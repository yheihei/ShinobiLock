# カルマロック

カルマロックは、使いすぎを控えたいiPhoneアプリを、指定した曜日と時間帯にロックするアプリです。一時的に使いたいときは、リワード広告を視聴すると対象アプリだけを5分間解除できます。

1.0.0（ビルド12）はApp Store審査待ちです。ReleaseはカルマロックのAdMob広告IDを使用し、DebugはGoogleの公式テスト広告を表示します。

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

2026年9月14日には、実機で広告中断時のロック継続、視聴完了後の対象アプリだけの解除、本体終了後の5分再ロックをユーザーが確認しました。診断ログの期限通知は解除開始から約301秒でした。端末再起動・時刻変更・実際の通信断などの条件は未確認です。詳しい結果は[実機検証記録](docs/device-verification.md)を参照してください。

自動テストでは、週間ルールの重なり、アプリ件数の上限、期限の境界と時計変更、広告の重複・古いコールバック、カルマの台詞を検査します。OS通知の配信と再ロックのタイミングは実機での確認が必要です。

## データと広告

アプリの選択トークンやルールはAdMobへ渡しません。広告SDK自体は広告配信に必要な情報を扱います。広告リクエストでは非パーソナライズを指定し、Publisher First-party IDを無効にしています。本番ID使用時はUMPで同意状態を確認してから広告を要求します。Googleの共有テストアプリIDと公式テスト広告ユニットを同時に使う場合だけ、その確認を省略します。

SDKの`PrivacyInfo.xcprivacy`は各フレームワークに含まれます。

## 公開前の準備

2026年9月14日に本番のAdMobアプリ・リワード広告ユニットを作成しました。Family Controls配布権限はAppleが承認し、本体と3つのScreen Time拡張で有効化済みです。AdMobアカウントもGoogleの審査待ちです。同日22:21に1.0.0（ビルド12）をApp Reviewへ提出し、「審査待ち」を確認しました。初回は日本のみ・無料、承認後に自動公開する設定です。

- AdMobアカウントの承認と、公開後のストア情報の紐付け・アプリ確認
- App Store審査結果の確認と、指摘がある場合の対応

[サポートページ](https://yheihei.github.io/karma-lock/)と[プライバシーポリシー](https://yheihei.github.io/karma-lock/privacy.html)を公開しています。公開用の元ファイルは`docs/site/`、配信先は`yheihei/yheihei.github.io`です。AdMobの欧州向け同意メッセージは英語・日本語で公開済みです。

App Storeのプライバシー回答は公開済みです。Family Controlsを含む配布署名、Appleのビルド検証、アップロードと審査提出が完了しています。

起動時にUMPの同意情報を更新し、広告視聴を選んだときに必要な同意画面を表示します。本番アプリIDを使うDebugビルドでもUMPの処理を通します。Googleの共有テストアプリIDとテスト広告ユニットを同時に使う場合だけ、その確認を省略します。

## 関連資料

- [初回のカルマの案内](docs/onboarding.md)
- [ルールの削除・休止と広告確認](docs/deletion-scope.md)
- [一時解除の操作と画面仕様](docs/unlock-intent.md)
- [初期要件定義書](docs/app_lock_mvp_requirements.md)
- [実機検証記録](docs/device-verification.md)
- [App Store公開準備](docs/app-store-release.md)
- [画面と操作の説明](docs/design-reference/README.md)
- [カルマの間の画面と素材](docs/karma-room.md)
