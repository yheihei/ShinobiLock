# カルマロック

カルマロックは、使いすぎを控えたいiPhoneアプリを、指定した曜日と時間帯にロックするアプリです。一時的に使いたいときは、リワード広告を視聴すると対象アプリだけを5分間解除できます。

現在は実機検証中の開発版です。Googleの公式テスト広告を使用しています。

## 主な機能

- 初回の使い方案内。スキップでき、設定から読み直せます。
- スクリーンタイムの利用許可と、許可状態の確認。
- 曜日・時間帯・対象アプリを指定するルールの作成、編集、削除、休止。
- カテゴリからのアプリ一括選択と、保存するアプリ一覧の確認。
- 時間帯が重なる複数ルールの適用。
- ロック画面からの一時解除。広告視聴後に対象アプリだけを5分間解除し、残り時間を表示します。視聴のキャンセルや失敗時はロックを継続します。
- Device Activity通知による解除期限後の再ロック。
- 個別ルールの削除・休止前に「カルマの間」と広告を表示。視聴が完了すると変更を適用します。
- 設定とアプリの選択情報を端末内に保存。

カテゴリ選択では、その時点で選んだ個別アプリをルールに保存します。後からインストールしたアプリは、ルールを編集して追加してください。Webサイトはロック対象外です。

## 開発

Xcode 26.6、iOS 26.5以降のiPhone、Apple Developer Programのチームが必要です。本体と3つのScreen Time拡張を含みます。シミュレータだけでは他アプリのロックを検証できません。

1. `Config/Local.xcconfig.example`を`Config/Local.xcconfig`へコピーし、チームIDと固有のBundle ID接頭辞を設定します。
2. 本体と各拡張でFamily Controlsと同じApp Groupを有効にします。
3. `ShinobiLock.xcodeproj`を開き、実機で`ShinobiLock`スキームを実行します。

Swift Package ManagerがGoogle Mobile Ads 13.9.0とUser Messaging Platform 3.1.0を取得します。解決済みバージョンは`Package.resolved`に記録しています。

コアロジックのテストと実機向けビルドは、次のコマンドで実行できます。

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project ShinobiLock.xcodeproj -scheme ShinobiLock \
  -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates build
```

ソース追加時は`python3 scripts/generate_project.py`でプロジェクトを再生成します。アイコンは`xcrun swift scripts/generate_icon.swift App/Assets.xcassets/AppIcon.appiconset`で元のベクター定義から生成できます。

## 検証状況

2026年9月12日の試作では、iPhone 12 mini / iOS 26.6.2でロック画面の表示、本体への移動、解除対象アプリの引き継ぎを確認しました。バックグラウンド中の再ロックは1回、開始から約5分2秒で動作しました。

週間ルールと広告フロー、複数アプリの個別解除、本体強制終了・再起動・時刻変更後の動作は、実機での検証が完了していません。詳しい結果と未確認項目は[実機検証記録](docs/device-verification.md)を参照してください。

自動テストでは、週間ルールの重なり、アプリ件数の上限、期限の境界と時計変更、広告の重複・古いコールバック、カルマの台詞を検査します。OS通知の配信と再ロックのタイミングは実機での確認が必要です。

## データと広告

アプリの選択トークンやルールはAdMobへ渡しません。広告SDK自体は広告配信に必要な情報を扱います。広告リクエストでは非パーソナライズを指定し、Publisher First-party IDを無効にしています。本番ID使用時はUMPで同意状態を確認してから広告を要求します。Googleの共有テストアプリIDには同意メッセージ設定がないため、公式テストユニットに限ってその確認を省略します。

SDKの`PrivacyInfo.xcprivacy`は各フレームワークに含まれます。

## 公開前の準備

本番のAdMob IDとFamily Controls配布権限は未設定です。広告による解除を含むApp Store審査も未実施です。公開前に以下を準備してください。

- AdMobの本番IDとプライバシーメッセージの設定
- 公開プライバシーポリシーと、広告SDKの収集内容を含むApp Storeのプライバシー回答
- 本体と各Screen Time拡張のFamily Controls配布権限
- 週間ルール、一時解除、再ロックの実機検証

## 関連資料

- [初回のカルマの案内](docs/onboarding.md)
- [ルールの削除・休止と広告確認](docs/deletion-scope.md)
- [一時解除の操作と画面仕様](docs/unlock-intent.md)
- [初期要件定義書](docs/app_lock_mvp_requirements.md)
- [実機検証記録](docs/device-verification.md)
- [画面と操作の説明](docs/design-reference/README.md)
- [カルマの間の画面と素材](docs/karma-room.md)
