import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that summons the candidate popup. Defaults to ⌥⌘H (H = Hanja); a Settings
    /// recorder UI to rebind it is future work (the user can override via KeyboardShortcuts later).
    static let summon = Self("summon", default: .init(.h, modifiers: [.command, .option]))
}
