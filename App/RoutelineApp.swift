import SwiftUI
import UserNotifications

@main
struct RoutelineApp: App {
  @State private var model: AppModel

  init() {
    let model = AppModel(settings: AppSettings())
    _model = State(initialValue: model)
    LanguageState.shared.apply(model.settings.values.language)
    UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    WatchBackground.register(model)
  }

  var body: some Scene {
    WindowGroup {
      LanguageRoot {
        RootView()
          .environment(model)
          .task { await model.start() }
      }
    }
    // The hardware keyboard: the shortcut list that holding ⌘ brings up on an iPad. The same commands are also buttons in the
    // view tree (`KeyboardShortcuts`), because a Mac that runs the iPad app shows no custom menu.
    .commands {
      // The system's own "Settings…" (⌘,) would open the iPad's Settings app, not the one in Routeline.
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { AppCommand.settings.perform(model) }.keyboardShortcut(",")
      }
      CommandMenu("Go") {
        item(.map); item(.info); item(.plan)
        Divider()
        item(.find); item(.routes); item(.locate); item(.refresh)
        Divider()
        item(.settings); item(.close)
      }
    }
  }

  private func item(_ command: AppCommand) -> some View {
    Button(command.title) { command.perform(model) }.keyboardShortcut(command.key, modifiers: command.modifiers)
  }
}
