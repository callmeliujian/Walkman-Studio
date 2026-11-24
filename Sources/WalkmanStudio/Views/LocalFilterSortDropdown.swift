import SwiftUI

struct LocalFilterSortDropdown: View {
    @ObservedObject private var localization = AppLocalization.shared
    @Binding var formatFilter: String
    @Binding var sortOption: LocalSortOption
    let formatOptions: [(id: String, label: String)]

    @State private var isHovered = false

    private var isFormatActive: Bool {
        formatFilter != "ALL"
    }

    private var isSortActive: Bool {
        sortOption != .artistAZ
    }

    private var isFilterOrSortActive: Bool {
        isFormatActive || isSortActive
    }

    private var activeFormatLabel: String {
        formatOptions.first(where: { $0.id == formatFilter })?.label ?? formatFilter
    }

    var body: some View {
        Menu {
            // -------------------------------------------------------------
            // SECTION 1: Audio Formats
            // -------------------------------------------------------------
            Section(L10n.tr("Audio Format")) {
                ForEach(formatOptions, id: \.id) { opt in
                    Button {
                        formatFilter = opt.id
                    } label: {
                        HStack {
                            if formatFilter == opt.id {
                                Image(systemName: "checkmark")
                            }
                            if opt.id == "HI-RES" {
                                Label(opt.label, systemImage: "waveform")
                            } else {
                                Text(opt.label)
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // SECTION 2: Sort Criteria
            // -------------------------------------------------------------
            Section(L10n.tr("Sort By")) {
                ForEach(LocalSortOption.allCases) { opt in
                    Button {
                        sortOption = opt
                    } label: {
                        HStack {
                            if sortOption == opt {
                                Image(systemName: "checkmark")
                            }
                            Label(L10n.lookup(opt.rawValue), systemImage: opt.iconName)
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // SECTION 3: Reset
            // -------------------------------------------------------------
            if isFilterOrSortActive {
                Divider()
                Button(role: .destructive) {
                    formatFilter = "ALL"
                    sortOption = .artistAZ
                } label: {
                    Label(L10n.tr("Reset Filter & Sort"), systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            ZStack {
                // Circular Liquid Glass foundation fill
                Circle()
                    .fill(
                        isFilterOrSortActive ?
                            Color.white.opacity(isHovered ? 0.16 : 0.10) :
                            Color.white.opacity(isHovered ? 0.09 : 0.045)
                    )

                // Top specular refraction sheen
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(isHovered ? 0.32 : (isFilterOrSortActive ? 0.24 : 0.14)), location: 0.0),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 7)
                    Spacer(minLength: 0)
                }
                .clipShape(Circle())

                // Filter icon (3 horizontal decreasing lines), enlarged
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 16.5, weight: .semibold))
                    .foregroundStyle(
                        isFilterOrSortActive ?
                            WalkmanTheme.hiResGold :
                            (isHovered ? Color.white : WalkmanTheme.silverLight)
                    )

                // Active beacon indicator (gold dot at top right when filter or sort is active)
                if isFilterOrSortActive {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(WalkmanTheme.hiResGold)
                                .frame(width: 5.5, height: 5.5)
                                .shadow(color: Color.black.opacity(0.4), radius: 1, x: 0, y: 1)
                        }
                        Spacer()
                    }
                    .padding(5.5)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(
                        isFilterOrSortActive ?
                            WalkmanTheme.hiResGold.opacity(isHovered ? 0.60 : 0.38) :
                            Color.white.opacity(isHovered ? 0.26 : 0.11),
                        lineWidth: 0.85
                    )
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.22 : 0.12), radius: isHovered ? 3.5 : 2, x: 0, y: 1)
            .scaleEffect(isHovered ? 1.03 : 1.0)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(L10n.tr("Filter & Sort: \(activeFormatLabel) • \(L10n.lookup(sortOption.rawValue))"))
        .onHover { hovering in
            guard isHovered != hovering else { return }
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHovered {
                isHovered = false
                NSCursor.pop()
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
        .fixedSize()
    }
}
