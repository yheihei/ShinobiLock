import Foundation
import XCTest
@testable import ShinobiLockCore

final class KarmaDialogueTests: XCTestCase {
    func testConsecutiveEncountersChangeBothLineAndPortrait() {
        let catalog = KarmaDialogueCatalog(unlockBeforeAd: ["一", "二", "三"], stayed: ["留まる"])
        var random = SystemRandomNumberGenerator()
        var previous = catalog.encounter(previousLine: nil, previousPortrait: nil, using: &random)
        XCTAssertEqual(previous.portrait, .coolSmirk)
        for _ in 0..<100 {
            let next = catalog.encounter(previousLine: previous.line, previousPortrait: previous.portrait, using: &random)
            XCTAssertNotEqual(next.line, previous.line)
            XCTAssertNotEqual(next.portrait, previous.portrait)
            XCTAssertTrue(catalog.unlockBeforeAd.contains(next.line))
            XCTAssertEqual(next.stayedLine, "留まる")
            previous = next
        }
    }

    func testAdFailureUsesSadPortraitsAndNonrepeatingLines() {
        let catalog = KarmaDialogueCatalog(unlockBeforeAd: [], stayed: [], adUnavailable: ["一", "二", "三"])
        var random = SystemRandomNumberGenerator()
        var previousLine: String?
        var previousPortrait: KarmaPortrait?
        for _ in 0..<30 {
            let next = catalog.encounter(context: .adUnavailable, previousLine: previousLine,
                                         previousPortrait: previousPortrait, using: &random)
            XCTAssertNotEqual(next.line, previousLine)
            XCTAssertNotEqual(next.portrait, previousPortrait)
            XCTAssertTrue([KarmaPortrait.sadBust, .disappointedFront, .sadLookaway].contains(next.portrait))
            previousLine = next.line
            previousPortrait = next.portrait
        }
        let fallback = KarmaDialogueCatalog.fallback.encounter(context: .adUnavailable,
                                                               previousLine: nil, previousPortrait: nil, using: &random)
        XCTAssertFalse(fallback.line.isEmpty)
        XCTAssertEqual(fallback.portrait == .coolSmirk, false)
    }

    func testSingleLineAndDuplicateLinesRemainUsable() {
        let catalog = KarmaDialogueCatalog(unlockBeforeAd: ["一", "一"], stayed: ["留まる"])
        var random = SystemRandomNumberGenerator()
        let encounter = catalog.encounter(previousLine: "一", previousPortrait: .sadBust, using: &random)
        XCTAssertEqual(encounter.line, "一")
        XCTAssertNotEqual(encounter.portrait, .sadBust)
    }

    func testEmptyEditedDialogueFallsBackToReadableLines() {
        let catalog = KarmaDialogueCatalog(unlockBeforeAd: ["", " \n"], stayed: [])
        var random = SystemRandomNumberGenerator()
        let encounter = catalog.encounter(previousLine: nil, previousPortrait: nil, using: &random)
        XCTAssertEqual(encounter.line, KarmaDialogueCatalog.fallback.unlockBeforeAd[0])
        XCTAssertEqual(encounter.stayedLine, KarmaDialogueCatalog.fallback.stayed[0])
    }

    func testShippingDialogueAndPortraitAssetsArePresent() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("App/Resources/karma-lines.json"))
        let catalog = try JSONDecoder().decode(KarmaDialogueCatalog.self, from: data)
        XCTAssertGreaterThan(catalog.unlockBeforeAd.count, 1)
        XCTAssertEqual(Set(catalog.unlockBeforeAd).count, catalog.unlockBeforeAd.count)
        XCTAssertEqual(catalog.adUnavailable.count, 10)
        XCTAssertEqual(Set(catalog.adUnavailable).count, 10)
        XCTAssertFalse(catalog.stayed.isEmpty)
        XCTAssertGreaterThan(catalog.pauseBeforeAd.count, 1)
        XCTAssertGreaterThan(catalog.deleteBeforeAd.count, 1)
        XCTAssertFalse(catalog.ruleStayed.isEmpty)
        for portrait in KarmaPortrait.allCases {
            let path = "App/Assets.xcassets/\(portrait.rawValue).imageset/\(portrait.rawValue).png"
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }

    func testRuleActionsUseTheirOwnDialogueAndCancellationResponse() {
        let catalog = KarmaDialogueCatalog(unlockBeforeAd: ["5分解除"], stayed: ["解除しない"],
                                           pauseBeforeAd: ["休止を確認"], deleteBeforeAd: ["削除を確認"],
                                           ruleStayed: ["ルールを残す"])
        var random = SystemRandomNumberGenerator()
        let pause = catalog.encounter(context: .pauseRule, previousLine: nil, previousPortrait: nil, using: &random)
        let delete = catalog.encounter(context: .deleteRule, previousLine: nil, previousPortrait: nil, using: &random)
        XCTAssertEqual(pause.line, "休止を確認")
        XCTAssertEqual(delete.line, "削除を確認")
        XCTAssertEqual(pause.stayedLine, "ルールを残す")
        XCTAssertEqual(delete.stayedLine, "ルールを残す")
    }

    func testOldEditableCatalogStillLoadsWithActionSpecificFallbacks() throws {
        let data = Data(#"{"unlock_before_ad":["既存の台詞"],"stayed":["留まる"]}"#.utf8)
        let catalog = try JSONDecoder().decode(KarmaDialogueCatalog.self, from: data)
        var random = SystemRandomNumberGenerator()
        for context in [KarmaContext.pauseRule, .deleteRule] {
            let encounter = catalog.encounter(context: context, previousLine: nil, previousPortrait: nil, using: &random)
            XCTAssertEqual(encounter.line, KarmaDialogueCatalog.fallback.lines(for: context)[0])
            XCTAssertEqual(encounter.stayedLine, KarmaDialogueCatalog.fallback.ruleStayed[0])
            XCTAssertFalse(encounter.line.contains("5分"))
        }
        let unlock = catalog.encounter(previousLine: nil, previousPortrait: nil, using: &random)
        XCTAssertEqual(unlock.line, "既存の台詞")
        XCTAssertEqual(unlock.stayedLine, "留まる")
    }

    func testOnboardingPreservesPageMeaningWhenCatalogIsMissingOrPartiallyEdited() throws {
        let oldCatalog = try JSONDecoder().decode(KarmaDialogueCatalog.self, from: Data("{}".utf8))
        let edited = KarmaDialogueCatalog(unlockBeforeAd: [], stayed: [], onboarding: ["新しい挨拶", " \n"])
        XCTAssertEqual(edited.onboardingLine(at: 0), "新しい挨拶")
        for page in 0..<4 {
            XCTAssertEqual(oldCatalog.onboardingLine(at: page), KarmaDialogueCatalog.fallback.onboarding[page])
            if page > 0 {
                XCTAssertEqual(edited.onboardingLine(at: page), KarmaDialogueCatalog.fallback.onboarding[page])
            }
        }
        XCTAssertEqual(edited.onboardingLine(at: -1), "")
        XCTAssertEqual(edited.onboardingLine(at: 4), "")
    }

    func testShippingOnboardingHasFourPagesAndSuppliedPortraits() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("App/Resources/karma-lines.json"))
        let catalog = try JSONDecoder().decode(KarmaDialogueCatalog.self, from: data)
        XCTAssertEqual(catalog.onboarding.count, 4)
        for line in catalog.onboarding {
            let displayLines = line.components(separatedBy: "\n")
            XCTAssertLessThanOrEqual(displayLines.count, 4)
            for displayLine in displayLines {
                XCTAssertLessThanOrEqual(displayLine.count, 16)
            }
            XCTAssertFalse(line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        for field in ["曜日", "時間", "アプリ"] {
            XCTAssertTrue(catalog.onboarding[1].contains(field))
        }
        XCTAssertTrue(catalog.onboarding[2].contains("5分"))
        for portrait in ["karma-onboarding-intro", "karma-onboarding-rules", "karma-onboarding-unlock", "karma-onboarding-farewell"] {
            let path = "App/Assets.xcassets/\(portrait).imageset/\(portrait).png"
            XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path))
        }
    }
}
