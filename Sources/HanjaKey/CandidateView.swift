import SwiftUI
import AppKit
import HanjaKitCore

/// Windows Hanja-key–style candidate list: a vertical, numbered list of candidates with gloss,
/// paged 9 at a time and driven by the keyboard. Tab expands to the full set — either a wide
/// Windows-style 9-row grid (default) or a compact square grid, per the user's setting.
///
/// Keys — 1–9 pick · ↑↓ move · ←→ page (or column/cell when expanded) · Tab expand/collapse ·
/// ↵ pick · esc cancel.
struct CandidateView: View {
    let reading: String
    let isWord: Bool                 // spec 007: word/decompose (multi) vs single — decided by the segmenter
    let onPick: (String, Int) -> Void
    let onCancel: () -> Void
    let onResize: (CGSize) -> Void
    private let replaceLength: Int   // chars insertion replaces = active-token length (0 = live selection)

    private let candidates: [Candidate]
    @State private var selection = 0
    @State private var expanded = false
    @State private var decomposing = false
    @State private var columns: [[Candidate]] = []
    @State private var picks: [String?] = []
    @State private var activeColumn = 0
    @Namespace private var glyphNS  // ties a candidate's glyph across list ↔ grid for smooth motion
    @AppStorage(AppSettings.expandedWideKey) private var wideStyle = true
    @FocusState private var focused: Bool

    // The Hanja table is heavy so it's cached once; only the small user symbol overlay is re-read
    // on reload (after the user edits their symbols.json).
    private static let hanja = try? HanjaTable.bundled()
    private static let baseSymbols = try? SymbolTable.bundled()
    private static let tiers = TierTable.bundled()   // spec 005 M2: single-syllable display ordering
    private static var converter: Converter? = buildConverter()

    static func buildConverter() -> Converter? {
        guard let hanja, let baseSymbols else { return nil }
        return Converter(hanja: hanja, symbols: baseSymbols.merging(UserSymbols.load()), tiers: tiers)
    }

    /// Rebuild the converter after the user edits their symbol file (cheap — Hanja stays cached).
    static func reloadUserSymbols() { converter = buildConverter() }

    /// Lazy: the multi-syllable word dictionary is large (~235k); loaded only on first word use.
    private static let wordTable = try? WordTable.bundled()

    /// Lazy: the 국립국어원 2002 frequency table (spec 003) — ranks homophone words by real usage.
    /// nil if the resource is missing, in which case word ranking falls back to the 002 heuristic.
    private static let freqTable = try? FreqTable.bundled()

    private static let pageSize = 9
    private static let visibleCutoff = 20   // spec 005: collapsed single-syllable list cap; the grid shows all
    private static let glossLineFit = 16    // collapsed-footer gloss length that fits one line → no "more" chevron
    private static let gridColumns = 5
    private static let cellWidth: CGFloat = 32
    private static let cellHeight: CGFloat = 28

    init(reading rawReading: String, autoCaptured: Bool = false,
         onPick: @escaping (String, Int) -> Void, onCancel: @escaping () -> Void,
         onResize: @escaping (CGSize) -> Void = { _ in }) {
        self.onPick = onPick
        self.onCancel = onCancel
        self.onResize = onResize

        // spec 007: for an auto-captured run, segment to the active token at the caret — a trailing lone
        // jamo → symbol, the longest dictionary suffix → word, else a single syllable or per-syllable
        // decomposition. A user's explicit selection is respected as-is (route by length, replace it all).
        if autoCaptured {
            let seg = Segmenter.segment(rawReading, words: Self.wordTable ?? WordTable(readingToEntries: [:]))
            self.reading = seg.text
            self.replaceLength = seg.text.count
            switch seg {
            case .single(let s):
                self.isWord = false
                self.candidates = Self.converter?.candidates(for: s, halfwidthSymbols: AppSettings.halfwidthSymbols) ?? []
            case .word(let s):
                self.isWord = true
                self.candidates = Self.wordTable.flatMap { Self.converter?.candidates(forWord: s, using: $0, freq: Self.freqTable) } ?? []
            case .decompose:
                self.isWord = true
                self.candidates = []   // no dictionary word → wordMissState → 음절별로 만들기
            }
        } else {
            let word = rawReading.count >= 2
            self.reading = rawReading
            self.isWord = word
            self.replaceLength = 0      // a live user selection → ⌘V replaces it (insert selectBack 0)
            if word {
                self.candidates = Self.wordTable.flatMap { Self.converter?.candidates(forWord: rawReading, using: $0, freq: Self.freqTable) } ?? []
            } else {
                self.candidates = Self.converter?.candidates(for: rawReading, halfwidthSymbols: AppSettings.halfwidthSymbols) ?? []
            }
        }
    }

    // Paging math, derived from the current selection.
    // spec 005: the collapsed single-syllable list shows only the curated head; Tab (the grid) reveals
    // the full set. Words and the expanded grid stay uncapped.
    private var visibleCount: Int {
        (expanded || isWord) ? candidates.count : min(Self.visibleCutoff, candidates.count)
    }
    private var pageCount: Int { max(1, (visibleCount + Self.pageSize - 1) / Self.pageSize) }
    private var currentPage: Int { selection / Self.pageSize }
    private var pageStart: Int { currentPage * Self.pageSize }
    private var pageEnd: Int { min(pageStart + Self.pageSize, visibleCount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if candidates.isEmpty {
                if decomposing {
                    decompositionView
                } else if isWord {
                    wordMissState
                } else {
                    emptyState
                }
            } else {
                Group {
                    if expanded {
                        // The wide 9-row grid assumes single-glyph cells; words use the flexible square grid.
                        if wideStyle && !isWord { wideGrid } else { squareGrid }
                    } else {
                        rows
                    }
                }
                .transition(.opacity) // glyphs ride matchedGeometry; the rest of each mode fades in/out
                Divider()
                footer
            }
        }
        .frame(width: panelWidth)
        .modifier(PanelSurface())
        .focusable()
        .focused($focused)
        .focusEffectDisabled() // suppress the blue keyboard focus ring around the panel
        .onAppear { focused = true }
        .onKeyPress(action: handleKey)
        .background(
            GeometryReader { proxy in
                // Report content-size changes (e.g. entering the decomposition view) so the panel
                // can resize + reposition — the NSPanel doesn't auto-follow SwiftUI's size.
                Color.clear.onChange(of: proxy.size) { _, newSize in onResize(newSize) }
            }
        )
    }

    private var panelWidth: CGFloat {
        if decomposing { return min(680, CGFloat(max(2, columns.count)) * 158 + 40) }
        guard expanded else { return 300 }
        return wideStyle ? 460 : 360
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack(spacing: 6) {
            Text(reading.isEmpty ? "—" : reading)
                .font(.headline)
            Text("한자 / 특수문자")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Group {
                if expanded {
                    Text("전체 \(candidates.count)")
                } else if candidates.count > visibleCount {
                    Text("\(currentPage + 1)/\(pageCount) · 전체 \(candidates.count)")
                } else if candidates.count > Self.pageSize {
                    Text("\(currentPage + 1)/\(pageCount)")
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .id(expanded)            // page-count vs total are different roles → cross-fade only on toggle
            .transition(.opacity)
            Menu {
                Button("설정…") { NotificationCenter.default.post(name: .hkOpenSettings, object: nil) }
                Button("HanjaKey 종료") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !candidates.isEmpty, let sel = candidates[safe: selection] {
                let gloss = sel.gloss ?? ""
                if expanded {
                    // Full definition in a FIXED-height scroll area, so navigating candidates never
                    // resizes the window (scroll/trackpad for the rest of a long gloss).
                    if !gloss.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Text(sel.value).font(.headline)
                            ScrollView {
                                Text(gloss)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .matchedGeometryEffect(id: "footerGloss", in: glyphNS)
                            }
                            .frame(height: 52)
                        }
                    }
                } else if !gloss.isEmpty {
                    // List: one faded line. The disclosure (chevron) that expands to the full text shows
                    // only when the gloss is long enough to be truncated — a short 훈음 (single Hanja) fits
                    // on one line, so there is nothing more to reveal (spec 005 follow-up / BACKLOG #16).
                    let truncated = gloss.count > Self.glossLineFit
                    HStack(spacing: 6) {
                        Text(gloss)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .matchedGeometryEffect(id: "footerGloss", in: glyphNS)
                            .mask {
                                if truncated {
                                    LinearGradient(
                                        stops: [.init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                                        startPoint: .leading, endPoint: .trailing)
                                } else {
                                    Color.black
                                }
                            }
                        if truncated {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) { expanded = true }
                            } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.plain)
                                .font(.caption2)
                                .foregroundStyle(.tint)
                                .help("전체 뜻 보기")
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(height: 15)
                } else if sel.kind != .symbol {
                    // Keep glossless hanja steady; symbols have no gloss → no placeholder.
                    Color.clear.frame(height: 15)
                }
            }
            Text(expanded
                 ? (wideStyle ? "1–9 · ↑↓←→ · Tab 접기" : "↑↓←→ · Tab 접기")
                 : "1–9 선택 · ↑↓ 이동 · ←→ 페이지 · Tab 전체 · ↵ 입력 · esc 취소")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .id(expanded)
                .transition(.opacity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.18), value: expanded)
    }

    private var emptyState: some View {
        Text(reading.isEmpty ? "변환할 한글이 없습니다" : "‘\(reading)’ 후보가 없습니다")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
    }

    // MARK: - Per-syllable fallback (dictionary miss for a multi-syllable word)

    private var wordMissState: some View {
        VStack(spacing: 12) {
            Text("‘\(reading)’ 단어를 사전에서 찾지 못했어요")
                .font(.callout).foregroundStyle(.secondary)
            Button("음절별로 만들기") {
                columns = Self.converter?.decomposition(of: reading) ?? []
                picks = columns.map { $0.first?.value }
                activeColumn = 0
                decomposing = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
    }

    private var decompositionView: some View {
        let chars = Array(reading)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(previewText).font(.title3)
                Spacer()
                Button("입력", action: confirmDecomposition).disabled(!allPicked)
            }
            .padding(.horizontal, 12).padding(.top, 10)
            Divider()
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(columns.indices, id: \.self) { ci in
                        VStack(spacing: 4) {
                            Text(ci < chars.count ? String(chars[ci]) : "")
                                .font(.caption.weight(ci == activeColumn ? .bold : .regular))
                                .foregroundStyle(ci == activeColumn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(spacing: 2) {
                                        ForEach(columns[ci], id: \.self) { candidate in
                                            Button { setPick(ci, candidate.value) } label: {
                                                HStack(spacing: 6) {
                                                    Text(candidate.value).font(.title3)
                                                    if let gloss = candidate.gloss, !gloss.isEmpty {
                                                        Text(gloss)
                                                            .font(.caption2).foregroundStyle(.secondary)
                                                            .lineLimit(1).truncationMode(.tail)
                                                    }
                                                    Spacer(minLength: 0)
                                                }
                                                .padding(.horizontal, 6).padding(.vertical, 3)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(
                                                    (ci < picks.count ? picks[ci] : nil) == candidate.value
                                                        ? AnyShapeStyle(.tint.opacity(0.20)) : AnyShapeStyle(.clear),
                                                    in: RoundedRectangle(cornerRadius: 5)
                                                )
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            .id(candidate.value)
                                        }
                                    }
                                }
                                .frame(height: 220)
                                .onChange(of: ci < picks.count ? picks[ci] : nil) { _, newValue in
                                    if let value = newValue {
                                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(value, anchor: .center) }
                                    }
                                }
                            }
                        }
                        .frame(width: 150)
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 6)
            }
            Text("←→ 음절 · ↑↓ 또는 1–9 한자 선택 · ↵ 입력 · esc 뒤로")
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.bottom, 8)
        }
    }

    private var previewText: String { picks.map { $0 ?? "·" }.joined() }
    private var allPicked: Bool { !picks.isEmpty && picks.allSatisfy { $0 != nil } }

    private func setPick(_ column: Int, _ value: String) {
        guard picks.indices.contains(column) else { return }
        picks[column] = value
        activeColumn = column
    }

    private func movePick(_ column: Int, _ delta: Int) {
        guard columns.indices.contains(column) else { return }
        let items = columns[column]
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.value == picks[column] } ?? 0
        picks[column] = items[min(max(current + delta, 0), items.count - 1)].value
    }

    private func pickInColumn(_ column: Int, _ index: Int) {
        guard columns.indices.contains(column), columns[column].indices.contains(index) else { return }
        picks[column] = columns[column][index].value
    }

    private func confirmDecomposition() {
        guard allPicked else { return }
        onPick(picks.compactMap { $0 }.joined(), replaceLength)
    }

    // MARK: - Paged list (collapsed)

    private var rows: some View {
        VStack(spacing: 1) {
            ForEach(pageStart..<pageEnd, id: \.self) { index in
                row(index: index)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private func row(index: Int) -> some View {
        let candidate = candidates[index]
        let number = index - pageStart + 1
        return HStack(spacing: 10) {
            Text("\(number)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
                .matchedGeometryEffect(id: "num-\(number)", in: glyphNS)
            Text(candidate.value)
                .font(.title2)
                .matchedGeometryEffect(id: index, in: glyphNS)
            if let gloss = candidate.gloss, !gloss.isEmpty {
                Text(gloss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight(index == selection), in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { onPick(candidate.value, replaceLength) }
    }

    // MARK: - Wide grid (Windows-style: 9 rows, columns scroll horizontally)

    private var wideGrid: some View {
        let rows = Self.pageSize
        let colCount = (candidates.count + rows - 1) / rows
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 1) { // 1–9 row gutter
                        ForEach(1...rows, id: \.self) { n in
                            Text("\(n)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 14, height: Self.cellHeight)
                                .matchedGeometryEffect(id: "num-\(n)", in: glyphNS)
                        }
                    }
                    ForEach(0..<colCount, id: \.self) { column in
                        VStack(spacing: 1) {
                            ForEach(0..<rows, id: \.self) { r in
                                let index = column * rows + r
                                if index < candidates.count {
                                    cell(index).id(index)
                                } else {
                                    Color.clear.frame(width: Self.cellWidth, height: Self.cellHeight)
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: Self.cellHeight * CGFloat(rows) + 20)
            .onChange(of: selection) { oldValue, newValue in
                // Horizontal grid: scroll ONLY when the column changes. ↑↓ moves within a column (±1) and
                // must not scroll; ←→ / column-boundary crossings reveal the new column (minimally, nil).
                guard oldValue / rows != newValue / rows else { return }
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo(newValue, anchor: nil) }
            }
            .onAppear { proxy.scrollTo(selection, anchor: nil) }
        }
    }

    // MARK: - Square grid (compact)

    private var squareGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: Self.gridColumns),
                    spacing: 4
                ) {
                    ForEach(candidates.indices, id: \.self) { index in
                        cell(index, fill: true).id(index)
                            // Words newly revealed on expand rise in (opacity + slight scale) so the
                            // entrance reads clearly instead of a too-fast fade.
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 320)
            .onChange(of: selection) { oldValue, newValue in
                // Vertical grid: scroll ONLY when the row changes. ←→ moves within a row (±1) and must
                // not scroll; ↑↓ / row-boundary crossings reveal the new row (minimally, nil).
                guard oldValue / Self.gridColumns != newValue / Self.gridColumns else { return }
                withAnimation(.smooth(duration: 0.25)) { proxy.scrollTo(newValue, anchor: nil) }
            }
            .onAppear { proxy.scrollTo(selection, anchor: nil) }
        }
    }

    private func cell(_ index: Int, fill: Bool = false) -> some View {
        Text(candidates[index].value)
            .font(.title3)
            .matchedGeometryEffect(id: index, in: glyphNS)
            .frame(
                width: fill ? nil : Self.cellWidth,
                height: fill ? 34 : Self.cellHeight
            )
            .frame(maxWidth: fill ? .infinity : nil)
            .background(highlight(index == selection), in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .topLeading) {
                // Square grid (words): show the 1–9 index like the list/wide grid do, carried over by
                // matchedGeometry so it eases in from the collapsed list rather than popping.
                if fill, (pageStart..<pageEnd).contains(index) {
                    Text("\(index - pageStart + 1)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .matchedGeometryEffect(id: "num-\(index - pageStart + 1)", in: glyphNS)
                        .padding(3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onPick(candidates[index].value, replaceLength) }
    }

    private func highlight(_ on: Bool) -> AnyShapeStyle {
        on ? AnyShapeStyle(.tint.opacity(0.20)) : AnyShapeStyle(.clear)
    }

    // MARK: - Keyboard handling

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if decomposing {
            switch press.key {
            case .escape: decomposing = false; return .handled // back to the miss screen
            case .return: confirmDecomposition(); return .handled
            case .leftArrow: activeColumn = max(0, activeColumn - 1); return .handled
            case .rightArrow: activeColumn = min(max(columns.count - 1, 0), activeColumn + 1); return .handled
            case .upArrow: movePick(activeColumn, -1); return .handled
            case .downArrow: movePick(activeColumn, 1); return .handled
            default: break
            }
            if let n = Int(press.characters), (1...9).contains(n) {
                pickInColumn(activeColumn, n - 1); return .handled
            }
            return .ignored
        }
        switch press.key {
        case .escape:
            onCancel(); return .handled
        case .return:
            pick(selection); return .handled
        case .tab:
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            if !expanded { selection = min(selection, visibleCount - 1) } // collapsing → keep selection in the head
            return .handled
        case .upArrow:
            move(verticalStep(-1)); return .handled
        case .downArrow:
            move(verticalStep(1)); return .handled
        case .leftArrow:
            horizontal(-1); return .handled
        case .rightArrow:
            horizontal(1); return .handled
        case .pageUp:
            move(-Self.pageSize); return .handled
        case .pageDown:
            move(Self.pageSize); return .handled
        default:
            break
        }
        // Number keys 1–9 pick within the current page/column (list & wide modes).
        if numberPickEnabled, let n = Int(press.characters), (1...9).contains(n) {
            pick(pageStart + n - 1); return .handled
        }
        if press.characters == "[" { horizontal(-1); return .handled }
        if press.characters == "]" { horizontal(1); return .handled }
        return .ignored
    }

    /// The wide 9-row grid renders only for single-glyph candidates; words always use the square grid
    /// even when the wide-style setting is on (see body line 93). Navigation must follow what is
    /// actually rendered, not just the setting — otherwise word grids get the wide step (arrows feel
    /// transposed).
    private var isWideGrid: Bool { expanded && wideStyle && !isWord }

    private var numberPickEnabled: Bool { !expanded || wideStyle }

    /// Up/down step: ±1 in the list and the wide grid; one row (±columns) in any square grid (incl. words).
    private func verticalStep(_ direction: Int) -> Int {
        (expanded && !isWideGrid) ? direction * Self.gridColumns : direction
    }

    /// Left/right: page in the list, adjacent column in the wide grid, ±1 in any square grid (incl. words).
    private func horizontal(_ direction: Int) {
        if !expanded {
            page(direction)
        } else if isWideGrid {
            move(direction * Self.pageSize)
        } else {
            move(direction)
        }
    }

    private func move(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        selection = min(max(selection + delta, 0), visibleCount - 1)
    }

    private func page(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        let target = min(max(currentPage + delta, 0), pageCount - 1)
        selection = target * Self.pageSize // land on the first item of the new page
    }

    private func pick(_ index: Int) {
        guard candidates.indices.contains(index) else { return }
        onPick(candidates[index].value, replaceLength)
    }
}

/// The popup's rounded surface: Liquid Glass on macOS 26+, a material fallback below.
private struct PanelSurface: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial)
                .clipShape(shape)
                .overlay(shape.strokeBorder(.separator))
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
