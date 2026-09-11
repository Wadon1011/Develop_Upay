# FlutterレジのGAS接続

## 構成

```text
Webポータル → Googleログイン → GASでQR発行（120秒）
                                  ↓
Flutterレジ → QR検証 → 本人の情報とレジセッション（最長30分）
            → 商品一覧 / 購入 / ギフト受領 / 現金チャージ
                                  ↓
                 Code.gs の SPREADSHEET_ID
```

Flutterは全ユーザー一覧を取得せず、QRで認証した本人の情報だけ取得します。
従来の固定ユーザーIDのQR・学生証バーコードは、この構成では利用しません。
Webポータルに表示されたワンタイムQRを使用してください。

## 1. GASを更新する

1. 既存GASプロジェクトの `Code.gs` を `web-portal/backend/Code.gs` の内容で置き換えます。
   `SPREADSHEET_ID` は今回の開発用シートを指す既存の値を維持しています。
2. GASの「プロジェクトの設定」でマニフェストを表示し、`appsscript.json` を
   `web-portal/backend/appsscript.json` と合わせます。既存設定がある場合は保持しながら、
   Sheets v4サービスと `spreadsheets` / `script.external_request` のOAuthスコープを追加します。
   標準Google Cloudプロジェクトを紐付けている場合は、そのプロジェクトでGoogle Sheets APIも有効にします。
3. 「プロジェクトの設定 → スクリプトプロパティ」に以下を登録します。

| 名前 | 値 |
| --- | --- |
| `REGISTER_API_KEY` | 推測困難な32文字以上のランダム値。Flutterと同じ値を使用 |
| `ALLOW_REGISTER_TOPUP` | 現金を管理するレジでチャージを許可するときだけ `true` |

4. 「デプロイ → デプロイを管理 → 編集 → 新バージョン」で更新し、追加権限を承認します。
   実行ユーザーは「自分」、アクセスできるユーザーは「全員」（GoogleログインなしでAPIに到達可能）にします。
   ポータルの個人情報APIはGoogle IDトークン、レジAPIはAPIキー＋QRセッションで認証します。
   組織の設定で匿名公開が禁止される場合は、この接続方式はそのままでは動作しません。
5. `/exec` URLをWebポータルとFlutterの設定に使用します。既存デプロイの更新ならURLを維持できます。

レジキーはサービスアカウントの秘密鍵ではありませんが、アプリから抽出可能です。
管理するレジ端末だけにアプリを配布してください。現金受領はサーバーで検証できないため、
現金チャージは既定で無効です。ギフトはシートに設定された `GiftAmount` のみを受け取れます。

## 2. シートの列を確認する

1行目はヘッダー、2行目以降はデータです。IDは重複させないでください。

| シート | 必須列 |
| --- | --- |
| `UserData` | `UserID`, `Balance`, `PurchaseNum`, `TotalAmount`, `GiftAmount` とポータル用メール列（`Email` / `メールアドレス` など） |
| `ItemData` | `ItemID`, `Name`, `Price`, `Stock`, `SalesFigure`, `SoldOut`, `ImagePath`, `Category` |

残高列とユーザーID列は既存ポータルの別名候補も利用できます。
`UserName` 列は不要です。表示名にはメールアドレスを使います。インストール済みFlutterとの互換性のため、APIはメールアドレスを `user.UserName` として返します。
金額・累計・在庫は空欄ではなく0以上の整数を入れます。`UserID` / `ItemID` は数値のIDを使用します。
`SoldOut` はチェックボックスまたは `true` / `false`、`Category` は `drink` / `snack` / `food`。
`ImagePath` はFlutter内の `images/...` アセットのパスを指定してください。

以下のシートは初回の該当取引時に自動作成されます。既存シートがある場合は列を確認してください。

| シート | 列 |
| --- | --- |
| `PurchaseHistoryYYMM` | `DateTime`, `UserID`, `ItemID`, `ItemName`, `Number`, `AfterPurchase`, `AmountSpent` |
| `TopupHistory` | `DateTime`, `UserID`, `Amount`, `AfterTopup` |
| `RegisterRequests` | `RequestID`, `Session`, `Payload`, `Result` |

購入履歴は既存と同じ、1取引1行・複数商品のカンマ区切りです。月の判定は日本時間です。
ギフト受領も `TopupHistory` に記録されます。ユーザーID `0` も通常の購入として更新されます。
従来の「ID 0だけ在庫・履歴を更新しない」例外はありません。

## 3. Flutterを設定する

リポジトリルートで `config/register.example.json` を `config/register.local.json` にコピーし、
`UPAY_GAS_URL` と `UPAY_REGISTER_API_KEY` を設定します。

```powershell
flutter pub get
flutter run -d windows --dart-define-from-file=config/register.local.json
```

WindowsでQRカメラが利用できない端末でも、自動テストは実行できます。
iPad用IPAの設定・ビルド手順は [README](../README.md#ipad用unsigned-ipa) を参照してください。
旧 `assets/credentials.json` がローカルに残っていてもアプリには同梱されず、コードからも参照しません。

## APIと再試行

| 呼び出し | 認証・主な入力 | 結果 |
| --- | --- | --- |
| GET | なし | 販売中商品一覧 |
| `verifyQrToken` | `apiKey`, `token` | `user`, `sessionToken` |
| `purchase` | `apiKey`, `sessionToken`, `requestId`, `items: [{itemId, quantity}]` | 更新後の `user`, `amount` |
| `topup` | 同上（itemsの代わりに `amount`） | 更新後の `user`, `amount` |
| `claimGift` | `apiKey`, `sessionToken`, `requestId` | 更新後の `user`, `amount` |

`sessionToken` / `requestId` は32桁の16進文字列です。ユーザーID、価格、更新後残高をクライアントから指定しても採用しません。
価格・在庫・残高をGASで再読込して計算し、ScriptLockでレジ間の処理を直列化します。
残高・在庫・累計・履歴・再試行用台帳はSheetsの `batchUpdate` で一括更新します。
いずれかが不正ならバッチ全体が失敗します。
([Google公式仕様](https://developers.google.com/workspace/sheets/api/reference/rest/v4/spreadsheets/batchUpdate))

通信失敗では成功表示せず、同じ画面から再試行できます。同一セッション・同一内容の再試行は同じ `requestId` を送り、
更新済みなら保存した結果を返します。購入後のセッションでは追加購入できません。
`RegisterRequests` は再試行判定に必要なので、運用中に削除・編集しないでください。

レジセッションはキャッシュに保存され、最長30分（早期削除される可能性もあります）で失効します。
アプリ再起動・QR再読取後は別セッションになるため、通信失敗後に画面を離れた場合は履歴と残高を確認してから再操作してください。
また、このロックは同じGASプロジェクト内にだけ有効です。旧Flutterや別スクリプトからの直接更新は停止し、
取引中に対象の残高・在庫を手編集しないでください。

## 動作確認

```powershell
node --test web-portal/backend/Code.test.cjs
flutter test --no-pub
```

実機では、ポータルのQR → 商品選択 → 購入 → ポータル残高・履歴の再表示、の順に確認します。
在庫が0になった商品の販売停止、残高不足時の拒否も開発用データで確認してください。
このリポジトリの変更だけでは、オンラインGASの更新やiOSビルドは実行されません。
