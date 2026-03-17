import Cocoa
import FinderSync

class FinderSync: FIFinderSync {

    override init() {
        super.init()
        // Watch all mounted volumes so the menu item appears everywhere.
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
        FIFinderSyncController.default().directoryURLs = Set(volumes)
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Only show on the directory background (right-click in empty space).
        guard menuKind == .contextualMenuForContainer else { return nil }

        // Check if files are on the pasteboard (i.e., user did Cmd+C on files).
        let pb = NSPasteboard.general
        guard let types = pb.types,
              types.contains(.fileURL),
              let urls = pb.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
              ]) as? [URL],
              !urls.isEmpty
        else {
            return nil
        }

        let menu = NSMenu(title: "")
        let item = NSMenuItem(
            title: "Move \(urls.count == 1 ? "Item" : "\(urls.count) Items") Here (Paste)",
            action: #selector(moveItemsHere(_:)),
            keyEquivalent: ""
        )
        item.image = NSImage(systemSymbolName: "arrow.right.doc.on.clipboard",
                             accessibilityDescription: "Move")
        menu.addItem(item)
        return menu
    }

    @objc func moveItemsHere(_ sender: AnyObject?) {
        // Destination = the folder the user right-clicked in.
        guard let target = FIFinderSyncController.default().targetedURL() else { return }

        let pb = NSPasteboard.general
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else { return }

        let fm = FileManager.default
        var movedCount = 0
        var errors: [String] = []

        for sourceURL in urls {
            let destURL = target.appendingPathComponent(sourceURL.lastPathComponent)

            // If destination already exists, ask what to do.
            if fm.fileExists(atPath: destURL.path) {
                let alert = NSAlert()
                alert.messageText = "An item named \"\(sourceURL.lastPathComponent)\" already exists."
                alert.informativeText = "Do you want to replace it?"
                alert.addButton(withTitle: "Replace")
                alert.addButton(withTitle: "Skip")
                alert.alertStyle = .warning

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    do {
                        try fm.removeItem(at: destURL)
                    } catch {
                        errors.append("Couldn't remove existing \(sourceURL.lastPathComponent): \(error.localizedDescription)")
                        continue
                    }
                } else {
                    continue
                }
            }

            do {
                try fm.moveItem(at: sourceURL, to: destURL)
                movedCount += 1
            } catch {
                errors.append("Failed to move \(sourceURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Clear the pasteboard after moving so "Move Item Here" disappears.
        if movedCount > 0 {
            pb.clearContents()
        }

        // Show errors if any.
        if !errors.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Some items couldn't be moved"
            alert.informativeText = errors.joined(separator: "\n")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
