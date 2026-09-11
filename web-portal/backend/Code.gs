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
// レジ端末など、verifyQrTokenを呼ぶ側だけが知っている合言葉。
// 実際にレジ側からこの検証APIを呼ぶ改修を行う前に、必ず推測困難な値に変更すること。
var REGISTER_API_KEY = 'CHANGE_ME_REGISTER_API_KEY';

/**
 * GET: 認証不要で販売中商品（SoldOut=false）の一覧を返す。
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
    });

    var items = [];
    for (var r = 1; r < values.length; r++) {
      var row = values[r];
      var soldOut = row[colIdx['SoldOut']];
      if (soldOut === true || String(soldOut).toLowerCase() === 'true') continue;
      items.push({
        id:       row[colIdx['ItemID']],
        name:     row[colIdx['Name']],
        price:    row[colIdx['Price']],
        stock:    row[colIdx['Stock']],
        image:    row[colIdx['ImagePath']],
        category: row[colIdx['Category']]
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
 */
function doPost(e) {
  try {
    var requestBody = parseRequestBody_(e);
    var action = (requestBody && requestBody.action) || 'balance';

    // レジ端末など、ログイン中のユーザーではない側から呼ばれる検証APIはidToken不要
    if (action === 'verifyQrToken') return jsonResponse_(verifyQrToken_(requestBody));

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
 * 現時点ではこのAPIを呼び出すレジ端末側の改修は別途行う想定で、ここではAPIの提供のみ行う。
 */
function verifyQrToken_(requestBody) {
  var apiKey = requestBody && requestBody.apiKey;
  if (!apiKey || apiKey !== REGISTER_API_KEY) {
    return { success: false, error: '検証用のAPIキーが正しくありません。' };
  }

  var token = requestBody && requestBody.token;
  if (!token) return { success: false, error: 'tokenが送信されていません。' };

  var cache = CacheService.getScriptCache();
  var key = 'qrtoken_' + token;
  var raw = cache.get(key);
  if (!raw) return { success: false, error: 'トークンが無効か、期限切れです。' };

  cache.remove(key); // 使い捨てにする（同じトークンは二度と使えない）

  var payload;
  try { payload = JSON.parse(raw); } catch (err) { return { success: false, error: 'トークンデータの解析に失敗しました。' }; }

  return { success: true, userId: payload.userId };
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