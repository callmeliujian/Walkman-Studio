import SwiftUI

private struct OnlineMetadataPickerModifier<ID: Equatable>: ViewModifier {
    @ObservedObject var lookup: OnlineMetadataLookup
    let identity: ID

    func body(content: Content) -> some View {
        content
            .sheet(item: $lookup.selection, onDismiss: { lookup.cancel() }) { selection in
                OnlineMetadataPickerSheet(selection: selection, lookup: lookup)
            }
            .onChange(of: identity) { _ in lookup.cancel() }
            .onDisappear { lookup.cancel() }
    }
}

extension View {
    func onlineMetadataPicker<ID: Equatable>(_ lookup: OnlineMetadataLookup, identity: ID) -> some View {
        modifier(OnlineMetadataPickerModifier(lookup: lookup, identity: identity))
    }
}
