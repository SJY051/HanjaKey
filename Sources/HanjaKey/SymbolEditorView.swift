import SwiftUI

/// In-app editor for the user symbol overlay. Only jamo that already have a set are shown as chips;
/// a "+" button adds a new jamo from a compact grid of the unused ones. Picking a chip edits that
/// jamo's symbols (add / remove / reorder). Saves to symbols.json and reloads the converter live.
struct SymbolEditorView: View {
    @State private var sets: [String: [String]] = UserSymbols.load()
    @State private var selectedJamo: String?
    @State private var newSymbol = ""
    @State private var showingPicker = false

    // Canonical order: vowels (unused by the real Hanja key) first, then consonants (override).
    private static let order = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ",
        "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ",
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ",
        "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    private var activeJamo: [String] { Self.order.filter { (sets[$0]?.isEmpty == false) } }
    private var unusedJamo: [String] { Self.order.filter { (sets[$0]?.isEmpty != false) } }
    private var current: [String] { selectedJamo.flatMap { sets[$0] } ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            chipBar
            Divider()
            if let jamo = selectedJamo {
                editor(for: jamo)
            } else {
                Text("위에서 자모를 고르거나 +로 새 자모를 추가하세요.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .onAppear {
            sets = UserSymbols.load() // pick up edits made via the JSON file
            if selectedJamo == nil { selectedJamo = activeJamo.first }
        }
    }

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(activeJamo, id: \.self) { jamo in
                    Button { selectedJamo = jamo } label: {
                        Text(jamo).frame(minWidth: 22)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedJamo == jamo ? .accentColor : .secondary)
                }
                Button { showingPicker = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingPicker, arrowEdge: .bottom) { jamoPicker }
            }
            .padding(.vertical, 2)
        }
    }

    private var jamoPicker: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 7), spacing: 6) {
                ForEach(unusedJamo, id: \.self) { jamo in
                    Button(jamo) {
                        selectedJamo = jamo
                        showingPicker = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .frame(width: 340, height: 240)
    }

    private func editor(for jamo: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("‘\(jamo)’ 기호").font(.headline)
                Spacer()
                Text("\(current.count)개").font(.caption).foregroundStyle(.secondary)
            }
            List {
                ForEach(current, id: \.self) { symbol in
                    HStack {
                        Text(symbol).font(.title3)
                        Spacer()
                        Button { remove(symbol) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { source, destination in
                    var v = current
                    v.move(fromOffsets: source, toOffset: destination)
                    setCurrent(v)
                }
                if current.isEmpty {
                    Text("기호가 없습니다. 아래에서 추가하세요. (모두 비우면 칩에서 사라집니다.)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 180)
            HStack {
                TextField("기호 추가 (예: ★  →  ♥)", text: $newSymbol).onSubmit(add)
                Button("추가", action: add)
                    .disabled(newSymbol.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text("자동 저장되어 다음 팝업부터 적용됩니다. 행을 드래그하면 순서가 바뀝니다.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func add() {
        let symbol = newSymbol.trimmingCharacters(in: .whitespaces)
        newSymbol = ""
        guard !symbol.isEmpty, !current.contains(symbol) else { return }
        setCurrent(current + [symbol])
    }

    private func remove(_ symbol: String) {
        setCurrent(current.filter { $0 != symbol })
    }

    private func setCurrent(_ value: [String]) {
        guard let jamo = selectedJamo else { return }
        sets[jamo] = value.isEmpty ? nil : value
        UserSymbols.save(sets)
        CandidateView.reloadUserSymbols()
    }
}
