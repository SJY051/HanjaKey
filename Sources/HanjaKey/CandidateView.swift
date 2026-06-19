import SwiftUI
import HanjaKitCore

/// Windows Hanja-key–style candidate list: a vertical, numbered list of candidates with gloss,
/// paged 9 at a time and driven by the keyboard. Tab expands to the full set — either a wide
/// Windows-style 9-row grid (default) or a compact square grid, per the user's setting.
///
/// Keys — 1–9 pick · ↑↓ move · ←→ page (or column/cell when expanded) · Tab expand/collapse ·
/// ↵ pick · esc cancel.
struct CandidateView: View {
    let reading: String
    let onPick: (String) -> Void
    let onCancel: () -> Void

    private let candidates: [Candidate]
    @State private var selection = 0
    @State private var expanded = false
    @AppStorage(AppSettings.expandedWideKey) private var wideStyle = true
    @FocusState private var focused: Bool

    // Loaded once: parsing the bundled tables is not free.
    private static let converter = try? Converter.bundled()
    private static let pageSize = 9
    private static let gridColumns = 5
    private static let cellWidth: CGFloat = 32
    private static let cellHeight: CGFloat = 28

    init(reading: String, onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.reading = reading
        self.onPick = onPick
        self.onCancel = onCancel
        self.candidates = Self.converter?.candidates(for: reading) ?? []
    }

    // Paging math, derived from the current selection.
    private var pageCount: Int { max(1, (candidates.count + Self.pageSize - 1) / Self.pageSize) }
    private var currentPage: Int { selection / Self.pageSize }
    private var pageStart: Int { currentPage * Self.pageSize }
    private var pageEnd: Int { min(pageStart + Self.pageSize, candidates.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if candidates.isEmpty {
                emptyState
            } else {
                if expanded {
                    if wideStyle { wideGrid } else { squareGrid }
                } else {
                    rows
                }
                Divider()
                footer
            }
        }
        .frame(width: panelWidth)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator)
        )
        .focusable()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(action: handleKey)
    }

    private var panelWidth: CGFloat {
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
            if expanded {
                Text("전체 \(candidates.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else if candidates.count > Self.pageSize {
                Text("\(currentPage + 1)/\(pageCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var footer: some View {
        Group {
            if expanded {
                HStack(spacing: 8) {
                    Text(candidates[safe: selection]?.value ?? "")
                        .font(.headline)
                    if let gloss = candidates[safe: selection]?.gloss, !gloss.isEmpty {
                        Text(gloss).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    }
                    Spacer(minLength: 0)
                    Text(wideStyle ? "1–9 · ↑↓←→ · Tab 접기" : "↑↓←→ · Tab 접기")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            } else {
                Text("1–9 선택 · ↑↓ 이동 · ←→ 페이지 · Tab 전체 · ↵ 입력 · esc 취소")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        Text(reading.isEmpty ? "변환할 한글이 없습니다" : "‘\(reading)’ 후보가 없습니다")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
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
            Text(candidate.value)
                .font(.title2)
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
        .onTapGesture { onPick(candidate.value) }
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
            .onChange(of: selection) { _, newValue in
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(newValue, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
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
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 320)
            .onChange(of: selection) { _, newValue in
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(newValue, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }

    private func cell(_ index: Int, fill: Bool = false) -> some View {
        Text(candidates[index].value)
            .font(.title3)
            .frame(
                width: fill ? nil : Self.cellWidth,
                height: fill ? 34 : Self.cellHeight
            )
            .frame(maxWidth: fill ? .infinity : nil)
            .background(highlight(index == selection), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture { onPick(candidates[index].value) }
    }

    private func highlight(_ on: Bool) -> AnyShapeStyle {
        on ? AnyShapeStyle(.tint.opacity(0.20)) : AnyShapeStyle(.clear)
    }

    // MARK: - Keyboard handling

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .escape:
            onCancel(); return .handled
        case .return:
            pick(selection); return .handled
        case .tab:
            expanded.toggle(); return .handled
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

    private var numberPickEnabled: Bool { !expanded || wideStyle }

    /// Up/down step: ±1 in the list and the wide grid; one row (±columns) in the square grid.
    private func verticalStep(_ direction: Int) -> Int {
        (expanded && !wideStyle) ? direction * Self.gridColumns : direction
    }

    /// Left/right: page in the list, adjacent column in the wide grid, ±1 in the square grid.
    private func horizontal(_ direction: Int) {
        if !expanded {
            page(direction)
        } else if wideStyle {
            move(direction * Self.pageSize)
        } else {
            move(direction)
        }
    }

    private func move(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        selection = min(max(selection + delta, 0), candidates.count - 1)
    }

    private func page(_ delta: Int) {
        guard !candidates.isEmpty else { return }
        let target = min(max(currentPage + delta, 0), pageCount - 1)
        selection = target * Self.pageSize // land on the first item of the new page
    }

    private func pick(_ index: Int) {
        guard candidates.indices.contains(index) else { return }
        onPick(candidates[index].value)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
