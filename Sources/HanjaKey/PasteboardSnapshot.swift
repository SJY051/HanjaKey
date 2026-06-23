import AppKit

/// A best-effort snapshot of the general pasteboard's full contents — every item and every readable
/// type, not just `.string`. HanjaKey drives the clipboard (⌘C/⌘V) to convert text in place; this lets
/// it restore exactly what the user had (images, files, RTF, multiple items) instead of wiping it.
///
/// Restoration is tagged transient — like the rest of HanjaKey's internal writes — so clipboard managers
/// (Maccy etc.) skip it. For a *deferred* restore, callers gate it with `ClipboardRestore.shouldRestore`
/// so a copy the user made in the meantime is never clobbered.
struct PasteboardSnapshot {
    /// One entry per `NSPasteboardItem`, mapping each captured type to its data. Order preserved.
    private let items: [[NSPasteboard.PasteboardType: Data]]
    /// True if some type vended no data (lazy/promised) and couldn't be captured — restore is partial.
    let isPartial: Bool

    /// Copy the current contents out of `pb` immediately (data, not live item references).
    static func capture(_ pb: NSPasteboard = .general) -> PasteboardSnapshot {
        var captured: [[NSPasteboard.PasteboardType: Data]] = []
        var partial = false
        for item in pb.pasteboardItems ?? [] {
            var typed: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typed[type] = data
                } else {
                    partial = true   // a lazy/promised type we can't snapshot
                }
            }
            if !typed.isEmpty { captured.append(typed) }
        }
        return PasteboardSnapshot(items: captured, isPartial: partial)
    }

    /// Re-write the captured contents, tagged transient so clipboard managers skip the restore. If the
    /// original was empty, leaves the (cleared) pasteboard empty rather than inventing content.
    func restore(to pb: NSPasteboard = .general) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        let objects: [NSPasteboardItem] = items.enumerated().map { index, typed in
            let item = NSPasteboardItem()
            for (type, data) in typed { item.setData(data, forType: type) }
            if index == 0 { item.setData(Data(), forType: Output.transientType) } // clipboard-manager hygiene
            return item
        }
        pb.writeObjects(objects)
    }
}

/// The (pure) decision for a deferred clipboard restore: restore only when HanjaKey still owns the
/// pasteboard — i.e. nothing wrote to it since HanjaKey's last write. Otherwise the user copied something
/// new in the meantime and we must leave it alone.
enum ClipboardRestore {
    static func shouldRestore(expectedChangeCount: Int, currentChangeCount: Int) -> Bool {
        expectedChangeCount == currentChangeCount
    }
}
