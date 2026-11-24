public struct ITunesStorefront: Hashable, Sendable {
    public let countryCode: String
    public static let unitedStates = Self(countryCode: "US")

    // Regions listed for iTunes Store music purchases at https://support.apple.com/en-us/118205.
    public static let supported: [Self] = """
        AE AG AI AM AR AT AU AZ BB BE BF BG BH BM BN BO BR BS BW BY BZ CA CH CL CO CR CV CY
        CZ DE DK DM DO EC EE EG ES FI FJ FM FR GB GD GH GM GR GT GW HK HN HU ID IE IL IN IT
        JO JP KE KG KH KN KY KZ LA LB LK LT LU LV MD MN MO MT MU MX MY MZ NA NE NG NI NL NO
        NP NZ OM PA PE PG PH PL PT PY QA RO RU SA SE SG SI SK SV SZ TH TJ TM TR TT TW UA UG
        US UZ VE VG VN ZA ZW
        """
        .split(whereSeparator: { $0.isWhitespace })
        .map { Self(countryCode: String($0)) }
}
