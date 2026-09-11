/**
 * UPay 残高確認ポータル - GAS(Google Apps Script) バックエンド
 */

var CLIENT_ID      = '605638314023-5rb9s3ukrkal634henma3trbnp17pfvq.apps.googleusercontent.com';
var SPREADSHEET_ID = '1Nvv6gepROM11XAPHPaeU2aRrXSkRyBcGUo4qg5JOkyo';
var SHEET_NAME       = 'UserData';
var ITEM_SHEET_NAME  = 'ItemData';
var TOPUP_SHEET_NAME = 'TopupHistory';

var EMAIL_HEADER_CANDIDATES   = ['email', 'emailaddress', 'mail', 'メールアドレス', 'メール', 'mailaddress'];
var BALANCE_HEADER_CANDIDATES = ['balance', 'balanceamount', '残高', '残高額'];
var USERID_HEADER_CANDIDATES  = ['userid', 'user_id', 'uid', 'id'];

// QRコード用ワンタイムトークンの有効期限（秒）
var QR_TOKEN_TTL_SECONDS = 120;
// QR検証後に発行するレジセッションの有効期間。
// プロジェクトの設定 → スクリプトプロパティに登録する。ソースには鍵を置かない。
var REGISTER_SESSION_TTL_SECONDS = 1800;

// 「補充希望」リアクションを保存するシート（なければ自動作成）
var REACTION_SHEET_NAME = 'ItemReactions';
// 在庫予約を保存するシート（なければ自動作成）
var RESERVATION_SHEET_NAME = 'Reservations';
// 予約の有効期限（分）。これを過ぎると自動的にキャンセル扱いになる。
var RESERVATION_TTL_MINUTES = 120;
// Reservationsシートの列インデックス（0始まり）
var RES_COL = { id: 0, itemId: 1, email: 2, createdAt: 3, expiresAt: 4, status: 5 };

/**
 * GET: 認証不要で販売中商品（SoldOut=false）の一覧を返す。
 * 在庫数（stock）は、有効な予約（Reservations）の分だけ差し引いた「購入可能数」。
 * reactionCountは「補充希望」リアクションの数。
 */
function doGet(e) {
  try {
    var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sheet = spreadsheet.getSheetByName(ITEM_SHEET_NAME);
    if (!sheet) return jsonResponse_({ success: false, error: 'ItemDataシートが見つかりません。' });

    var values = sheet.getDataRange().getValues();
    if (values.length < 2) return jsonResponse_({ success: true, items: [] });

    var headers = values[0];
    var colIdx = {};
    ['ItemID', 'Name', 'Price', 'Stock', 'ImagePath', 'Category', 'SoldOut'].forEach(function(key) {
      for (var i = 0; i < headers.length; i++) {
        if (String(headers[i]).trim() === key) { colIdx[key] = i; }
      }
      if (colIdx[key] === undefined) throw new Error('ItemDataに' + key + '列がありません。');
    });

    var reservedCounts = getActiveReservedCounts_(spreadsheet);
    var reactionCounts = getReactionCounts_(spreadsheet);

    var items = [];
    for (var r = 1; r < values.length; r++) {
      var row = values[r];
      var soldOut = row[colIdx['SoldOut']];
      if (soldOut === true || String(soldOut).toLowerCase() === 'true') continue;
      var itemId = row[colIdx['ItemID']];
      // 一覧は既存データの空欄・非数値を0として表示する。購入時は別途厳密に検証する。
      var rawStock = Number(row[colIdx['Stock']]) || 0;
      var reserved = reservedCounts[String(itemId)] || 0;
      items.push({
        id:            itemId,
        name:          row[colIdx['Name']],
        price:         Number(row[colIdx['Price']]) || 0,
        stock:         Math.max(0, rawStock - reserved),
        image:         row[colIdx['ImagePath']],
        category:      row[colIdx['Category']],
        reactionCount: reactionCounts[String(itemId)] || 0
      });
    }
    return jsonResponse_({ success: true, items: items });
  } catch (err) {
    return jsonResponse_({ success: false, error: 'サーバー内部エラー: ' + err.message });
  }
}

/**
 * POST: idToken を検証し action に応じた処理を行う。
 *   action 省略 or 'balance' → 残高・UserID を返す
 *   action = 'history'       → 過去2ヶ月の取引履歴（購入＋チャージ）を返す
 *   action = 'issueQrToken'  → QRコード用のワンタイムトークンを発行する
 *   action = 'verifyQrToken' → （レジ端末など向け）ワンタイムトークンを検証し、UserIDを返す。idToken不要・apiKey必須。
 *   action = 'toggleRestockReaction' → 「補充希望」リアクションのON/OFFを切り替える。idToken不要（誰でも利用可）。
 *   action = 'reserveItem'       → 商品の在庫を2時間キープする（予約）。
 *   action = 'cancelReservation' → 自分の予約を取り消す。
 *   action = 'myReservations'    → 自分の有効な予約一覧を返す。
 */
function doPost(e) {
  try {
    var requestBody = parseRequestBody_(e);
    var action = (requestBody && requestBody.action) || 'balance';

    // Google IDトークン不要のアクション。レジAPIは独自のキー・セッション認証を行う。
    if (action === 'verifyQrToken') return jsonResponse_(verifyQrToken_(requestBody));
    if (action === 'toggleRestockReaction') return jsonResponse_(toggleRestockReaction_(requestBody));
    if (['purchase', 'topup', 'claimGift'].indexOf(action) !== -1) {
      return jsonResponse_(registerTransaction_(requestBody));
    }

    var idToken = requestBody && requestBody.idToken;
    if (!idToken) return jsonResponse_({ success: false, error: 'idTokenが送信されていません。' });

    var tokenInfo = verifyIdToken_(idToken);
    if (tokenInfo.error) return jsonResponse_({ success: false, error: 'トークンの検証に失敗しました: ' + tokenInfo.error });
    if (tokenInfo.aud !== CLIENT_ID) return jsonResponse_({ success: false, error: 'クライアントIDが一致しません。不正なリクエストの可能性があります。' });
    if (tokenInfo.email_verified !== 'true' && tokenInfo.email_verified !== true) return jsonResponse_({ success: false, error: 'メールアドレスが確認されていないGoogleアカウントです。' });

    var email = String(tokenInfo.email || '').trim().toLowerCase();
    if (!email) return jsonResponse_({ success: false, error: 'トークンにメールアドレスが含まれていません。' });

    if (action === 'history') return jsonResponse_(getTransactionHistory_(email));
    if (action === 'issueQrToken') return jsonResponse_(issueQrToken_(email));
    if (action === 'reserveItem') return jsonResponse_(reserveItem_(email, requestBody));
    if (action === 'cancelReservation') return jsonResponse_(cancelReservation_(email, requestBody));
    if (action === 'myReservations') return jsonResponse_(listMyReservations_(email));
    return jsonResponse_(lookupBalanceByEmail_(email));
  } catch (err) {
    return jsonResponse_({ success: false, error: 'サーバー内部エラー: ' + err.message });
  }
}

/**
 * ログイン中のユーザー（email）に対して、QRコードに載せるワンタイムトークンを発行する。
 * トークンとUserIDの対応はCacheServiceに保存し、有効期限が切れると自動的に消える。
 */
function issueQrToken_(email) {
  var lookup = lookupBalanceByEmail_(email);
  if (!lookup.success) return lookup;
  if (lookup.userIdColumnFound === false) {
    return { success: false, error: 'スプレッドシートに「UserID」列が見つかりません。' };
  }
  if (lookup.userId === undefined || lookup.userId === null || String(lookup.userId).trim() === '') {
    return { success: false, error: 'あなたの行の UserID が空です。' };
  }

  var token = Utilities.getUuid().replace(/-/g, '');
  var cache = CacheService.getScriptCache();
  cache.put('qrtoken_' + token, JSON.stringify({
    userId: String(lookup.userId).trim(),
    email: email,
  }), QR_TOKEN_TTL_SECONDS);

  return { success: true, token: token, expiresInSeconds: QR_TOKEN_TTL_SECONDS };
}

/**
 * レジ端末など、ユーザーのGoogleログインを持たない側からトークンを検証するためのAPI。
 * apiKeyがREGISTER_API_KEYと一致しない場合は拒否する。
 * 検証に成功したトークンはその場で無効化される（使い捨て）。
 * 検証した本人の情報と、購入・チャージ・ギフト用の短期セッションを返す。
 */
function verifyQrToken_(requestBody) {
  requireRegisterKey_(requestBody);
  if (typeof requestBody.token !== 'string' || !/^[a-f0-9]{32}$/.test(requestBody.token)) {
    throw new Error('Webポータルに表示されたQRコードを読み取ってください。');
  }
  return withRegisterLock_(function() {
    var cache = CacheService.getScriptCache();
    var key = 'qrtoken_' + requestBody.token;
    var raw = cache.get(key);
    if (!raw) throw new Error('QRコードが無効か期限切れです。新しいQRを読み取ってください。');
    var payload = JSON.parse(raw);
    var table = registerTable_(SpreadsheetApp.openById(SPREADSHEET_ID), SHEET_NAME, USER_FIELDS_);
    var user = registerUser_(table, payload.userId);
    var sessionToken = Utilities.getUuid().replace(/-/g, '');
    cache.put('register_' + sessionToken, JSON.stringify({userId: String(user.UserID)}), REGISTER_SESSION_TTL_SECONDS);
    cache.remove(key);
    return {success: true, userId: user.UserID, user: user, sessionToken: sessionToken,
      expiresInSeconds: REGISTER_SESSION_TTL_SECONDS};
  });
}

/**
 * 「補充希望」リアクションのON/OFFを切り替える（LINEのスタンプのようなカジュアルな機能）。
 * ログイン不要。誰が押したかは記録せず、商品ごとの合計数だけをカウントする。
 * 実際の発注は、管理者がItemReactionsシートのCountを見て判断する想定。
 */
function toggleRestockReaction_(requestBody) {
  var itemId = requestBody && requestBody.itemId;
  if (!itemId) return { success: false, error: 'itemIdが送信されていません。' };
  var add = !!(requestBody && requestBody.add);

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sheet = getOrCreateReactionSheet_(spreadsheet);
    var values = sheet.getDataRange().getValues();
    for (var i = 1; i < values.length; i++) {
      if (String(values[i][0]) === String(itemId)) {
        var count = Math.max(0, (Number(values[i][1]) || 0) + (add ? 1 : -1));
        sheet.getRange(i + 1, 2).setValue(count);
        sheet.getRange(i + 1, 3).setValue(new Date());
        return { success: true, count: count };
      }
    }
    var newCount = add ? 1 : 0;
    sheet.appendRow([itemId, newCount, new Date()]);
    return { success: true, count: newCount };
  } finally {
    lock.releaseLock();
  }
}

function getOrCreateReactionSheet_(spreadsheet) {
  var sheet = spreadsheet.getSheetByName(REACTION_SHEET_NAME);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(REACTION_SHEET_NAME);
    sheet.appendRow(['ItemID', 'Count', 'UpdatedAt']);
  }
  return sheet;
}

function getReactionCounts_(spreadsheet) {
  var sheet = getOrCreateReactionSheet_(spreadsheet);
  var values = sheet.getDataRange().getValues();
  var result = {};
  for (var i = 1; i < values.length; i++) {
    var itemId = String(values[i][0]);
    if (!itemId) continue;
    result[itemId] = Number(values[i][1]) || 0;
  }
  return result;
}

/**
 * ログイン中のユーザー（email）に対して、商品の在庫を2時間だけキープする（予約）。
 * 「在庫」は元のStock列の値から、他の有効な予約の数を差し引いたもの。
 * 同じ商品を同時に複数予約することはできない。
 */
function reserveItem_(email, requestBody) {
  var itemId = requestBody && requestBody.itemId;
  if (!itemId) return { success: false, error: 'itemIdが送信されていません。' };

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    var itemSheet = spreadsheet.getSheetByName(ITEM_SHEET_NAME);
    if (!itemSheet) return { success: false, error: 'ItemDataシートが見つかりません。' };
    var itemValues = itemSheet.getDataRange().getValues();
    var itemHeaders = itemValues[0];
    var idColIdx = findColumnIndex_(itemHeaders, ['itemid']);
    var stockColIdx = findColumnIndex_(itemHeaders, ['stock']);
    if (idColIdx === -1 || stockColIdx === -1) return { success: false, error: 'ItemDataの列が見つかりません。' };

    var stock = null;
    for (var i = 1; i < itemValues.length; i++) {
      if (String(itemValues[i][idColIdx]) === String(itemId)) {
        stock = Number(itemValues[i][stockColIdx]) || 0;
        break;
      }
    }
    if (stock === null) return { success: false, error: '商品が見つかりません。' };

    var reservationSheet = getOrCreateReservationSheet_(spreadsheet);
    var resValues = reservationSheet.getDataRange().getValues();
    var now = new Date();
    var reservedCount = 0;
    var alreadyReserved = false;
    for (var r = 1; r < resValues.length; r++) {
      var row = resValues[r];
      var status = expireReservationRowIfNeeded_(reservationSheet, r, row, now);
      if (status !== 'active') continue;
      if (String(row[RES_COL.itemId]) !== String(itemId)) continue;
      reservedCount++;
      if (String(row[RES_COL.email]) === email) alreadyReserved = true;
    }

    if (alreadyReserved) return { success: false, error: 'この商品はすでに予約中です。' };
    if (reservedCount >= stock) return { success: false, error: '現在予約できる在庫がありません。' };

    var reservationId = Utilities.getUuid();
    var expiresAt = new Date(now.getTime() + RESERVATION_TTL_MINUTES * 60 * 1000);
    reservationSheet.appendRow([reservationId, itemId, email, now, expiresAt, 'active']);

    return { success: true, reservationId: reservationId, expiresAt: expiresAt.toISOString() };
  } finally {
    lock.releaseLock();
  }
}

/**
 * 自分の予約を取り消す（本人の予約かどうかをemailで確認する）。
 */
function cancelReservation_(email, requestBody) {
  var reservationId = requestBody && requestBody.reservationId;
  if (!reservationId) return { success: false, error: 'reservationIdが送信されていません。' };

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sheet = getOrCreateReservationSheet_(spreadsheet);
    var values = sheet.getDataRange().getValues();
    for (var i = 1; i < values.length; i++) {
      if (String(values[i][RES_COL.id]) !== String(reservationId)) continue;
      if (String(values[i][RES_COL.email]) !== email) return { success: false, error: 'この予約を取り消す権限がありません。' };
      var status = expireReservationRowIfNeeded_(sheet, i, values[i], new Date());
      if (status !== 'active') return { success: false, error: 'この予約はすでに終了しています。' };
      sheet.getRange(i + 1, RES_COL.status + 1).setValue('cancelled');
      return { success: true };
    }
    return { success: false, error: '予約が見つかりません。' };
  } finally {
    lock.releaseLock();
  }
}

/**
 * 自分の有効な予約の一覧を、商品名・価格つきで返す。
 */
function listMyReservations_(email) {
  var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = getOrCreateReservationSheet_(spreadsheet);
  var values = sheet.getDataRange().getValues();
  var now = new Date();

  var itemSheet = spreadsheet.getSheetByName(ITEM_SHEET_NAME);
  var itemMap = {};
  if (itemSheet) {
    var itemValues = itemSheet.getDataRange().getValues();
    if (itemValues.length >= 2) {
      var itemHeaders = itemValues[0];
      var idColIdx    = findColumnIndex_(itemHeaders, ['itemid']);
      var nameColIdx  = findColumnIndex_(itemHeaders, ['name']);
      var priceColIdx = findColumnIndex_(itemHeaders, ['price']);
      for (var i = 1; i < itemValues.length; i++) {
        itemMap[String(itemValues[i][idColIdx])] = {
          name:  nameColIdx !== -1 ? itemValues[i][nameColIdx] : '',
          price: priceColIdx !== -1 ? itemValues[i][priceColIdx] : null
        };
      }
    }
  }

  var result = [];
  for (var r = 1; r < values.length; r++) {
    var row = values[r];
    if (String(row[RES_COL.email]) !== email) continue;
    var status = expireReservationRowIfNeeded_(sheet, r, row, now);
    if (status !== 'active') continue;
    var itemInfo = itemMap[String(row[RES_COL.itemId])] || {};
    var expiresAt = row[RES_COL.expiresAt] instanceof Date ? row[RES_COL.expiresAt] : new Date(row[RES_COL.expiresAt]);
    result.push({
      reservationId: String(row[RES_COL.id]),
      itemId:        String(row[RES_COL.itemId]),
      itemName:      itemInfo.name || '(不明な商品)',
      price:         itemInfo.price,
      expiresAt:     expiresAt.toISOString()
    });
  }
  return { success: true, reservations: result };
}

/**
 * 有効な（期限内の）予約の、商品ごとの件数を返す。doGetの在庫計算に使う。
 * 読み取りのついでに、期限切れになった行のStatusを'expired'へ更新する（遅延クリーンアップ）。
 */
function getActiveReservedCounts_(spreadsheet) {
  var sheet = getOrCreateReservationSheet_(spreadsheet);
  var values = sheet.getDataRange().getValues();
  var now = new Date();
  var result = {};
  for (var i = 1; i < values.length; i++) {
    var row = values[i];
    var status = expireReservationRowIfNeeded_(sheet, i, row, now);
    if (status !== 'active') continue;
    var itemId = String(row[RES_COL.itemId]);
    result[itemId] = (result[itemId] || 0) + 1;
  }
  return result;
}

/**
 * 行が'active'のまま期限（ExpiresAt）を過ぎていたら、シート上のStatusを'expired'に書き換える。
 * 戻り値は更新後のステータス文字列。
 */
function expireReservationRowIfNeeded_(sheet, rowIndex, row, now) {
  var status = String(row[RES_COL.status]);
  if (status !== 'active') return status;
  var expiresAt = row[RES_COL.expiresAt] instanceof Date ? row[RES_COL.expiresAt] : new Date(row[RES_COL.expiresAt]);
  if (expiresAt > now) return 'active';
  sheet.getRange(rowIndex + 1, RES_COL.status + 1).setValue('expired');
  return 'expired';
}

function getOrCreateReservationSheet_(spreadsheet) {
  var sheet = spreadsheet.getSheetByName(RESERVATION_SHEET_NAME);
  if (!sheet) {
    sheet = spreadsheet.insertSheet(RESERVATION_SHEET_NAME);
    sheet.appendRow(['ReservationID', 'ItemID', 'Email', 'CreatedAt', 'ExpiresAt', 'Status']);
  }
  return sheet;
}

function parseRequestBody_(e) {
  if (!e || !e.postData || !e.postData.contents) return null;
  try { return JSON.parse(e.postData.contents); } catch (err) { return null; }
}

function verifyIdToken_(idToken) {
  var url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken);
  var response = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  var body;
  try { body = JSON.parse(response.getContentText()); } catch (err) { return { error: 'トークン検証応答の解析に失敗しました。' }; }
  if (response.getResponseCode() !== 200 || body.error) return { error: body.error_description || body.error || '無効なトークンです。' };
  return body;
}

function lookupBalanceByEmail_(email) {
  var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!sheet) return { success: false, error: 'シート「' + SHEET_NAME + '」が見つかりません。' };

  var values = sheet.getDataRange().getValues();
  if (values.length < 2) return { success: false, error: 'データが登録されていません。' };

  var headers = values[0];
  var emailColIdx   = findColumnIndex_(headers, EMAIL_HEADER_CANDIDATES);
  var balanceColIdx = findColumnIndex_(headers, BALANCE_HEADER_CANDIDATES);
  var userIdColIdx  = findColumnIndex_(headers, USERID_HEADER_CANDIDATES);

  if (emailColIdx === -1) return { success: false, error: 'メールアドレス列が見つかりません。' };
  if (balanceColIdx === -1) return { success: false, error: '残高列が見つかりません。' };

  for (var i = 1; i < values.length; i++) {
    var rowEmail = String(values[i][emailColIdx] || '').trim().toLowerCase();
    if (rowEmail === email) {
      var result = { success: true, balance: values[i][balanceColIdx] };
      if (userIdColIdx !== -1) {
        result.userId = values[i][userIdColIdx];
        result.userIdColumnFound = true;
      } else {
        result.userIdColumnFound = false;
      }
      return result;
    }
  }
  return { success: false, error: '未登録ユーザーです' };
}

/**
 * 購入履歴（PurchaseHistoryYYMM）とチャージ履歴（TopupHistory）を
 * 過去2ヶ月分マージして返す。type='purchase' / 'topup' で区別。
 */
function getTransactionHistory_(email) {
  var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);

  // email → UserID 変換
  var userSheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!userSheet) return { success: false, error: 'UserDataシートが見つかりません。' };
  var userValues = userSheet.getDataRange().getValues();
  var userHeaders = userValues[0];
  var emailColIdx  = findColumnIndex_(userHeaders, EMAIL_HEADER_CANDIDATES);
  var userIdColIdx = findColumnIndex_(userHeaders, USERID_HEADER_CANDIDATES);
  if (emailColIdx === -1 || userIdColIdx === -1) return { success: false, error: 'UserData の列が見つかりません。' };

  var userId = null;
  for (var i = 1; i < userValues.length; i++) {
    if (String(userValues[i][emailColIdx] || '').trim().toLowerCase() === email) {
      userId = userValues[i][userIdColIdx];
      break;
    }
  }
  if (userId === null || String(userId).trim() === '') return { success: false, error: '未登録ユーザーです。' };

  var history = [];

  // ── 購入履歴 (PurchaseHistoryYYMM) ──────────────────────────
  var months = getRecentMonths_();
  months.forEach(function(yymm) {
    var sheet = spreadsheet.getSheetByName('PurchaseHistory' + yymm);
    if (!sheet) return;
    var values = sheet.getDataRange().getValues();
    if (values.length < 2) return;
    var headers = values[0];
    var dtIdx   = findColumnIndex_(headers, ['datetime', 'date', '日時']);
    var uidIdx  = findColumnIndex_(headers, ['userid', 'user_id', 'uid']);
    var nameIdx = findColumnIndex_(headers, ['itemname', 'item_name', 'name', '商品名']);
    var amtIdx  = findColumnIndex_(headers, ['amountspent', 'amount', '金額', '支払額']);
    var numIdx  = findColumnIndex_(headers, ['number', 'qty', 'quantity', '個数']);
    if (dtIdx === -1 || uidIdx === -1 || nameIdx === -1 || amtIdx === -1) return;
    for (var r = 1; r < values.length; r++) {
      var row = values[r];
      if (String(row[uidIdx]) !== String(userId)) continue;
      var dt = row[dtIdx];
      history.push({
        type:        'purchase',
        dateTime:    dt instanceof Date ? dt.toISOString() : String(dt),
        label:       String(row[nameIdx]),
        amount:      Number(row[amtIdx]),
        number:      numIdx !== -1 ? String(row[numIdx]) : '1'
      });
    }
  });

  // ── チャージ履歴 (TopupHistory・単一シート・過去2ヶ月でフィルタ) ──
  var topupSheet = spreadsheet.getSheetByName(TOPUP_SHEET_NAME);
  if (topupSheet) {
    var cutoff = new Date();
    cutoff.setMonth(cutoff.getMonth() - 1);
    cutoff.setDate(1);
    cutoff.setHours(0, 0, 0, 0);

    var tValues = topupSheet.getDataRange().getValues();
    if (tValues.length >= 2) {
      var tHeaders = tValues[0];
      var tDtIdx  = findColumnIndex_(tHeaders, ['datetime', 'date', '日時']);
      var tUidIdx = findColumnIndex_(tHeaders, ['userid', 'user_id', 'uid']);
      var tAmtIdx = findColumnIndex_(tHeaders, ['amount', '金額', 'topupamount', 'チャージ額']);
      if (tDtIdx !== -1 && tUidIdx !== -1 && tAmtIdx !== -1) {
        for (var r = 1; r < tValues.length; r++) {
          var row = tValues[r];
          if (String(row[tUidIdx]) !== String(userId)) continue;
          var dt = row[tDtIdx];
          var dtDate = dt instanceof Date ? dt : new Date(dt);
          if (dtDate < cutoff) continue;
          history.push({
            type:     'topup',
            dateTime: dt instanceof Date ? dt.toISOString() : String(dt),
            label:    'チャージ',
            amount:   Number(row[tAmtIdx])
          });
        }
      }
    }
  }

  // 新しい順にソート
  history.sort(function(a, b) { return new Date(b.dateTime) - new Date(a.dateTime); });
  return { success: true, history: history };
}

/**
 * 今月と先月の YYMM 文字列を返す（例: ['2609', '2608']）。
 */
function getRecentMonths_() {
  var now = new Date();
  var months = [];
  for (var i = 0; i < 2; i++) {
    var d  = new Date(now.getFullYear(), now.getMonth() - i, 1);
    var yy = String(d.getFullYear()).slice(2);
    var mm = ('0' + (d.getMonth() + 1)).slice(-2);
    months.push(yy + mm);
  }
  return months;
}

function findColumnIndex_(headers, candidates) {
  for (var i = 0; i < headers.length; i++) {
    var header = String(headers[i]).trim().toLowerCase();
    for (var j = 0; j < candidates.length; j++) {
      if (header === candidates[j].toLowerCase()) return i;
    }
  }
  return -1;
}

function jsonResponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

// レジAPI。全書き込みを同じScriptLockとSheets.batchUpdateで処理する。
var USER_FIELDS_ = ['UserID', 'Email', 'Balance', 'PurchaseNum', 'TotalAmount', 'GiftAmount'];
var ITEM_FIELDS_ = ['ItemID', 'Name', 'Price', 'Stock', 'SalesFigure', 'SoldOut'];
var RECEIPT_FIELDS_ = ['RequestID', 'Session', 'Payload', 'Result'];

function requireRegisterKey_(body) {
  var key = PropertiesService.getScriptProperties().getProperty('REGISTER_API_KEY');
  if (!key || key.length < 32 || key === 'CHANGE_ME_REGISTER_API_KEY' || !body || body.apiKey !== key) {
    throw new Error('レジAPIキーが未設定か一致しません。');
  }
}

function withRegisterLock_(callback) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) throw new Error('処理が混雑しています。同じ操作を再試行してください。');
  try { return callback(); } finally { lock.releaseLock(); }
}

function registerTable_(ss, name, required) {
  var sheet = ss.getSheetByName(name);
  if (!sheet) throw new Error(name + 'シートがありません。');
  var rows = sheet.getDataRange().getValues();
  var columns = {};
  required.forEach(function(field) {
    var candidates = field === 'Balance' ? BALANCE_HEADER_CANDIDATES :
      field === 'UserID' ? USERID_HEADER_CANDIDATES :
      field === 'Email' ? EMAIL_HEADER_CANDIDATES : [field];
    var index = findColumnIndex_(rows[0], candidates);
    if (index < 0) throw new Error(name + 'に' + field + '列がありません。');
    columns[field] = index;
  });
  return {sheet: sheet, rows: rows, columns: columns};
}

function registerRow_(table, field, id) {
  var matches = [];
  for (var i = 1; i < table.rows.length; i++) {
    if (String(table.rows[i][table.columns[field]]).trim() === String(id).trim()) matches.push(i);
  }
  if (matches.length !== 1) throw new Error(field + 'が未登録または重複しています。');
  return matches[0];
}

function nonnegativeInteger_(value, label) {
  if ((typeof value !== 'number' && typeof value !== 'string') || String(value).trim() === '') {
    throw new Error(label + 'は0以上の整数が必要です。');
  }
  var number = Number(value);
  if (!Number.isSafeInteger(number) || number < 0) throw new Error(label + 'は0以上の整数が必要です。');
  return number;
}

function registerUser_(table, id) {
  var row = table.rows[registerRow_(table, 'UserID', id)];
  var user = {};
  USER_FIELDS_.forEach(function(field) {
    var value = row[table.columns[field]];
    if (field === 'Email') {
      // インストール済みFlutterとの互換性のため返却キーはUserNameを維持する。
      // シートのUserName列は不要。表示名にはポータルと同じメールアドレスを使う。
      user.UserName = String(value || '').trim().toLowerCase();
      if (!user.UserName) throw new Error('UserDataのメールアドレスが空です。');
    } else {
      user[field] = field === 'UserID' ? String(value) : nonnegativeInteger_(value, field);
    }
  });
  return user;
}

function cellData_(value) {
  var key = typeof value === 'number' ? 'numberValue' : typeof value === 'boolean' ? 'boolValue' : 'stringValue';
  var cell = {userEnteredValue: {}};
  cell.userEnteredValue[key] = value;
  return cell;
}

function updateRegisterCell_(requests, table, row, field, value) {
  requests.push({updateCells: {
    start: {sheetId: table.sheet.getSheetId(), rowIndex: row, columnIndex: table.columns[field]},
    rows: [{values: [cellData_(value)]}], fields: 'userEnteredValue'
  }});
}

// 履歴シートがない場合も同じ原子的バッチで作成する。
function appendRegisterRecord_(ss, requests, name, fields, record) {
  var sheet = ss.getSheetByName(name);
  var id;
  var headers;
  if (sheet) {
    id = sheet.getSheetId();
    headers = sheet.getDataRange().getValues()[0];
    fields.forEach(function(field) {
      if (headers.indexOf(field) < 0) throw new Error(name + 'に' + field + '列がありません。');
    });
  } else {
    id = Math.floor(Math.random() * 2000000000) + 1;
    headers = fields;
    requests.push({addSheet: {properties: {sheetId: id, title: name}}});
    requests.push({appendCells: {sheetId: id, rows: [{values: headers.map(cellData_)}], fields: 'userEnteredValue'}});
  }
  requests.push({appendCells: {sheetId: id,
    rows: [{values: headers.map(function(field) { return cellData_(record[field] === undefined ? '' : record[field]); })}],
    fields: 'userEnteredValue'}});
}

function registerTransaction_(body) {
  requireRegisterKey_(body);
  if (typeof body.sessionToken !== 'string' || !/^[a-f0-9]{32}$/.test(body.sessionToken)) throw new Error('QRを読み取り直してください。');
  if (typeof body.requestId !== 'string' || !/^[a-f0-9]{32}$/.test(body.requestId)) throw new Error('requestIdが不正です。');
  return withRegisterLock_(function() {
    var rawSession = CacheService.getScriptCache().get('register_' + body.sessionToken);
    if (!rawSession) throw new Error('セッションの期限が切れました。QRを読み取り直してください。');
    var userId = JSON.parse(rawSession).userId;
    var sessionHash = Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, body.sessionToken));
    var signature = JSON.stringify({action: body.action, items: body.items || null, amount: body.amount === undefined ? null : body.amount});
    var ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    // 応答喪失後も同じrequestIdなら保存済み結果を返す。キャッシュを台帳にしない。
    var ledger = ss.getSheetByName('RegisterRequests');
    var purchaseCompleted = false;
    if (ledger) {
      var receipts = registerTable_(ss, 'RegisterRequests', RECEIPT_FIELDS_);
      for (var r = 1; r < receipts.rows.length; r++) {
        var receipt = receipts.rows[r];
        if (receipt[receipts.columns.Session] !== sessionHash) continue;
        if (receipt[receipts.columns.RequestID] === body.requestId) {
          if (receipt[receipts.columns.Payload] !== signature) throw new Error('同じrequestIdで内容を変更できません。');
          return JSON.parse(receipt[receipts.columns.Result]);
        }
        if (JSON.parse(receipt[receipts.columns.Payload]).action === 'purchase') purchaseCompleted = true;
      }
    }
    if (purchaseCompleted) throw new Error('このセッションは決済済みです。QRを読み取り直してください。');
    var users = registerTable_(ss, SHEET_NAME, USER_FIELDS_);
    var userRow = registerRow_(users, 'UserID', userId);
    var user = registerUser_(users, userId);
    var requests = [];
    var now = new Date();
    var amount = 0;
    if (body.action === 'purchase') {
      if (!Array.isArray(body.items) || !body.items.length || body.items.length > 100) throw new Error('商品を1〜100種類選択してください。');
      var items = registerTable_(ss, ITEM_SHEET_NAME, ITEM_FIELDS_);
      var quantities = {};
      body.items.forEach(function(item) {
        if (!item || !Number.isSafeInteger(item.itemId) || item.itemId < 0 || !Number.isSafeInteger(item.quantity) || item.quantity <= 0) {
          throw new Error('商品ID・個数が不正です。');
        }
        quantities[item.itemId] = nonnegativeInteger_((quantities[item.itemId] || 0) + item.quantity, '個数');
      });
      var ids = [], names = [], numbers = [];
      Object.keys(quantities).sort().forEach(function(id) {
        var rowIndex = registerRow_(items, 'ItemID', id);
        var row = items.rows[rowIndex];
        var quantity = quantities[id];
        var stock = nonnegativeInteger_(row[items.columns.Stock], 'Stock');
        var price = nonnegativeInteger_(row[items.columns.Price], 'Price');
        var soldOut = row[items.columns.SoldOut];
        if (String(soldOut).toLowerCase() === 'true' || stock < quantity) throw new Error(String(row[items.columns.Name]) + 'の在庫が不足しています。');
        amount = nonnegativeInteger_(amount + price * quantity, '購入金額');
        updateRegisterCell_(requests, items, rowIndex, 'Stock', stock - quantity);
        updateRegisterCell_(requests, items, rowIndex, 'SalesFigure', nonnegativeInteger_(nonnegativeInteger_(row[items.columns.SalesFigure], 'SalesFigure') + quantity, 'SalesFigure'));
        updateRegisterCell_(requests, items, rowIndex, 'SoldOut', stock === quantity);
        ids.push(id); names.push(String(row[items.columns.Name])); numbers.push(quantity);
      });
      if (user.Balance < amount) throw new Error('残高が不足しています。');
      user.Balance -= amount;
      user.PurchaseNum = nonnegativeInteger_(user.PurchaseNum + numbers.reduce(function(a, b) { return a + b; }, 0), 'PurchaseNum');
      user.TotalAmount = nonnegativeInteger_(user.TotalAmount + amount, 'TotalAmount');
      appendRegisterRecord_(ss, requests, 'PurchaseHistory' + Utilities.formatDate(now, 'Asia/Tokyo', 'yyMM'),
        ['DateTime', 'UserID', 'ItemID', 'ItemName', 'Number', 'AfterPurchase', 'AmountSpent'],
        {DateTime: now.toISOString(), UserID: user.UserID, ItemID: ids.join(','), ItemName: names.join(','),
          Number: numbers.join(','), AfterPurchase: user.Balance, AmountSpent: amount});
    } else if (body.action === 'topup' || body.action === 'claimGift') {
      if (body.action === 'topup') {
        // 現金受領はAPIでは検証できないため、管理者が明示的に有効化した端末のみ。
        if (PropertiesService.getScriptProperties().getProperty('ALLOW_REGISTER_TOPUP') !== 'true') throw new Error('この環境では現金チャージが無効です。');
        if (!Number.isSafeInteger(body.amount) || body.amount <= 0 || body.amount > 100000) throw new Error('チャージ額は1〜100000の整数で指定してください。');
        amount = body.amount;
      } else {
        amount = user.GiftAmount;
        if (amount <= 0) throw new Error('受け取り可能なギフトがありません。');
        user.GiftAmount = 0;
      }
      user.Balance = nonnegativeInteger_(user.Balance + amount, 'Balance');
      appendRegisterRecord_(ss, requests, TOPUP_SHEET_NAME, ['DateTime', 'UserID', 'Amount', 'AfterTopup'],
        {DateTime: now.toISOString(), UserID: user.UserID, Amount: amount, AfterTopup: user.Balance});
    } else { throw new Error('未対応のレジ操作です。'); }
    ['Balance', 'PurchaseNum', 'TotalAmount', 'GiftAmount'].forEach(function(field) {
      updateRegisterCell_(requests, users, userRow, field, user[field]);
    });
    var result = {success: true, user: user, amount: amount, requestId: body.requestId};
    appendRegisterRecord_(ss, requests, 'RegisterRequests', RECEIPT_FIELDS_,
      {RequestID: body.requestId, Session: sessionHash, Payload: signature, Result: JSON.stringify(result)});
    // 残高・在庫・履歴・再試行台帳をすべて成功またはすべて失敗にする。
    Sheets.Spreadsheets.batchUpdate({requests: requests}, SPREADSHEET_ID);
    return result;
  });
}
