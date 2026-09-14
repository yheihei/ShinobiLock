import SwiftUI
import UIKit

// Store the last choices locally so reopening the sheet or app cannot repeat them.
enum KarmaDialogue {
    static let catalog: KarmaDialogueCatalog = {
        guard let url = Bundle.main.url(forResource: "karma-lines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(KarmaDialogueCatalog.self, from: data) else {
            return .fallback
        }
        return catalog
    }()

    static func next(context: KarmaContext = .unlock, defaults: UserDefaults = .standard) -> KarmaEncounter {
        var random = SystemRandomNumberGenerator()
        let lineKey = context == .unlock ? "karma.lastLine" : "karma.lastLine." + context.rawValue
        let encounter = catalog.encounter(
            context: context,
            previousLine: defaults.string(forKey: lineKey),
            previousPortrait: defaults.string(forKey: "karma.lastPortrait").flatMap(KarmaPortrait.init(rawValue:)),
            using: &random
        )
        defaults.set(encounter.line, forKey: lineKey)
        defaults.set(encounter.portrait.rawValue, forKey: "karma.lastPortrait")
        return encounter
    }
}

struct KarmaRoomView: View {
    let encounter: KarmaEncounter
    var context: KarmaContext = .unlock
    let continueToAd: () -> Void
    let stayLocked: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var staying = false
    @State private var continuing = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 700
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(spacing: 12) {
                                brand.padding(.top, 16)
                                portrait(size: 160)
                                dialogue(compact: true)
                            }
                            .padding(.bottom, 24)
                            .frame(maxWidth: .infinity)
                        }
                        actions(compact: true).padding(.top, 12).padding(.bottom, 16)
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: 520).frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            brand.frame(height: compact ? 64 : 76)
                            Spacer(minLength: compact ? 8 : 24)
                            portrait(size: compact ? 220 : 280)
                                .padding(.bottom, compact ? 4 : 8)
                            dialogue(compact: compact)
                            Spacer(minLength: compact ? 28 : 48)
                            actions(compact: compact)
                        }
                        .padding(.horizontal, compact ? 20 : 24)
                        .padding(.bottom, compact ? 16 : 20)
                        .frame(maxWidth: 520)
                        .frame(minHeight: geometry.size.height)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background {
                Image("karma-realm-bg").resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height + geometry.safeAreaInsets.top + geometry.safeAreaInsets.bottom)
                    .clipped().ignoresSafeArea()
                    .accessibilityHidden(true)
            }
        }
        .background(ShinobiStyle.background)
        .foregroundStyle(ShinobiStyle.text)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: staying && !voiceOverEnabled) {
            // Keep the response available until the user closes it with VoiceOver.
            guard staying, !voiceOverEnabled else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            guard !Task.isCancelled else { return }
            stayLocked()
        }
    }

    private var brand: some View {
        Text("忍びロック")
            .shinobiFont(12, relativeTo: .caption).tracking(1.7)
            .foregroundStyle(ShinobiStyle.subdued)
            .accessibilityLabel("忍びロック、カルマの間")
            .accessibilityAddTraits(.isHeader)
    }

    private func portrait(size: CGFloat) -> some View {
        Image(encounter.portrait.rawValue)
            .resizable().scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .accessibilityLabel(encounter.portrait.description)
    }

    private func dialogue(compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            Text("カルマ").shinobiFont(11, relativeTo: .caption).tracking(2.2)
                .foregroundStyle(ShinobiStyle.muted)
            Text(staying ? encounter.stayedLine : encounter.line)
                .shinobiFont(compact ? 19 : 21, weight: .medium, relativeTo: .title3)
                .lineSpacing(compact ? 7 : 8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: compact ? 60 : 68)
                .contentTransition(.opacity)
        }
        .accessibilityElement(children: .combine)
    }

    private func actions(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 18) {
            Button(staying ? (context == .unlock ? "ロックを続ける" : "ルールを残す") : "やめておく") {
                guard !continuing else { return }
                if staying {
                    stayLocked()
                } else {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { staying = true }
                    if voiceOverEnabled {
                        UIAccessibility.post(notification: .announcement, argument: encounter.stayedLine)
                    }
                }
            }
            .buttonStyle(ShinobiButtonStyle(height: compact ? 50 : 52))
            .disabled(continuing || (staying && !voiceOverEnabled))
            .accessibilityHint(context == .unlock
                                ? (staying ? "解除せずに閉じます" : "広告を見ずに、ロックを続けます")
                                : "ルールを変更せずに閉じます")

            Button {
                guard !staying, !continuing else { return }
                continuing = true
                continueToAd()
            } label: {
                Text(continueTitle)
                    .shinobiFont(14).multilineTextAlignment(.center)
                    .foregroundStyle(ShinobiStyle.subdued)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(staying || continuing)
            .opacity(staying ? 0 : 1)
            .accessibilityHidden(staying)
        }
    }

    private var continueTitle: String {
        switch context {
        case .unlock: return "それでも広告を見て5分間解除する"
        case .pauseRule: return "それでも広告を見て休止する"
        case .deleteRule: return "それでも広告を見て削除する"
        }
    }
}
