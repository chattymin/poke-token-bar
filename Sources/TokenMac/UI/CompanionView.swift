import SwiftUI

func rarityColor(_ r: Rarity?) -> Color {
    switch r {
    case .uncommon: return .green
    case .rare: return .blue
    case .legendary: return .orange
    default: return .gray
    }
}

/// 스프라이트 1개(런타임 로드 + 캐시). 없으면 알 글리프. bob 으로 가벼운 상하 움직임.
struct SpriteView: View {
    let speciesID: Int?
    var size: CGFloat = 84
    var bob: Bool = false
    @State private var img: NSImage?
    @State private var up = false

    init(speciesID: Int?, size: CGFloat = 84, bob: Bool = false) {
        self.speciesID = speciesID
        self.size = size
        self.bob = bob
        // 캐시에 있으면 즉시(동기) 표시 — 재렌더 플래시 방지 + 정적 스냅샷에서도 보임
        _img = State(initialValue: speciesID.flatMap { SpriteLoader.cachedImage(speciesID: $0) })
    }

    var body: some View {
        Group {
            if let img {
                Image(nsImage: img).resizable().interpolation(.none)
                    .frame(width: size, height: size)
            } else {
                Text("🥚").font(.system(size: size * 0.62)).frame(width: size, height: size)
            }
        }
        .offset(y: bob && up ? -3 : 0)
        .task(id: speciesID) {
            guard let id = speciesID else { img = nil; return }
            img = await SpriteLoader.image(speciesID: id, animated: false)
        }
        .onAppear {
            guard bob else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { up = true }
        }
    }
}

/// 진화 라인(초기→최종, 다음 후보 미리보기). done/cur/future.
struct EvoLineView: View {
    let nodes: [(id: Int, kind: String)]
    var thumb: CGFloat = 40
    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { i, node in
                if i > 0 { Image(systemName: "arrow.right").font(.system(size: 8)).foregroundStyle(.tertiary) }
                SpriteView(speciesID: node.id, size: thumb)
                    .opacity(node.kind == "future" ? 0.32 : 1)
                    .saturation(node.kind == "future" ? 0.4 : 1)
                    .overlay(alignment: .bottom) {
                        if node.kind == "cur" {
                            Circle().fill(Color.accentColor).frame(width: 4, height: 4).offset(y: 2)
                        }
                    }
            }
        }
    }
}

/// 팝오버 상단 — 현재 포켓몬 + 진화 진행.
struct CompanionHeader: View {
    let store: CompanionStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                SpriteView(speciesID: store.currentSpeciesID, size: 76, bob: true)
                    .frame(width: 76, height: 76)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(store.displayName).font(.callout.weight(.semibold))
                        if let r = store.rarity {
                            Text(r.rawValue.uppercased()).font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(rarityColor(r)).foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    if store.hasActive {
                        Text(store.stageText).font(.caption2).foregroundStyle(.secondary)
                        ProgressView(value: store.progress).controlSize(.small).tint(.orange)
                        if store.tokensToNext > 0 {
                            let amount = TokenFormatter.compact(store.tokensToNext)
                            Text(store.isFinalStage ? store.l.toGraduation(amount) : store.l.toNextEvolution(amount))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                    } else {
                        Text(store.l.waitingFirstToken).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(statusLine).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if store.hasActive, !store.lineNodes.isEmpty {
                EvoLineView(nodes: store.lineNodes)
            }
            if let g = store.justGraduated {
                Text(store.l.graduated(g))
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private var statusLine: String {
        let l = store.l
        switch store.displayState {
        case .egg:     return l.statusEgg
        case .idle:    return l.statusIdle
        case .working: return l.statusWorking
        case .focus:   return l.statusFocus
        case .tired:   return l.statusTired
        case .sleep:   return l.statusSleep
        case .levelUp: return store.justEvolvedTo.map { l.statusEvolved($0) } ?? l.statusGrew
        }
    }
}

/// 희귀도 1종 요약 캡슐 — 색 점 + 라벨 + 개수. 0이면 흐리게.
struct RarityTally: View {
    let label: String
    let count: Int
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9, weight: .medium))
            Text("\(count)").font(.system(size: 9, weight: .bold))
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .opacity(count == 0 ? 0.4 : 1)
    }
}

/// 도감 요약 헤더 — 총 개수 + 희귀도별 개수 캡슐.
struct DexSummaryHeader: View {
    let store: CompanionStore
    private let order: [Rarity] = [.legendary, .rare, .uncommon, .common]
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(store.l.dexTitle).font(.callout.weight(.semibold))
                Text(store.l.dexTotal(store.dexEntries.count))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { r in
                    RarityTally(label: store.l.rarityLabel(r), count: store.dexCount(r), color: rarityColor(r))
                }
            }
        }
    }
}

/// 도감 — 잡은 라인(초기→최종 전부) 목록.
struct CollectionView: View {
    let store: CompanionStore
    var body: some View {
        ScrollView {
            if store.dexEntries.isEmpty {
                Text(store.l.dexEmpty)
                    .font(.caption).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    DexSummaryHeader(store: store)
                    ForEach(store.dexEntriesSorted) { entry in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(entry.rarity.rawValue.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(rarityColor(entry.rarity)).foregroundStyle(.white)
                                    .clipShape(Capsule())
                                Spacer()
                                Text(store.l.formsComplete(entry.chainOrder.count)).font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            EvoLineView(nodes: entry.chainOrder.map { ($0, "done") }, thumb: 38)
                            if let caughtAt = entry.caughtAt {
                                Text(caughtAt, style: .relative).font(.system(size: 9)).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .frame(maxHeight: 260)
    }
}
