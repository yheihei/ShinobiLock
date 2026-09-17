# 2026年9月15日のApp Review指摘と9月16日の承認

## 結論

1.0.0のビルド13は、9月16日9:04 JSTにApp Reviewを通過し、日本のApp Storeで公開された。9月15日にFamily Controls権限について却下された後、同日13:19 JSTに承認日時と提出IPAの検証結果を返信して、再確認を依頼していた。ビルドを差し替えずに承認された。

Appleは9月16日9:01 JSTに情報提供への謝意と審査を続行する旨を返信し、9:04に審査完了、9:06に配布承認を通知した。最初の判定の原因は説明されていない。

[審査完了メール](https://mail.google.com/mail/u/?authuser=yheihei0126%40gmail.com#all/1a0a787c0e205b48) · [公開中のApp Storeページ](https://apps.apple.com/jp/app/id6811883726)

## Appleからの指摘

- 受信日時: 2026年9月15日12:52 JST。
- 対象: カルマロック、1.0.0、ビルド13、Apple ID `6811883726`。
- 提出ID: `8f6c6123-e7c1-47b2-8292-a38b0ccdfef5`。
- App Store Connectの表示: 却下済み、`2.5.1 Performance: Software Requirements`。
- 内容: Screen Time APIの使用を検出したが、Family Controls entitlementを伴って提出されていないため審査を進められない。
- App Reviewのメッセージは1件。本文はGmailの通知と一致した。

[審査通知メール](https://mail.google.com/mail/u/?authuser=yheihei0126%40gmail.com#all/1a0a332161bdab12) · [App Reviewの提出詳細](https://appstoreconnect.apple.com/apps/6811883726/distribution/reviewsubmissions/details/8f6c6123-e7c1-47b2-8292-a38b0ccdfef5)

## 確認した証拠

2026年9月14日20:35 JSTに、AppleからFamily Controlsの配布権限をアカウントへ付与したという[承認メール](https://mail.google.com/mail/u/?authuser=yheihei0126%40gmail.com#all/1a09fb32f0ffedb5)が届いている。

9月15日8:41にアップロードしたIPAがXcodeの一時出力に残っていた。ファイルのMD5が当時のContentDeliveryログと一致したため、そのIPAを展開して本体と3拡張を検査した。

| Bundle ID | 署名のFamily Controls | 配布プロファイルのFamily Controls | 署名検証 |
| --- | --- | --- | --- |
| `com.yhei.shinobilock` | true | true | 成功 |
| `com.yhei.shinobilock.DeviceActivityMonitor` | true | true | 成功 |
| `com.yhei.shinobilock.ShieldAction` | true | true | 成功 |
| `com.yhei.shinobilock.ShieldConfiguration` | true | true | 成功 |

すべてバージョン1.0.0、ビルド13。権限キーは `com.apple.developer.family-controls`。署名とプロファイルの `get-task-allow` はfalse。プロファイルはiOS Team Store Provisioning Profileで、登録端末リストや全端末配布指定もない。

アーカイブ自体は開発署名だが、アップロード時にApp Store用へ再署名されている。上表はアップロードしたIPAの結果。

- IPAのMD5: `9D2F7B5648521333DCD07B539AE76622`
- IPAのSHA-256: `6b7a91a9b00d43d3b95dfb270cdd636c52f69a519d93281b0201eede45199267`
- 証拠の保存先: `build/app-review-2026-09-15/signature-evidence.json`
- IPAの保存先: `build/app-review-2026-09-15/ShinobiLock-build13-uploaded.ipa`
- アップロード成功ログ: `build/app-store-upload-13.log`

Apple公式資料は、本体とScreen Time拡張の権限設定、配布用の承認、プロビジョニングプロファイルの更新を求めている。今回確認したIPAには、本体と3拡張の配布権限が含まれていた。

[Family Controls配布権限の申請](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) · [Family Controlsの設定](https://developer.apple.com/documentation/xcode/configuring-family-controls)

## Developerアカウントの追加確認

9月15日、返信後にApple Developerの管理画面を読み直した。本体と3拡張のApp IDすべてで、Family ControlsのDevelopmentとDistributionが有効だった。変更は加えていない。

本体のCapability RequestsにはFamily Controls (Distribution)がAssignedと表示された。Request Historyの申請ID `DK2MB8994V` は、2026年9月14日、TypeがTeam、StatusがApprovedだった。

| 対象 | App ID設定ページのID | Family Controls (Distribution) |
| --- | --- | --- |
| 本体 | `VJ9FWN2F66` | 有効 |
| DeviceActivityMonitor | `6A5NPW9Y6K` | 有効 |
| ShieldAction | `WFDLCGAUDD` | 有効 |
| ShieldConfiguration | `P6923HSR6U` | 有効 |

ソースでも、4ターゲットのDebug/Release設定がFamily Controls権限を含む `Config/Shared.entitlements` を参照していることを確認した。端末利用者から許可を得る処理は `App/LockModel.swift` の `requestAuthorization(for: .individual)` に実装されている。これはAppleから開発者への配布許可とは別に、利用者本人が端末で承認する手順になる。

以上から、Family Controlsに関して開発者側で必要な承認・設定・配布署名の作業は、確認できる範囲で完了している。App Reviewの却下理由との食い違いは未解決で、アプリ公開の承認はまだ得られていない。

## 対応の順序

1. App Store ConnectのApp Reviewから、以下の返信を送る。承認日時、本体と3拡張のBundle ID、アップロード済みIPAの確認結果を伝え、再確認を依頼する。
2. Appleが権限不足を再度指摘する場合は、不足と判定されたBundle IDと権限キーを確認する。DeveloperアカウントのCapability Requestsと4つのApp IDの配布設定を照合し、必要な箇所を直す。
3. Appleが新しいビルドを求める場合、または設定変更が必要だった場合は、配布プロファイルを更新してビルド番号を上げる。アップロード前にIPAの本体と3拡張を再検証し、再提出する。

9月15日13:19 JST、ユーザーの指示を受けて返信を送信した。App Reviewのメッセージ数が1件から2件になり、本人名義の13:19の返信と本文末尾までの表示を確認した。ファイル添付とビルドの再提出は行っていない。

## App Reviewへの送信済み本文

Hello App Review team,

We received the automated Family Controls entitlement message for Karma Lock (カルマロック), version 1.0.0, build 13.

Apple assigned the Family Controls distribution entitlement to our developer account on September 14, 2026 at 11:35 UTC. Our Team ID is U8E796F5BN.

We inspected the exact IPA used for the successful upload of build 13 on September 14, 2026 at 23:41 UTC. Its checksum matches the Xcode upload log. The code signatures and embedded App Store provisioning profiles all contain com.apple.developer.family-controls = true for these four bundle IDs:

- com.yhei.shinobilock
- com.yhei.shinobilock.DeviceActivityMonitor
- com.yhei.shinobilock.ShieldAction
- com.yhei.shinobilock.ShieldConfiguration

All four bundles are version 1.0.0, build 13, and use App Store distribution profiles with get-task-allow = false.

The app uses Screen Time APIs to let users schedule restrictions on their own selected apps, so this entitlement is required for its core functionality.

Could you please recheck the entitlement approval and the submitted build, and continue the review if the requirements are satisfied? If an entitlement is still missing, please identify the affected bundle ID and entitlement key so we can correct it. We can provide the approval email and the extracted entitlement details if needed.

App Apple ID: 6811883726

Submission ID: 8f6c6123-e7c1-47b2-8292-a38b0ccdfef5

Thank you.
