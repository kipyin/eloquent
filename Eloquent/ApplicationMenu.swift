import AppKit

enum ApplicationMenu {
    // LSUIElement apps often have no Edit menu, so Cmd+V never sends paste: to the field editor.
    static func install() {
        let app = NSApplication.shared
        let mainMenu: NSMenu
        if let existing = app.mainMenu {
            mainMenu = existing
        } else {
            let created = NSMenu()
            created.addItem(makeAppMenuItem())
            app.mainMenu = created
            mainMenu = created
        }

        if containsEditMenu(mainMenu) {
            return
        }

        if mainMenu.items.isEmpty {
            mainMenu.addItem(makeAppMenuItem())
        }

        mainMenu.addItem(makeEditMenuItem())
    }

    private static func containsEditMenu(_ mainMenu: NSMenu) -> Bool {
        mainMenu.items.contains { item in
            item.title == "Edit" || item.submenu?.title == "Edit"
        }
    }

    private static func makeAppMenuItem() -> NSMenuItem {
        let appName = "Eloquent"
        let item = NSMenuItem()
        let menu = NSMenu()
        menu.addItem(
            withTitle: "About \(appName)",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Hide \(appName)",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(hideOthers)
        menu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.submenu = menu
        return item
    }

    private static func makeEditMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Edit")
        menu.addItem(menuItem("Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = menuItem("Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(redo)
        menu.addItem(.separator())
        menu.addItem(menuItem("Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(menuItem("Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(menuItem("Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(menuItem("Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        item.submenu = menu
        return item
    }

    private static func menuItem(_ title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    }
}
