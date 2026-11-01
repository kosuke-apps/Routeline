import SwiftUI

/// The rule that chooses between the phone layout and the wide one, and the numbers of the wide layout. The rule goes by the
/// width of the window, not by the kind of device: Split View, Slide Over, Stage Manager and a Mac window give an iPad a window as
/// narrow as a phone's, and then the phone layout is the right one.
enum WideLayout {
  /// Windows at least this wide (in points) get the wide layout.
  static let threshold: CGFloat = 700

  static func isWide(width: CGFloat, horizontalSizeClass: UserInterfaceSizeClass?) -> Bool {
    horizontalSizeClass != .compact && width >= threshold
  }

  /// The rail at the left edge: a column of round buttons floating over the map.
  static let railWidth: CGFloat = 56
  static let railMargin: CGFloat = 12
  static let gap: CGFloat = 8

  /// The panel's width: a little narrower in a window under 900 points, so that the map keeps room.
  static func panelWidth(forWidth width: CGFloat) -> CGFloat { width >= 900 ? 380 : 340 }

  /// Where the panel starts, and how much of the map's left side the rail and the panel cover together.
  static var panelOrigin: CGFloat { railMargin + railWidth + gap }
  static func leadingInset(forWidth width: CGFloat) -> CGFloat { panelOrigin + panelWidth(forWidth: width) + gap }

  /// What fills the panel. A selected stop, bus, trip or journey, the search, the route list and the settings come first;
  /// otherwise the service board or the planner while that mode is on; otherwise there is no panel and the map has the whole
  /// window. The settings are in the panel, not in an inspector: an inspector wraps the whole screen in a split view controller,
  /// and when it moves the map's view between its columns MapLibre removes a key-value observer it never added and the app
  /// aborts (seen in the iPad simulator).
  static func showsPanel(mode: AppMode, sheet: ActiveSheet?) -> Bool {
    switch sheet {
    case .stop?, .bus?, .trip?, .journey?, .search?, .routes?, .settings?: return true
    case nil: return mode != .map
    }
  }
}

/// Measures the window's width (the whole window, whatever is laid over the map).
struct WindowWidthKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The modes and settings as round buttons down the left edge, in place of the menu drawer.
struct WideRail: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(spacing: 4) {
      item(.map, title: "Map", symbol: "map")
      item(.info, title: "Service info", symbol: "exclamationmark.bubble", badge: model.visibleActiveAlerts.count)
      item(.plan, title: "Plan a trip", symbol: "arrow.triangle.turn.up.right.diamond")
      Divider().frame(width: 28).padding(.vertical, 4)
      Button { model.sheet = model.sheet == .settings ? nil : .settings } label: {
        icon("gearshape", selected: model.sheet == .settings)
      }
      .buttonStyle(.plain)
      .hoverEffect(.highlight)
      .accessibilityLabel(Text("Settings"))
      .help(Text("Settings"))
    }
    .padding(.vertical, 6)
    .frame(width: WideLayout.railWidth)
    .background(.regularMaterial, in: Capsule())
    .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
  }

  private func item(_ mode: AppMode, title: LocalizedStringKey, symbol: String, badge: Int = 0) -> some View {
    Button {
      model.mode = mode
      // A list that was open over the map (search, routes) gives way to the mode that was chosen.
      if model.sheet == .search || model.sheet == .routes || model.sheet == .settings { model.sheet = nil }
    } label: {
      icon(symbol, selected: model.mode == mode)
        .overlay(alignment: .topTrailing) {
          if badge > 0 {
            Text("\(badge)").font(.caption2.weight(.bold)).foregroundStyle(.white)
              .padding(.horizontal, 5).padding(.vertical, 1).background(.orange, in: Capsule())
              .offset(x: 2, y: 2)
          }
        }
    }
    .buttonStyle(.plain)
    .hoverEffect(.highlight)
    .accessibilityLabel(Text(title))
    .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
    .help(Text(title))
  }

  private func icon(_ symbol: String, selected: Bool) -> some View {
    Image(systemName: symbol)
      .font(.system(size: 19, weight: .medium))
      .foregroundStyle(selected ? Color.accentColor : Color.primary)
      .frame(width: 44, height: 44)
      .background(selected ? Color.accentColor.opacity(0.14) : .clear, in: Circle())
      .contentShape(Circle())
  }
}

/// The panel at the left of the map: what the sheets show on a phone, and the service board and the planner, beside the map.
struct WidePanel: View {
  @Environment(AppModel.self) private var model
  let width: CGFloat

  var body: some View {
    ZStack {
      // The service board and the planner stay in the tree while their mode is on, so that a stop opened on top of them
      // (and put away again) leaves the planner's form, results and pushed screens as they were.
      if model.mode == .info { InfoView().background(Color(.systemGroupedBackground)) }
      if model.mode == .plan { PlanView().background(Color(.systemGroupedBackground)) }
      if let sheet = model.sheet {
        content(for: sheet).background(Color(.systemBackground))
      }
    }
    .frame(width: width)
    .frame(maxHeight: .infinity)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
  }

  @ViewBuilder private func content(for sheet: ActiveSheet) -> some View {
    switch sheet {
    case .stop(let id): withPutAway { StopSheet(stopID: id) }
    case .bus(let id): withPutAway { BusSheet(vehicleID: id) }
    case .trip(let id, let date): withPutAway { TripSheet(tripID: id, date: date) }
    case .journey: withPutAway { JourneySheet() }
    case .search: SearchSheet()
    case .routes: RoutesSheet()
    case .settings: SettingsView().background(Color(.systemGroupedBackground))
    }
  }

  /// A stop, bus, trip or journey can be put away into the dock, as swiping its sheet down does on a phone.
  private func withPutAway<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    VStack(spacing: 0) {
      HStack {
        Button { model.minimizeSheet() } label: {
          Image(systemName: "chevron.left").font(.footnote.weight(.bold)).foregroundStyle(.secondary).frame(width: 44, height: 24)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityLabel(Text("Put away"))
        .help(Text("Put away"))
        Spacer()
      }
      .padding(.top, 6)
      content()
    }
  }
}
