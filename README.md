# 忍びロック

指定した曜日と時間帯に、選んだiPhoneアプリをロックします。必要なときは、自分でリワード広告の視聴を選び、そのアプリだけ5分間使えます。

現在は実機検証中の開発版です。初版から起動・押下回数の表示を外す方針は、2026年9月12日にユーザーが了承しています。

実装済みの機能:

- 個人向けスクリーンタイムの許可と許可状態の表示
- 曜日・時間帯・対象アプリを選ぶルールの作成、編集、削除、休止
- カテゴリからのアプリ一括選択と、保存対象のアプリ一覧。Webサイトは対象外
- 重複するルールの対象アプリの合算
- Shieldから解除対象を本体へ引き継ぐ処理
- リワード広告の報酬通知による5分解除。キャンセル・失敗時はロック継続
- 残り時間の表示、OSのDevice Activity通知による再ロック
- 設定・選択トークンの端末内保存と全ルールの一括休止

Googleの公式テスト広告を使用しています。本番のAdMob IDとFamily Controls配布権限は未設定です。広告方式のApp Store審査は未実施で、承認を保証するものではありません。

カテゴリ選択では、その時点で選んだ個別アプリをルールに保存します。後からインストールしたアプリは、ルールを編集して追加してください。カテゴリ自体やWebサイトを継続的にロックする機能は含みません。

## 開発

Xcode 26.6、iOS 26.5以降のiPhone、Apple Developer Programのチームが必要です。本体と3つのScreen Time拡張を含みます。シミュレータだけでは他アプリのロックを検証できません。

1. `Config/Local.xcconfig.example`を`Config/Local.xcconfig`へコピーし、チームIDと固有のBundle ID接頭辞を設定します。
2. 本体と各拡張でFamily Controlsと同じApp Groupを有効にします。
3. `ShinobiLock.xcodeproj`を開き、実機で`ShinobiLock`スキームを実行します。

Swift Package ManagerがGoogle Mobile Ads 13.9.0とUser Messaging Platform 3.1.0を取得します。解決済みバージョンは`Package.resolved`に固定しています。独立した追加アプリのインストールは不要です。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ShinobiLock.xcodeproj -scheme ShinobiLock \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates build
```

ソース追加時は`python3 scripts/generate_project.py`でプロジェクトを再生成します。アイコンは`xcrun swift scripts/generate_icon.swift App/Assets.xcassets/AppIcon.appiconset`で元のベクター定義から生成できます。

## 実機で確認した範囲

試作では、iPhone 12 mini / iOS 26.6.2でShield表示、本体への移動、対象トークンの受け渡しを確認しました。バックグラウンド中の再ロックは1回、開始から約5分2秒で動作しました。

現行の週間ルールと広告フロー、複数アプリの分離、本体強制終了・再起動・時刻変更後の動作は、まだ受入検証を終えていません。自動テスト17件は週間ルールの重なり、アプリ件数の上限、期限の境界と時計変更、広告の重複・古いコールバックを検査します。OS通知の到着を保証するテストではありません。

## データと広告

アプリの選択トークンやルールはAdMobへ渡しません。広告SDK自体は広告配信に必要な情報を扱います。広告リクエストでは非パーソナライズを指定し、Publisher First-party IDを無効にしています。本番ID使用時はUMPで同意状態を確認してから広告を要求します。Googleの共有テストアプリIDには同意メッセージ設定がないため、公式テストユニットに限ってその確認を省略します。

SDKのPrivacyInfo.xcprivacyは各フレームワークに含まれます。公開時にはSDKを含む収集内容でApp Storeのプライバシー回答を作成し、AdMobのプライバシーメッセージ、本番ID、公開プライバシーポリシー、Family Controls配布権限を設定してください。

- [元の要件定義書](docs/app_lock_mvp_requirements.md)
- [実機検証記録](docs/device-verification.md)

元の要件書は変更していません。キャラクター素材は使っておらず、採用する場合は[指定リポジトリ](https://github.com/omikirin/MCP)を参照します。
