/**
 * UPay 残高確認ポータル - GAS(Google Apps Script) バックエンド
 */

var CLIENT_ID      = '605638314023-5rb9s3ukrkal634henma3trbnp17pfvq.apps.googleusercontent.com';
var SPREADSHEET_ID = '1Nvv6gepROM11XAPHPaeU2aRrXSkRyBcGUo4qg5JOkyo';
var SHEET_NAME      = 'UserData';
var ITEM_SHEET_NAME = 'ItemData';

var EMAIL_HEADER_CANDIDATES   = ['email', 'emailaddress', 'mail', 'メールアドレス', 'メール', 'mailaddress'];
var BALANCE_HEADER_CANDIDATES = ['balance', 'balanceamount', '残高', '残高額'];
var USERID_HEADER_CANDIDATES  = ['userid', 'user_id', 'uid', 'id'];

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
 *   action = 'history'       → 過去2ヶ月の購入履歴を返す
 */
function doPost(e) {
  try {
    var requestBody = parseRequestBody_(e);
    var idToken = requestBody && requestBody.idToken;
    var action  = (requestBody && requestBody.action) || 'balance';

    if (!idToken) return jsonResponse_({ success: false, error: 'idTokenが送信されていません。' });

    var tokenInfo = verifyIdToken_(idToken);
    if (tokenInfo.error) return jsonResponse_({ success: false, error: 'トークンの検証に失敗しました: ' + tokenInfo.error });
    if (tokenInfo.aud !== CLIENT_ID) return jsonResponse_({ success: false, error: 'クライアントIDが一致しません。不正なリクエストの可能性があります。' });
    if (tokenInfo.email_verified !== 'true' && tokenInfo.email_verified !== true) return jsonResponse_({ success: false, error: 'メールアドレスが確認されていないGoogleアカウントです。' });

    var email = String(tokenInfo.email || '').trim().toLowerCase();
    if (!email) return jsonResponse_({ success: false, error: 'トークンにメールアドレスが含まれていません。' });

    if (action === 'history') return jsonResponse_(getPurchaseHistory_(email));
    return jsonResponse_(lookupBalanceByEmail_(email));
  } catch (err) {
    return jsonResponse_({ success: false, error: 'サーバー内部エラー: ' + err.message });
  }
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
 * 過去2ヶ月の PurchaseHistoryYYMM シートからユーザーの購入履歴を返す。
 * 新しい月のシートが追加されても YYMM 命名規則に従えば自動対応。
 */
function getPurchaseHistory_(email) {
  var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  var userSheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!userSheet) return { success: false, error: 'UserDataシートが見つかりません。' };

  // email → UserID 変換
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

  // 過去2ヶ月の YYMM リストを生成
  var months = getRecentMonths_();
  var history = [];

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
        dateTime:    dt instanceof Date ? dt.toISOString() : String(dt),
        itemName:    String(row[nameIdx]),
        amountSpent: Number(row[amtIdx]),
        number:      numIdx !== -1 ? String(row[numIdx]) : '1'
      });
    }
  });

  // 新しい順にソート
  history.sort(function(a, b) { return new Date(b.dateTime) - new Date(a.dateTime); });
  return { success: true, history: history };
}

/**
 * 今月と先月の YYMM 文字列を返す（例: ['2609', '2608']）。
 * 月をまたいでシートが追加されても自動対応。
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