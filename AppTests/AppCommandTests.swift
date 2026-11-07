import Foundation
import Testing

@testable import Headway

@MainActor @Suite struct AppCommandTests {
  private func model() -> AppModel {
    AppModel(settings: AppSettings(defaults: UserDefaults(suiteName: "headway-tests-\(UUID().uuidString)")!))
  }

  @Test func everyCommandHasItsOwnKey() {
    var seen = Set<String>()
    for command in AppCommand.allCases {
      let id = "\(command.key.character)-\(command.modifiers.rawValue)"
      #expect(seen.insert(id).inserted, "\(command) shares its shortcut with another command")
    }
  }

  @Test func theModeCommandsSwitchTheModeAndClosePanelsOverTheMap() {
    let model = model()
    model.sheet = .search
    AppCommand.info.perform(model)
    #expect(model.mode == .info)
    #expect(model.sheet == nil)

    model.sheet = .routes
    AppCommand.plan.perform(model)
    #expect(model.mode == .plan)
    #expect(model.sheet == nil)

    // A stop that is open stays open, as it does when the rail's button is pressed.
    model.sheet = .stop("1")
    AppCommand.map.perform(model)
    #expect(model.mode == .map)
    #expect(model.sheet == .stop("1"))
  }

  @Test func findRoutesAndSettingsOpenTheirPanels() {
    let model = model()
    model.isWide = true
    AppCommand.find.perform(model)
    #expect(model.sheet == .search)
    AppCommand.routes.perform(model)
    #expect(model.sheet == .routes)
    AppCommand.settings.perform(model)
    #expect(model.sheet == .settings)
  }

  @Test func escapeClosesOneStepAtATime() {
    let model = model()
    model.isWide = true
    model.mode = .plan
    model.sheet = .stop("1")
    AppCommand.close.perform(model)
    #expect(model.sheet == nil)
    #expect(model.mode == .plan)
    AppCommand.close.perform(model)
    #expect(model.mode == .map)
    // With nothing open, Escape does nothing.
    AppCommand.close.perform(model)
    #expect(model.mode == .map)
    #expect(model.sheet == nil)
  }
}
