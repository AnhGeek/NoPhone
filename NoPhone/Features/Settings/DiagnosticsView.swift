import SwiftUI

/// The diagnostic trail, readable and shareable from the device.
///
/// Exists because the hardest bugs in this app happen where a Mac isn't
/// attached: on a TestFlight build, on someone else's iPad, or inside the
/// monitor extension's brief wake-up. Console can't reach any of those.
struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = DiagLog.text

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.sm)
                    .cardSurface()
                    .padding(.horizontal, Space.gutter)
                    .padding(.bottom, Space.xxl)
            }
            .playgroundBackground()
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = text
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    Button {
                        DiagLog.clear()
                        text = DiagLog.text
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .task { text = DiagLog.text }
        }
    }
}

#Preview("Diagnostics") {
    DiagnosticsView()
}
