import SwiftUI
import HanjaKitCore

/// The popup UI: a search field for the Hangul reading + a grid of candidates.
struct CandidateView: View {
    /// Called when the user picks a candidate (click or ↩). Receives the chosen character.
    let onPick: (String) -> Void

    @State private var input = ""
    @State private var candidates: [Candidate] = []
    @FocusState private var fieldFocused: Bool

    // Loaded once: parsing the bundled tables is not free.
    private static let converter = try? Converter.bundled()

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("한글 입력 (예: 한, ㅁ)", text: $input)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($fieldFocused)
                .onSubmit { if let first = candidates.first { onPick(first.value) } }
                .onChange(of: input) { newValue in
                    candidates = Self.converter?.candidates(for: newValue) ?? []
                }

            if candidates.isEmpty {
                Text(input.isEmpty ? "한글 음절(한자) 또는 자모(특수문자)를 입력하세요" : "후보 없음")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(candidates, id: \.self) { candidate in
                            Button { onPick(candidate.value) } label: {
                                Text(candidate.value)
                                    .font(.title)
                                    .frame(width: 46, height: 46)
                            }
                            .buttonStyle(.bordered)
                            .help(candidate.gloss ?? "")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(14)
        .frame(minWidth: 380, minHeight: 320)
        .onAppear { fieldFocused = true }
    }
}
