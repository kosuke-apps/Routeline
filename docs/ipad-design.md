# Routeline on iPad: design note

Status: implemented in the 0.8 series (see the notes marked **Changed** below, where the build taught something). Written 2026-10-31 for version 0.7.5 (`81ff05e`).

Goal: a real iPad app, not the iPhone screen stretched. The same `.ipa` runs on iPhone and iPad; the iPhone layout does not
change. On an Apple silicon Mac the app can run as "Designed for iPad" from Xcode (that is how it is tested; a Mac download is
not promised).

## 1. What was looked at, and what was seen

Observation, not opinion. Routeline 0.7.5 was built with `TARGETED_DEVICE_FAMILY` set to `1,2` and nothing else changed, and run
in the iPad Pro 13-inch simulator (iOS 27.0), portrait and landscape, light appearance, with the live city feeds.

- The map fills the screen and works. The three round buttons (search, routes, my location) sit at the right edge and the
  menu button at the left edge, far apart on a 13-inch screen.
- A stop sheet comes up as a card about 520 pt wide, at the bottom centre of the screen, and the map stays usable behind it. It
  covers the middle of the map, which is where the selected stop is centred (the map is moved up by `bottomInset`, a phone idea).
- The menu is the 304 pt drawer over a dimmed map. With a 13-inch screen it hides a small part, but needs two taps (open, choose)
  for something that could always be on screen.
- "Plan a trip" and "Service info" are full-screen lists with the map hidden. Their content stretches to nearly the full width
  of the window: in landscape the trip form's fields and the "Find routes" button run across it, and the three tiles of
  Service info become very large.
- Orientation: `Info.plist` lists portrait only, yet the app rotated to landscape in the iPad simulator. For an iPad app the
  four orientations should be declared on purpose (`UISupportedInterfaceOrientations~ipad`), not left to happen.
- Mac: `xcodebuild` with the destination "My Mac (Designed for iPad)" built the current app successfully. The product is the same
  arm64 iOS build (`Debug-iphoneos/Routeline.app`, platform IOS, with `MapLibre.framework`); the MapLibre package ships only iOS
  device and iOS simulator slices, and a Designed-for-iPad app uses the iOS slice. It has not been run on the Mac yet.

Everything below that says "will" is a proposal.

## 2. One rule for the layout: width, not device

The layout is chosen by the width of the window, not by "iPad":

- **Compact** (width under 700 pt, or `horizontalSizeClass == .compact`): exactly today's layout. This covers every iPhone, an iPad
  in Slide Over or in Split View at 1/3 (and at 1/2, which is under 700 pt on the iPads checked here: to confirm), and a small
  window on the Mac.
- **Wide** (700 pt and more, regular width): the new layout below.

The two layouts share the same state (`AppModel.sheet`, `mode`, `focus`, `dockedStopID`, ...), so a window that is resized across
the threshold keeps what the rider was looking at; only where it is drawn changes. The threshold is a first guess to tune on the
iPad mini (744 pt wide in portrait) and in Split View at 2/3.

Why not `UIDevice.userInterfaceIdiom`: Split View, Stage Manager and a resizable Mac window all give an iPad an iPhone-sized
window, and the layout must follow.

A pure function (`WideLayout.isWide(width:sizeClass:)`) holds the rule so that it can be unit-tested.

## 3. The wide layout

```
+------+------------------------------------------------+
| rail | +-----------+   status pill (centre of the map)   |
|      | |  panel    |                                  o |
| map  | |  (stop,   |          the map                 o |
| info | |  bus,     |                                  o |
| plan | |  trip,    |                                      |
|      | |  search…) |                       dock chips     |
| ...  | +-----------+                                      |
+------+------------------------------------------------+
```

### 3.1 Map

One `MapContainer`, always in the same place in the view tree. It is never re-created when the layout changes, because that
would reload the style and lose the camera. The wide layout is built from overlays and insets around it.

- The map keeps the whole window. A panel floats over its left part, so the map shows through the gaps.
- `MapState.bottomInset` (a height) becomes a pair of insets (`leading` and `bottom`). In the wide layout only `leading` is used:
  `fly` moves the camera east to centre the selection in the free part, and `fitBounds` pads its left side with the panel's
  width. Compact keeps `bottom` and `leading = 0`; the arithmetic for it does not change.
- The credits (the MapLibre logo and the "i", `placeCredits`) are at the bottom left today, under where the panel will be. In the
  wide layout they move to the bottom right (`logoViewPosition` / `attributionButtonPosition`).
- Controls (search, routes, my location) stay at the top right. Their 44 pt hit areas stay.

### 3.2 Navigation rail instead of the drawer

A 56 pt rail of round buttons floating at the left edge: Map, Service info, Plan a trip, then Settings, with the alert count
badge on Service info (**Changed:** Routes and Find a stop stay where they are, with the round buttons at the right, which open
the panel; there was no reason to have them twice). It replaces the hamburger button and the drawer in the wide layout; the drawer stays in compact.

Why: on a large screen it costs a few points and saves a tap on every switch; the drawer's dimmed map hides what the rider is
watching. The edge-swipe strip (`EdgeSwipeArea`) is not used in the wide layout: it would collide with the system's Split View
and Stage Manager edge gestures.

Not chosen: `NavigationSplitView` for the whole app. Its detail column is rebuilt by the system on a column change and the map
must not be; a hand-made layout around the one map is simpler to keep alive.

### 3.3 Left panel: stop, bus, trip, journey, search, routes

`StopSheet`, `BusSheet`, `TripSheet`, `JourneySheet`, `SearchSheet` and `RoutesSheet` are reused as they are, but hosted by a
panel instead of `.sheet`:

- 380 pt wide (340 when the window is under 900 pt wide), full height minus the safe area and a 12 pt margin, rounded corners,
  `regularMaterial` background, over the left part of the map. The map stays interactive in the free part.
- No detents. A stop's sheet today rests at 320 pt and is pulled up to read more; a panel shows the whole board at once, which is
  the main gain on a 13-inch screen (twelve or more rows instead of three).
- Contents follow `AppModel.sheet` exactly as the sheet does. Selecting a bus from a stop's board changes the panel's content in
  place and keeps the "Back to <stop>" button.
- Closing: the cross, a tap on the empty map and Escape work as now (`clearSelection`). The swipe-down gesture that minimises a
  sheet is replaced in the panel's header by a "minimise" button that calls `minimizeSheet()`; the dock chips (bottom right) still
  bring it back. So `dockedStopID`, `dockedVehicleID` and `Dock` do not change.
- Search and Routes open in the same panel (Search as a field at the top with the results below, like a map app on iPad), not in a
  second sheet over the first.
- `.sheet(item:)` in `RootView` returns `nil` in the wide layout and the panel shows its content instead. When the window is made
  narrow the sheet appears again for the same `model.sheet`.

### 3.4 Plan a trip and Service info

Today both replace the map. In the wide layout they become panel contents with the map still visible beside them:

- **Plan a trip**: the existing `PlanView` (form, saved places, results, journey details in its own `NavigationStack`) goes in the
  panel. A journey selected from the results is drawn on the map right away (`mapJourney`, today reached through "show on map"
  and a sheet), and the panel shows its steps. The planner's result cards keep their design.
- **Service info**: the dashboard (tiles, alerts, delays, cancellations, trips without a position, favourites) goes in the panel;
  "Show on map" focuses the route on the map beside it without leaving the mode. Today `focusRoute` switches `mode` to `.map`;
  the wide layout does not switch it.

Why: the map is the point of the app, and both screens exist to be looked at together with it. It also removes the stretched
form fields and tiles seen in section 1.

The panel uses the same `PlanView` / `InfoView` code, so only the container and the two mode switches differ.

### 3.5 Settings

**Changed:** the settings are the panel's content too, not an inspector. The proposal was a trailing `.inspector`; the first
build with it aborted in the iPad simulator, because `.inspector` puts the whole screen in a split view controller and, when it
moves the map's view between its columns, MapLibre removes a key-value observer it never added (an Objective-C exception in
`MLNMapView` on leaving the window). The map stays visible beside the panel, so colours, line widths and the marker size can
still be watched while they change, which was the point.

### 3.6 Smaller pieces

- **Status pill, focus chip, route chooser**: centred over the free part of the map (to the right of the panel), not the window;
  the chip and chooser get a maximum width (about 560 pt) instead of the window width.
- **Live card** (`LiveSummary`): a popover already (fixed 320 pt); regular width gives it the real popover look. No change.
- **Dock**: unchanged, bottom right.
- **Trip details, timetable** (`TimetableView`, `PunctualityDetail`): pushed inside the panel with the same navigation stack. The
  charts and the timetable grid are given the panel's width; nothing else changes. The hour column of the timetable is fixed at
  54 pt and fits.
- **Notification badge, notification text**: no change.

### 3.7 What does not change

Every compact layout: the bottom sheets, the dock, the drawer, the edge swipe, `bottomInset` arithmetic, all screens' content.
No iPhone-only screen is removed. The regression check is the same four iPhone screenshots (map, stop board, trip planner, bus
stops) taken before and after on the iPhone 18 Pro simulator at the same moment of the feed, compared by eye and by pixel
difference of the parts that do not move with the live data.

## 4. Keyboard and pointer

Hardware keyboard (also on the Mac): declared with `.commands` on the scene so that they show in the iPad shortcut overlay
(hold ⌘) and in the Mac menu bar.

| Action | Shortcut |
|---|---|
| Map / Service info / Plan a trip | ⌘1 / ⌘2 / ⌘3 |
| Find a stop (focus the search field) | ⌘F |
| Routes | ⌘R |
| My location | ⌘L |
| Refresh the buses now | ⇧⌘R |
| Settings | ⌘, |
| Close the panel (as the cross does) | Escape |
| Zoom the map in / out | ⌘+ / ⌘− |
| Move in the search results | ↑ ↓, open with Return |

Pointer: `hoverEffect` on the small controls (the round buttons, the dock chips, the route chips, the close and favourite icons)
and a highlight on list rows. Secondary click (right click or two-finger click) on the map drops the pin that a long press drops
today (`UIContextMenuInteraction` or a tap recogniser with `buttonMaskRequired = .secondary`); a tap on the map with a pointer
works already as a tap. Scroll wheel and trackpad scroll over the map need checking: if MapLibre's recognisers do not accept
scroll events, a recogniser with `allowedScrollTypesMask` is added.

Drag and drop: none. The app has nothing the rider drags (the one share action is `ShareLink`), so none is added.

## 5. Split View, Stage Manager, small widths, text size

- One window. `UIApplicationSupportsMultipleScenes` is not declared today and stays that way: the model (selection, sheet, poll,
  data meter, notification ledger) is created once in `RoutelineApp` and shared, and two windows would show the same selection and
  could not be told apart. Multiple windows are out of scope for this version.
- `UIRequiresFullScreen` is not set, so Split View, Slide Over and Stage Manager are available.
- The window is any size from about 320 pt up. Under 700 pt the compact layout applies; at 1/3 and 1/2 of an iPad that is the
  phone layout, as the brief asks. The wide layout must hold from 700 pt: with the rail (64) and the panel (340) the map has at
  least about 300 pt, which is small but usable on the iPad mini in portrait; to tune.
- Larger text sizes: the panel and the rail use the same Dynamic Type styles as the phone. The rail's labels are shown only as
  accessibility labels and hover tooltips; at accessibility sizes the rail grows to show text. The panel scrolls.
- All four orientations are allowed on iPad: `UISupportedInterfaceOrientations~ipad`. The iPhone key stays portrait.

## 6. The Mac, as "Designed for iPad"

Planned checks (none run yet; section 1 only records that the build links):

- **Window**: resize from small to large; the layout switches at 700 pt; the minimum size is set so that the compact layout never
  gets narrower than the phone layout supports.
- **MapLibre**: the iOS slice of the MapLibre package is what runs. The renderer backend it uses (OpenGL ES or Metal) under
  Designed for iPad, trackpad scroll and pinch, and the 313 start-up log lines about an `NSPredicate` function being "forbidden"
  (seen on the iOS 27 simulator, harmless to the line widths) are checked in the first run.
- **Location**: a Mac has no GPS; the system gives a Wi-Fi based position of coarser accuracy, so "my location" and "from my
  location" in the planner will work but may be off by far more than on a phone. To be measured and then stated in the release
  notes.
- **Haptics**: `UISelectionFeedbackGenerator` does nothing on a Mac. The one use is optional (a setting), so no change.
- **Background work**: `BGAppRefreshTask` (`dev.kosuke.headway.watch`) and the "pause in the background" setting. Whether a Mac
  runs the task, and what the scene phases are for a minimised window, is unknown and is to be observed. If the task never
  runs, notifications on the Mac work only while the window is open; the setting's text says "iOS decides", which is true on both.
- **Notifications**: permission prompt, the late/early notification text and its small picture (a temporary file attachment).
- **Menu bar**: the `.commands` above, the app name, and the Settings item.
- **Cellular words**: "mobile data" and "Save mobile data" mean a hotspot connection on a Mac; the wording stays, the behaviour
  (`NWPath.isExpensive`) is the same call.
- **Open Settings**: `UIApplication.openSettingsURLString` (used when notifications are refused) may not open the right place
  from a Designed-for-iPad app; to check.
- **Install**: a Designed-for-iPad app reaches a Mac through the Mac App Store, which needs the paid Developer Program. The
  unsigned `.ipa` of the releases cannot be installed on a Mac by any official way; the Mac is tested through Xcode only, and the
  release notes will say exactly that.

## 7. Risks

1. **The map must not be re-created.** If a layout change moves `MapContainer` in the view tree, SwiftUI rebuilds it: the
   style reloads (a blank map for about a second) and the camera is lost. Mitigation: one `MapContainer`, layout by overlays and
   insets only; a test that counts `makeUIView` calls over a resize.
2. **Camera arithmetic.** `fly` and `fitBounds` assume a bottom inset. Adding a leading inset touches code that the iPhone also
   uses; the iPhone path must give identical numbers (unit-tested on the arithmetic, which is extracted into a pure function).
3. **Sheet to panel hand-over.** `.sheet(item:)` and the panel must never both show the same content, and a sheet dismissed by the
   layout (not by the rider) must not call `minimizeSheet()`. To be checked by resizing with each kind of sheet open.
4. **`PlanView` and `InfoView` in a panel.** `PlanView` owns a `NavigationStack(path:)`, sets `model.planPushed`, and uses its own
   sheets (place picker, options, saved places); in a 380 pt panel the sheets are presented over the whole window, which is
   acceptable, and `.presentationDetents` there must be tested. `InfoView` calls `focusRoute`, which changes `mode`.
5. **Settings as an inspector.** Happened: see section 3.5. The settings are in the panel.
6. **Pointer and keyboard on the map.** MapLibre's gesture recognisers were written for touch; scroll and right click may need
   extra recognisers (section 4).
7. **Split View.** The Simulator and `xcodebuild` have no scripted way to put the app in Split View at 1/3, 1/2, 2/3; the checks
   either use the system gestures through the simulator tool or a window-size override used only in tests. If neither works, the
   release notes will say Split View was not checked rather than say it was.
8. **Data and battery.** A bigger map and a panel redraw more per second than the phone layout. The bus animation runs at 20
   frames a second already; to be measured (CPU at idle on the iPad simulator and on the Mac) with the same recipe as before.
9. **Two orientations of the same state.** The rail, panel and map insets all depend on the window width; a rotation while a
   sheet is animating is the usual place for a wrong inset. To be exercised by rotating with each panel open.
10. **No real iPad.** None has been used. Everything is checked in the iPad simulator and on a Mac; the notes will say "iPad
    simulator and Mac", not "iPad".

## 8. Work order after the go

1. Project: `TARGETED_DEVICE_FAMILY` `1,2`, the iPad orientations, no full-screen requirement; the layout rule and its tests.
2. Map insets as a pair; credits; the panel for stop, bus, trip and journey; the rail; compact unchanged (screenshot comparison).
3. Search and Routes in the panel; Settings as an inspector.
4. Plan a trip and Service info beside the map.
5. Keyboard commands, pointer, secondary click.
6. Mac checks, the full matrix (iPad Pro 13-inch and iPad mini, portrait and landscape, Split View, larger text), sanitizers and
   leak checks.
7. Docs: `AGENTS.md` (its "out of scope: iPad" line and the "iPad layout" idea are removed and the layout is described), README
   (iPad screenshots from the iPad Pro 13-inch simulator), `PRIVACY.md` (no change expected), release notes, version 0.8.0.
