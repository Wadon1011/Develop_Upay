# UPay 残高確認ポータル（デモ）

研究室メンバーがGoogleアカウントでサインインし、自分の残高（スプレッドシート上の`UserData`シートの値）を確認し、購買に使うQRコードを表示できる、シンプルなWebポータルのデモです。QRコードの中身は固定のユーザーIDではなく、GASが発行する短命・使い捨てのトークンで、一定時間ごとに自動的に更新されます。

## 構成

```
web-portal/
├── frontend/
│   └── index.html   # Googleサインイン + 残高表示 + ユーザーIDのQRコード生成
├── backend/
│   └── Code.gs       # Google Apps Script（IDトークン検証 + スプレッドシート検索、残高とユーザーIDを返す）
└── README.md
```

## このデモの制限事項

- **購入・チャージ機能はありません。** 残高の閲覧のみです。
- 既存のFlutterアプリ（`upay_ver01`）とは完全に独立しており、既存アプリのコード・ビルド設定・秘密鍵には一切依存しません。
- スプレッドシートへの書き込みは行いません（読み取りのみ）。
- `UserData`シートに「メールアドレス列」が存在しない場合は動作しません。既存のFlutterアプリのシート構成にはメールアドレス列がないため、このデモを使う場合は別途メールアドレス列を追加する必要があります。
- QRコード生成には「ユーザーID列」（例: `UserID`）が必要です。見つからない場合は残高だけ表示し、QRコードの代わりに案内メッセージを出します。
- QRコードの生成はブラウザ側でCDN配信の`qrcodejs`ライブラリを使って行います（バックエンドは画像を生成しません）。オフライン環境で使う場合はライブラリをローカルに同梱してください。
- 認可は「Googleアカウントでログインできること」のみで、シート上にそのメールアドレスの行があるかどうかで残高照会の可否を判定しています。UPayの独自ユーザーIDとの紐付けなどは行っていません。
- QRコードの検証API（`verifyQrToken`）は用意していますが、実際のレジ端末（既存のFlutterアプリ）からこのAPIを呼び出す改修は行っていません。レジ端末は依然として自身が読み込んだユーザー一覧とローカルで照合しており、別のスプレッドシートを参照しています。QRコードの中身を使い捨てトークン化したことと、レジ側でそれを検証することは別の作業です。

## 仕組み

1. `frontend/index.html` を開くと、Google Identity Services (GIS) のサインインボタンが表示されます。
2. サインインすると、GoogleからIDトークン（JWT）が発行されます。
3. フロントエンドはそのIDトークンを、GASのWebアプリ（`backend/Code.gs`）にPOSTします。
4. GAS側は `https://oauth2.googleapis.com/tokeninfo` にアクセスしてIDトークンを検証し、`aud`（トークンの発行先クライアントID）が想定するクライアントIDと一致するかを確認します。
5. 検証済みのメールアドレス（正規化のため小文字化）を使い、スプレッドシートの`UserData`シートを検索します。列位置はヘッダー行から動的に取得するため、列の並び順が変わっても追従できます。
6. 該当行があれば残高とユーザーID（数字のみの場合は5桁ゼロ埋め）を、なければエラーをJSONで返します。
7. フロントエンドは残高を表示したうえで、`action: 'issueQrToken'`をGASにPOSTし、ランダムなワンタイムトークン（有効期限120秒、`CacheService`に保存）を発行してもらいます。QRコードにはこのトークンだけを載せ、ユーザーIDそのものは含めません。
8. トークンは有効期限が近づくたびにフロントエンドが自動的に再発行し、QRコードを描き直します（画面に表示され続けている間、内容は常に変化します）。そのため「QRコードを保存する」機能はあえて廃止しました（保存すると使い捨てトークンが実質的に固定の秘密情報に戻ってしまうため）。
9. GAS側には`action: 'verifyQrToken'`（token・apiKeyを受け取り、対応するUserIDを返して該当トークンを即座に無効化する）も用意していますが、これを呼び出す検証側（レジ端末等）の実装は本デモのスコープ外です。呼び出す場合は`Code.gs`内の`REGISTER_API_KEY`を推測困難な値に必ず変更してください。

サービスアカウントの秘密鍵は一切使用しません。スプレッドシートへのアクセスは、GASスクリプトをデプロイしたGoogleアカウント自身の権限で行われます。

## デプロイ手順

### 1. Google Cloud ConsoleでOAuthクライアントIDを発行する

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセスし、対象プロジェクトを選択（または新規作成）。
2. 「APIとサービス」→「OAuth同意画面」を設定（社内利用なら「内部」を選択可能な場合はそちらを推奨）。
3. 「APIとサービス」→「認証情報」→「認証情報を作成」→「OAuthクライアントID」。
4. アプリケーションの種類は **ウェブアプリケーション** を選択。
5. 「承認済みのJavaScript生成元」に、フロントエンドを配信するURL（例: `https://your-domain.example.com` や、ローカルテスト用の `http://localhost:8000` など）を追加。
6. 発行された **クライアントID**（`xxxxxxxx.apps.googleusercontent.com`の形式）を控える。

### 2. GAS（Google Apps Script）Webアプリのデプロイ

1. [Google Apps Script](https://script.google.com/) にアクセスし、新しいプロジェクトを作成。
2. デフォルトの `Code.gs` の内容を、このリポジトリの `backend/Code.gs` の内容で置き換える。
3. スクリプト上部にある以下の2つの定数を実際の値に書き換える。
   - `CLIENT_ID` … 手順1で発行したOAuthクライアントID
   - `SPREADSHEET_ID` … 残高データが入っているスプレッドシートのID（スプレッドシートのURL `https://docs.google.com/spreadsheets/d/【ここ】/edit` の部分）
4. 対象スプレッドシートの`UserData`シートに、少なくとも「メールアドレス列」「残高列」「ユーザーID列」を用意する（列名の例: `Email` / `メールアドレス`、`Balance` / `残高`、`UserID`。詳細候補は`Code.gs`内の`EMAIL_HEADER_CANDIDATES` / `BALANCE_HEADER_CANDIDATES` / `USERID_HEADER_CANDIDATES`を参照）。QRコードのトークン有効期限は`Code.gs`内の`QR_TOKEN_TTL_SECONDS`（既定`120`秒）で調整できます。
5. 右上の「デプロイ」→「新しいデプロイ」。
6. 種類の選択で「ウェブアプリ」を選択。
   - 実行するユーザー: 自分（このアカウントの権限でスプレッドシートにアクセスします）
   - アクセスできるユーザー: 用途に応じて選択（研究室内のみなら「アカウントを持つ全員」など、公開範囲を必要最小限に絞ることを推奨）
7. デプロイすると **ウェブアプリのURL**（`https://script.google.com/macros/s/xxxxxxxxxxxx/exec`の形式）が発行されるので控える。
8. スプレッドシートを、このスクリプトを実行するGoogleアカウントが閲覧できる状態にしておく（自分がオーナー/編集者のシートであれば通常は追加設定不要）。

### 3. フロントエンドの設定とホスティング

1. `frontend/index.html` を開き、上部の設定値を書き換える。
   - `GOOGLE_CLIENT_ID` … 手順1で発行したOAuthクライアントID（`Code.gs`の`CLIENT_ID`と必ず同じ値にする）
   - `GAS_WEB_APP_URL` … 手順2で発行したGAS WebアプリのURL
2. 静的ファイルなので、任意の静的ホスティングで配信できます（例: GitHub Pages, Firebase Hosting, 学内の静的ファイルサーバーなど）。
3. ローカルで動作確認する場合、`file://`で直接開くとGoogle Identity Servicesが正しく動作しないことがあるため、簡易HTTPサーバー経由でアクセスしてください。

```bash
cd web-portal/frontend
python -m http.server 8000
```

上記の場合、ブラウザで `http://localhost:8000` を開き、手順1のOAuthクライアントIDの「承認済みのJavaScript生成元」に `http://localhost:8000` を追加しておく必要があります。

## CLIENT_IDとSPREADSHEET_IDの設定箇所まとめ

| 設定値 | 設定ファイル | 変数名 |
| --- | --- | --- |
| Google OAuthクライアントID | `frontend/index.html` | `GOOGLE_CLIENT_ID` |
| Google OAuthクライアントID（同じ値） | `backend/Code.gs` | `CLIENT_ID` |
| GAS WebアプリURL | `frontend/index.html` | `GAS_WEB_APP_URL` |
| スプレッドシートID | `backend/Code.gs` | `SPREADSHEET_ID` |

`GOOGLE_CLIENT_ID`（フロントエンド）と`CLIENT_ID`（バックエンド）は必ず同じ値にしてください。一致しない場合、バックエンド側のトークン検証で常にエラーになります。
