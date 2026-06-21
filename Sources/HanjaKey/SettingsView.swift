import SwiftUI
import AppKit
import KeyboardShortcuts

/// Preferences window: a "General" tab for toggles and a "User sets" tab for editing the custom
/// jamo → symbol overlay in-app. Settings live in `AppSettings`/`UserSymbols`.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("일반", systemImage: "gearshape") }
            SymbolEditorView()
                .tabItem { Label("사용자 세트", systemImage: "character.textbox") }
        }
        .frame(width: 480, height: 460)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(AppSettings.expandedWideKey) private var expandedWide = true
    @AppStorage(AppSettings.halfwidthSymbolsKey) private var halfwidthSymbols = false
    @AppStorage(AppSettings.showMenuBarIconKey) private var showMenuBarIcon = true

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            Section("단축키") {
                KeyboardShortcuts.Recorder("팝업 호출", name: .summon)
                Text("어디서든 이 단축키로 변환 팝업을 띄웁니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("일반") {
                Toggle("메뉴바 아이콘 표시", isOn: $showMenuBarIcon)
                    .onChange(of: showMenuBarIcon) { _, _ in
                        NotificationCenter.default.post(name: .hkMenuBarVisibilityChanged, object: nil)
                    }
                Text("끄면 단축키(⌥⌘H)와 팝업의 ⋯ 메뉴로 접근합니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("팝업") {
                Toggle("Tab 확장 시 와이드 그리드", isOn: $expandedWide)
                Text("끄면 컴팩트한 정사각 그리드로 펼쳐집니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("특수문자") {
                Toggle("특수문자를 반각으로 입력", isOn: $halfwidthSymbols)
                Text("문장부호·숫자·영문(ㄱ/ㅈ/ㅍ 등)을 전각(！０Ａ) 대신 반각(!0A)으로 넣습니다. ※ ☆ 같은 기호는 그대로입니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("사용자 세트 파일") {
                HStack {
                    Button("심볼 파일 열기") { NSWorkspace.shared.open(UserSymbols.fileURL) }
                    Button("다시 불러오기") { CandidateView.reloadUserSymbols() }
                }
                Text("‘사용자 세트’ 탭에서 직접 편집하거나, JSON 파일을 열어 수정할 수 있습니다.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("정보") {
                LabeledContent("HanjaKey", value: Self.appVersion)
                Link("GitHub 저장소", destination: URL(string: "https://github.com/SJY051/HanjaKey")!)
                Text("데이터 출처 — libhangul(BSD), 국립국어원 표준국어대사전·한국어 위키낱말사전(CC BY-SA), 국립국어원 2002 빈도조사(KOGL 제1유형), NeoMindStd/HanjaDB(MIT). 단일 한자 정렬·훈음은 자체 생성(MIT).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
