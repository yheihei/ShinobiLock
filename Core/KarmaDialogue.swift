import Foundation

enum KarmaContext: String, CaseIterable {
    case unlock, pauseRule, deleteRule
}

enum KarmaPortrait: String, CaseIterable {
    case sadBust = "karma-sad-bust"
    case disappointedFront = "karma-disappointed-front"
    case sadLookaway = "karma-sad-lookaway"
    case coolSmirk = "karma-cool-smirk"
    case coolFoldedArms = "karma-cool-folded-arms"
    case coolSideEye = "karma-cool-side-eye"
    case coolAppraising = "karma-cool-appraising"
    case coolKnowing = "karma-cool-knowing"
    case coolQuestioning = "karma-cool-questioning"
    case coolUnimpressed = "karma-cool-unimpressed"
    case coolScarf = "karma-cool-scarf"
    case coolLookingBack = "karma-cool-looking-back"
    case coolHandOnHip = "karma-cool-hand-on-hip"

    var description: String {
        switch self {
        case .sadBust: return "寂しそうに目を伏せるカルマ"
        case .disappointedFront: return "悲しそうにこちらを見つめるカルマ"
        case .sadLookaway: return "視線をそらすカルマ"
        case .coolSmirk: return "正面からニヒルな薄笑いを浮かべるカルマ"
        case .coolFoldedArms: return "右斜めを向き、腕を組んで見つめるカルマ"
        case .coolSideEye: return "左斜めを向き、横目で薄く笑うカルマ"
        case .coolAppraising: return "右横顔で顎に手を添えるカルマ"
        case .coolKnowing: return "左横顔で目を閉じ、含み笑いをするカルマ"
        case .coolQuestioning: return "上を見上げ、片眉を上げて問いかけるカルマ"
        case .coolUnimpressed: return "低い位置のこちらを無言で見据えるカルマ"
        case .coolScarf: return "右肩越しに振り返って薄く笑うカルマ"
        case .coolLookingBack: return "左肩越しに静かに振り返るカルマ"
        case .coolHandOnHip: return "腰に手を置き、余裕のある笑みを浮かべるカルマ"
        }
    }
}

struct KarmaEncounter: Identifiable {
    let id = UUID()
    let line: String
    let portrait: KarmaPortrait
    let stayedLine: String
}

struct KarmaDialogueCatalog: Decodable {
    let unlockBeforeAd: [String]
    let stayed: [String]
    let pauseBeforeAd: [String]
    let deleteBeforeAd: [String]
    let ruleStayed: [String]
    let onboarding: [String]

    enum CodingKeys: String, CodingKey {
        case unlockBeforeAd = "unlock_before_ad"
        case stayed
        case pauseBeforeAd = "pause_before_ad"
        case deleteBeforeAd = "delete_before_ad"
        case ruleStayed = "rule_stayed"
        case onboarding
    }

    init(unlockBeforeAd: [String], stayed: [String], pauseBeforeAd: [String] = [],
         deleteBeforeAd: [String] = [], ruleStayed: [String] = [], onboarding: [String] = []) {
        self.unlockBeforeAd = unlockBeforeAd
        self.stayed = stayed
        self.pauseBeforeAd = pauseBeforeAd
        self.deleteBeforeAd = deleteBeforeAd
        self.ruleStayed = ruleStayed
        self.onboarding = onboarding
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        unlockBeforeAd = try values.decodeIfPresent([String].self, forKey: .unlockBeforeAd) ?? []
        stayed = try values.decodeIfPresent([String].self, forKey: .stayed) ?? []
        pauseBeforeAd = try values.decodeIfPresent([String].self, forKey: .pauseBeforeAd) ?? []
        deleteBeforeAd = try values.decodeIfPresent([String].self, forKey: .deleteBeforeAd) ?? []
        ruleStayed = try values.decodeIfPresent([String].self, forKey: .ruleStayed) ?? []
        onboarding = try values.decodeIfPresent([String].self, forKey: .onboarding) ?? []
    }

    static let fallback = KarmaDialogueCatalog(
        unlockBeforeAd: ["……責めはしない。\nただ、5分の先に何がある？"],
        stayed: ["……そうか。\n今日は、鎖を握ったままか。"],
        pauseBeforeAd: ["……この約束を、休ませるのか。\n決めたときの理由を、覚えているか？"],
        deleteBeforeAd: ["……この約束を、消すのか。\nここで守りたかった時間は、どうする？"],
        ruleStayed: ["……そうか。\nおまえの決めたこと、ここに残しておく。"],
        onboarding: [
            "カルマだ。\nここでは、余計なアプリを縛る。\n……おまえには、ほかに\nやることがあるはずだからな。",
            "曜日と時間、縛るアプリを決めろ。\nまずは一つでいい。\n……守り切るところから始めるぞ。",
            "広告を最後まで見れば、\n5分だけ鎖が緩む。\n……その手前で踏みとどまる方に、\n賭けているがな。",
            "……行ってこい。\n終わったら、堂々としていろ。\n自分で決めて、守ったんだからな。"
        ]
    )

    // Keep each page's meaning when an older or partially edited catalog is loaded.
    func onboardingLine(at page: Int) -> String {
        guard Self.fallback.onboarding.indices.contains(page) else { return "" }
        guard onboarding.indices.contains(page),
              !onboarding[page].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Self.fallback.onboarding[page]
        }
        return onboarding[page]
    }

    func lines(for context: KarmaContext) -> [String] {
        switch context {
        case .unlock: return unlockBeforeAd
        case .pauseRule: return pauseBeforeAd
        case .deleteRule: return deleteBeforeAd
        }
    }

    func encounter<R: RandomNumberGenerator>(context: KarmaContext = .unlock,
                                             previousLine: String?, previousPortrait: KarmaPortrait?,
                                             using random: inout R) -> KarmaEncounter {
        let lines = lines(for: context).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let differentLines = lines.filter { $0 != previousLine }
        let line = (differentLines.isEmpty ? lines : differentLines).randomElement(using: &random)
            ?? Self.fallback.lines(for: context)[0]
        let portrait = previousPortrait == nil ? .coolSmirk :
            KarmaPortrait.allCases.filter { $0 != previousPortrait }.randomElement(using: &random) ?? .coolSmirk
        let responses = (context == .unlock ? stayed : ruleStayed)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let fallbackResponse = context == .unlock ? Self.fallback.stayed[0] : Self.fallback.ruleStayed[0]
        return KarmaEncounter(line: line, portrait: portrait,
                              stayedLine: responses.randomElement(using: &random) ?? fallbackResponse)
    }
}
