import SwiftUI

/// 팝오버용 캐릭터 애니메이션 뷰 — 상태에 따라 코드 드로잉된 NSImage 를 ~12fps 로 갱신.
struct CompanionView: View {
    let store: CompanionStore
    var size: CGFloat = 88

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12.0)) { context in
            Image(nsImage: CompanionRenderer.image(
                size: size,
                state: store.displayState,
                level: store.level,
                time: context.date.timeIntervalSinceReferenceDate))
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }
}

/// 팝오버 상단 캐릭터 섹션 — 스프라이트 + 이름/레벨 + XP 바 + 오늘 XP + 다음 레벨까지.
struct CompanionHeader: View {
    let store: CompanionStore

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CompanionView(store: store, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(store.name).font(.callout.weight(.semibold))
                    Text(store.isMaxed ? "Lv. \(store.level) · MAX" : "Lv. \(store.level)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: store.levelProgress)
                    .controlSize(.small)
                    .tint(.orange)
                HStack(spacing: 8) {
                    if store.todayXP > 0 {
                        Text("오늘 +\(store.todayXP) XP").font(.caption2).foregroundStyle(.secondary)
                    }
                    if !store.isMaxed, store.tokensToNextLevel > 0 {
                        Text("다음 레벨까지 \(TokenFormatter.compact(store.tokensToNextLevel))")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Text(statusLine).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusLine: String {
        switch store.displayState {
        case .egg:    return "곧 깨어나요."
        case .idle:   return "오늘은 조용히 자리를 지켜요."
        case .working: return "오늘의 작업 흔적이 쌓이고 있어요."
        case .focus:  return "지금은 집중 모드예요."
        case .tired:  return "한도에 가까워요. 잠깐 쉬어도 괜찮아요."
        case .sleep:  return "지금은 자고 있어요."
        case .levelUp: return "\(store.name)가 한 단계 자랐어요!"
        }
    }
}
