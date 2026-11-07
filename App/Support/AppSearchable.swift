import SwiftUI

extension View {
  /// `searchable` on an iPhone and an iPad; a plain field above the list on a Mac that runs the iPad app ("Designed for
  /// iPad"). There UIKit's search presentation asserts as soon as the search field is active (`UINavigationBar
  /// defaultSizeForOrientation:` asks the screen for its focused window, which a Mac does not have) and the app quits.
  ///
  /// - Parameters:
  ///   - isPresented: whether the search field is active, for the iPhone and iPad path (nil leaves it to the system).
  ///   - autoFocus: put the cursor in the field at once (the wide layout, where a keyboard is likely to be there).
  func appSearchable(text: Binding<String>, prompt: String, isPresented: Binding<Bool>? = nil, autoFocus: Bool = false) -> some View {
    modifier(AppSearchable(text: text, prompt: prompt, isPresented: isPresented, autoFocus: autoFocus))
  }
}

private struct AppSearchable: ViewModifier {
  @Binding var text: String
  let prompt: String
  let isPresented: Binding<Bool>?
  let autoFocus: Bool

  @ViewBuilder func body(content: Content) -> some View {
    if ProcessInfo.processInfo.isiOSAppOnMac {
      content.safeAreaInset(edge: .top, spacing: 0) { SearchField(text: $text, prompt: prompt, autoFocus: autoFocus) }
    } else if let isPresented {
      content.searchable(text: $text, isPresented: isPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(prompt))
    } else {
      content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(prompt))
    }
  }
}

/// A search field that looks like the system's: a magnifier, the text, and a cross that clears it.
private struct SearchField: View {
  @Binding var text: String
  let prompt: String
  let autoFocus: Bool
  @FocusState private var focused: Bool

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
      TextField(prompt, text: $text)
        .textFieldStyle(.plain)
        .focused($focused)
        .submitLabel(.search)
        .autocorrectionDisabled()
      if !text.isEmpty {
        Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("Clear"))
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 16)
    .padding(.bottom, 6)
    .onAppear { if autoFocus { focused = true } }
  }
}
