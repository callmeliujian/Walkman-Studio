import SwiftUI

struct ITunesStorefrontPicker: View {
    @Binding var selection: ITunesStorefront
    let locale: Locale

    var body: some View {
        let options = ITunesStorefront.supported.map { storefront in
            (storefront: storefront, name: locale.localizedString(forRegionCode: storefront.countryCode) ?? storefront.countryCode)
        }.sorted {
            $0.name.compare($1.name, options: .caseInsensitive, locale: locale) == .orderedAscending
        }

        Picker(L10n.tr("Country or Region"), selection: $selection) {
            ForEach(options, id: \.storefront) { option in
                Text(verbatim: option.name).tag(option.storefront)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }
}
