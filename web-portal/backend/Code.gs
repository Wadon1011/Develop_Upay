/**
 * UPay 残高確認ポータル（デモ） - GAS(Google Apps Script) バックエンド
 *
 * frontend/index.html からPOSTされたGoogle IDトークンを検証し、
 * 検証済みのメールアドレスをキーに UserData シートを検索して残高を返す。
 *
 * このスクリプトはサービスアカウント鍵を一切必要としない。
 * スプレッドシートへのアクセスは、このスクリプトを実行するGoogleアカウント
 * （デプロイ時に「実行するユーザー: 自分」を選択した場合はデプロイ者のアカウント）の
 * 権限で行われる。
 */

// ============================================================
// 設定値（TODO: ここに実際の値を入れてください）
// ============================================================

// Google Cloud Console で発行した OAuth 2.0 クライアントID。
// frontend/index.html 内の GOOGLE_CLIENT_ID と必ず同じ値にすること。
// TODO: ここに実際の値を入れてください
var CLIENT_ID = '605638314023-5rb9s3ukrkal634henma3trbnp17pfvq.apps.googleusercontent.com';

// 残高データが入っているスプレッドシートのID。
// スプレッドシートのURL https://docs.google.com/spreadsheets/d/【この部分】/edit の【この部分】。
// TODO: ここに実際の値を入れてください
var SPREADSHEET_ID = '1Nvv6gepROM11XAPHPaeU2aRrXSkRyBcGUo4qg5JOkyo';

// 検索対象のシート名
var SHEET_NAME = 'UserData';

// 商品データのシート名
var ITEM_SHEET_NAME = 'ItemData';

// ============================================================

// ヘッダー行から「メールアドレス列」を探すときの候補（大文字小文字・前後空白は無視して比較する）
var EMAIL_HEADER_CANDIDATES = ['email', 'emailaddress', 'mail', 'メールアドレス', 'メール', 'mailaddress'];

// ヘッダー行から「残高列」を探すときの候補（大文字小文字・前後空白は無視して比較する）
var BALANCE_HEADER_CANDIDATES = ['balance', 'balanceamount', '残高', '残高額'];

// ヘッダー行から「ユーザーID列」を探すときの候補（大文字小文字・前後空白は無視して比較する）
var USERID_HEADER_CANDIDATES = ['userid', 'user id', 'user_id', 'ユーザーid', 'ユーザid'];

// QRコードに載せるユーザーIDの桁数。数字のみのIDはこの桁数までゼロ埋めする。
var USERID_DIGITS = 5;

/**
 * GETリクエストを処理するエントリポイント。
 * 認証不要で販売中商品（SoldOut=false）の一覧を返す。
 * レスポンス(JSON): { "success": true, "items": [...] }
 */
function doGet(e) {
  try {
    var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
    var sheet = spreadsheet.getSheetByName(ITEM_SHEET_NAME);
    if (!sheet) {
      return jsonResponse_({ success: false, error: 'ItemDataシートが見つかりません。' });
    }

    var values = sheet.getDataRange().getValues();
    if (values.length < 2) {
      return jsonResponse_({ success: true, items: [] });
    }

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
 * フロントエンドからのPOSTリクエストを処理するエントリポイント。
 * リクエストボディ(JSON): { "idToken": "<GoogleのIDトークン>" }
 * レスポンス(JSON): { "success": true, "balance": <数値> }
 *              または { "success": false, "error": "<エラーメッセージ>" }
 */
function doPost(e) {
  try {
    var requestBody = parseRequestBody_(e);
    var idToken = requestBody && requestBody.idToken;
    if (!idToken) {
      return jsonResponse_({ success: false, error: 'idTokenが送信されていません。' });
    }

    var tokenInfo = verifyIdToken_(idToken);
    if (tokenInfo.error) {
      return jsonResponse_({ success: false, error: 'トークンの検証に失敗しました: ' + tokenInfo.error });
    }

    // aud(トークンの発行先クライアントID)が想定するCLIENT_IDと一致するか必ず確認する。
    // これを怠ると、他のGoogleアプリ向けに発行されたトークンでもなりすましが可能になる。
    if (tokenInfo.aud !== CLIENT_ID) {
      return jsonResponse_({ success: false, error: 'クライアントIDが一致しません。不正なリクエストの可能性があります。' });
    }

    if (tokenInfo.email_verified !== 'true' && tokenInfo.email_verified !== true) {
      return jsonResponse_({ success: false, error: 'メールアドレスが確認されていないGoogleアカウントです。' });
    }

    var email = String(tokenInfo.email || '').trim().toLowerCase();
    if (!email) {
      return jsonResponse_({ success: false, error: 'トークンにメールアドレスが含まれていません。' });
    }

    var result = lookupBalanceByEmail_(email);
    return jsonResponse_(result);
  } catch (err) {
    return jsonResponse_({ success: false, error: 'サーバー内部エラー: ' + err.message });
  }
}

/**
 * リクエストボディ(JSON文字列)をパースする。失敗時はnullを返す。
 */
function parseRequestBody_(e) {
  if (!e || !e.postData || !e.postData.contents) {
    return null;
  }
  try {
    return JSON.parse(e.postData.contents);
  } catch (err) {
    return null;
  }
}

/**
 * GoogleのtokeninfoエンドポイントでIDトークンを検証する。
 * 有効な場合はデコード済みのペイロード(aud, email, email_verified等を含む)を返す。
 * 無効な場合は { error: "<理由>" } を返す。
 */
function verifyIdToken_(idToken) {
  var url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken);
  var response = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  var body;
  try {
    body = JSON.parse(response.getContentText());
  } catch (err) {
    return { error: 'トークン検証応答の解析に失敗しました。' };
  }

  if (response.getResponseCode() !== 200 || body.error) {
    return { error: body.error_description || body.error || '無効なトークンです。' };
  }
  return body;
}

/**
 * UserDataシートをヘッダー行から動的に列位置を求めて検索し、
 * 該当ユーザーの残高を返す。
 */
function lookupBalanceByEmail_(email) {
  var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = spreadsheet.getSheetByName(SHEET_NAME);
  if (!sheet) {
    return { success: false, error: 'シート「' + SHEET_NAME + '」が見つかりません。' };
  }

  var values = sheet.getDataRange().getValues();
  if (values.length < 2) {
    return { success: false, error: 'データが登録されていません。' };
  }

  var headers = values[0];
  var emailColIdx = findColumnIndex_(headers, EMAIL_HEADER_CANDIDATES);
  var balanceColIdx = findColumnIndex_(headers, BALANCE_HEADER_CANDIDATES);
  var userIdColIdx = findColumnIndex_(headers, USERID_HEADER_CANDIDATES);

  if (emailColIdx === -1) {
    return { success: false, error: 'メールアドレス列が見つかりません。ヘッダー行の列名を確認してください。' };
  }
  if (balanceColIdx === -1) {
    return { success: false, error: '残高列が見つかりません。ヘッダー行の列名を確認してください。' };
  }

  for (var i = 1; i < values.length; i++) {
    var rowEmail = String(values[i][emailColIdx] || '').trim().toLowerCase();
    if (rowEmail === email) {
      var result = { success: true, balance: values[i][balanceColIdx] };
      result.userIdColumnFound = (userIdColIdx !== -1);
      if (userIdColIdx !== -1) {
        // 列が見つかった場合は、値が空でも userId キー自体は返す（空文字）。
        // フロント側で「列なし」と「値が空」を区別できるようにするため。
        result.userId = formatUserId_(values[i][userIdColIdx]);
      }
      return result;
    }
  }

  return { success: false, error: '未登録ユーザーです' };
}

/**
 * ユーザーID列の値を、QRコードに載せる文字列へ整形する。
 * 数字のみの場合は USERID_DIGITS 桁までゼロ埋めする。
 * それ以外はトリムした文字列をそのまま返す。空なら空文字を返す。
 */
function formatUserId_(rawValue) {
  var value = String(rawValue == null ? '' : rawValue).trim();
  if (!value) { return ''; }
  if (/^\d+$/.test(value)) {
    while (value.length < USERID_DIGITS) { value = '0' + value; }
  }
  return value;
}

/**
 * ヘッダー行(1次元配列)の中から候補名(候補は複数、大文字小文字・前後空白は無視)に
 * 一致する列のインデックスを返す。見つからなければ-1。
 * 列番号を決め打ちにせず、シートの列構成が変わっても追従できるようにするための実装。
 */
function findColumnIndex_(headers, candidates) {
  for (var i = 0; i < headers.length; i++) {
    var header = String(headers[i]).trim().toLowerCase();
    for (var j = 0; j < candidates.length; j++) {
      if (header === candidates[j].toLowerCase()) {
        return i;
      }
    }
  }
  return -1;
}

/**
 * JSON形式のレスポンスを生成する。
 */
function jsonResponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}