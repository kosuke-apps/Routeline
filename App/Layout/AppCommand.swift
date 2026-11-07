import SwiftUI

/// What a hardware keyboard can do. One list feeds the two places a shortcut has to live: the "Go" menu (the shortcut list
/// that holding ⌘ brings up on an iPad) and invisible buttons in the view tree (`KeyboardShortcuts`), because a Mac that
/// runs the iPad app ("Designed for iPad") shows no custom menu at all.
enum AppCommand: CaseIterable {
  case map, info, plan, find, routes, locate, refresh, settings, close

  var title: LocalizedStringKey {
    switch self {
    case .map: "Map"
    case .info: "Service info"
    case .plan: "Plan a trip"
    case .find: "Find a stop"
    case .routes: "Routes"
    case .locate: "My location"
    case .refresh: "Refresh buses now"
    case .settings: "Settings"
    case .close: "Close"
    }
  }

  var key: KeyEquivalent {
    switch self {
    case .map: "1"
    case .info: "2"
    case .plan: "3"
    case .find: "f"
    case .routes, .refresh: "r"
    case .locate: "l"
    case .settings: ","
    case .close: .escape
    }
  }

  var modifiers: EventModifiers {
    switch self {
    case .refresh: [.command, .shift]
    case .close: []
    default: .command
    }
  }

  @MainActor func perform(_ model: AppModel) {
    switch self {
    case .map: model.switchMode(.map)
    case .info: model.switchMode(.info)
    case .plan: model.switchMode(.plan)
    case .find: model.open(.search)
    case .routes: model.open(.routes)
    case .locate: model.locateMe()
    case .refresh: model.refreshNow()
    case .settings: model.open(.settings)
    case .close: model.closeTop()
    }
  }
}

/// The commands as buttons nobody sees: SwiftUI turns a button's `keyboardShortcut` into a key command of the window, which
/// works wherever there is a hardware keyboard and does not depend on a menu.
struct KeyboardShortcuts: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ZStack {
      ForEach(AppCommand.allCases, id: \.self) { command in
        Button("") { command.perform(model) }.keyboardShortcut(command.key, modifiers: command.modifiers)
      }
    }
    .frame(width: 0, height: 0)
    .opacity(0)
    .accessibilityHidden(true)
  }
}
