# UPay

FlutterレジとWeb残高ポータルは、`web-portal/backend/Code.gs` の `SPREADSHEET_ID` で指定した同じ開発用スプレッドシートを使います。
FlutterはGASへHTTPリクエストを送り、Google Sheetsへの読み書きはGASが実行します。
`credentials.json`、サービスアカウント、`UPAY_CREDENTIALS_JSON` は不要です。

## 初回設定

先に [GAS移行・設定手順](docs/gas-register.md) の手順に従い、GASを更新してください。
必要なのはGASの `/exec` URLとレジ用APIキーです。APIキーはGoogleの秘密鍵とは別の、レジAPIを保護する値です。

Windowsでの実行例（このREADMEがあるフォルダで実行）:

```powershell
Copy-Item config/register.example.json config/register.local.json
# register.local.json のURLを確認し、APIキーを設定する
flutter pub get
flutter run -d windows --dart-define-from-file=config/register.local.json
```

`register.local.json` はGit管理対象外です。設定例のURLはWebポータルの既存URLと同じですが、GASの再デプロイが必要です。

## iPad用unsigned IPA

Gitリポジトリのルートは `Develop_Upay`（`pubspec.yaml` があるフォルダ）です。
`.github/workflows/ios.yml` はFlutter 3.47.2 / macOSで手動ビルドします。対象はiPadOS 15.0以降です。

1. GitHubの **Settings → Secrets and variables → Actions** で以下を登録します。
   - **Variables**: `UPAY_GAS_URL` = GAS Webアプリの `/exec` URL
   - **Secrets**: `UPAY_REGISTER_API_KEY` = GASのスクリプトプロパティ `REGISTER_API_KEY` と同じ値
2. 変更をデフォルトブランチへpushします。
3. **Actions → Build iOS IPA → Run workflow** を実行します。
4. 成功した実行の **Artifacts → UPay-unsigned** をダウンロードし、外側のZIPを解凍します。
5. `UPay-unsigned.ipa` をWindowsのSideloadlyへ渡して、自分のApple Accountで署名・インストールします。
6. iPad側で必要な開発者の信頼・開発者モード設定を行い、QR読み取り時にカメラを許可します。

Appleの証明書やApple AccountをGitHubへ登録する必要はありません。
IPAにはレジAPIキーが組み込まれるので、研究室の管理端末に限定してください。Artifact保存期間は1日です。
Actionsの料金はプラン・利用枠によります。署名更新はWindows側で行います。

## ローカル検証

```powershell
node --test web-portal/backend/Code.test.cjs
flutter test --no-pub
```

これらは実スプレッドシートに接続しないテストです。GASへのデプロイ後、開発用データで起動・QR検証・購入・在庫・履歴を確認してください。

iOSビルドの説明: [Flutter公式](https://docs.flutter.dev/deployment/ios)、[Flutter Action](https://github.com/subosito/flutter-action)。