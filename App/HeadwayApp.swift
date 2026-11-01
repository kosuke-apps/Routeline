import SwiftUI
import UserNotifications

@main
struct HeadwayApp: App {
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
    // The hardware keyboard: shown in the shortcut list that holding ⌘ brings up on an iPad, and in the menu bar on a Mac.
    .commands {
      CommandMenu("Go") {
        Button("Map") { model.mode = .map }.keyboardShortcut("1")
        Button("Service info") { model.mode = .info }.keyboardShortcut("2")
        Button("Plan a trip") { model.mode = .plan }.keyboardShortcut("3")
        Divider()
        Button("Find a stop") { model.open(.search) }.keyboardShortcut("f")
        Button("Routes") { model.open(.routes) }.keyboardShortcut("r")
        Button("My location") { model.locateMe() }.keyboardShortcut("l")
        Button("Refresh buses now") { model.refreshNow() }.keyboardShortcut("r", modifiers: [.command, .shift])
        Divider()
        Button("Settings") { model.open(.settings) }.keyboardShortcut(",")
        Button("Close") { model.closeTop() }.keyboardShortcut(.escape, modifiers: [])
      }
    }
  }
}
