
import SwiftUI

/// Profile tab's landing screen — a settings hub. Each row here just
/// navigates somewhere else; none of these rows hold real settings logic
/// themselves (that lives in the pushed screens, e.g. GuestAccountView).
struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    // Not wired to real app-wide dark mode yet — that's a separate task.
    // This just gets the row's Toggle UI in place.
    @State private var isDarkMode = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GTHeader(title: "Profile")

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        group("Manage Account") {
                            NavigationLink {
                                if authViewModel.isAnonymous {
                                    GuestAccountView()
                                } else {
                                    LoggedInAccountView()
                                }
                            } label: {
                                ProfileRow(
                                    title: authViewModel.displayName ?? "Guest",
                                    subtitle: "Update your details"
                                ) {
                                    InitialsAvatar(name: authViewModel.displayName ?? "G")
                                } trailing: {
                                    chevron
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        group("Accessibility") {
                            NavigationLink {
                                TextSizeView()
                            } label: {
                                ProfileRow(title: "Text Size", subtitle: "Adjust the size") {
                                    iconCircle("textformat.size")
                                } trailing: {
                                    chevron
                                }
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 58)

                            ProfileRow(title: "Theme", subtitle: "Dark Mode") {
                                iconCircle("moon.stars.fill")
                            } trailing: {
                                Toggle("", isOn: $isDarkMode)
                                    .labelsHidden()
                                    .tint(GTColor.brand)
                            }
                        }

                        group("Game Preferences") {
                            NavigationLink {
                                InterestsPreferenceView()
                            } label: {
                                ProfileRow(title: "Your Interests", subtitle: "Change interests") {
                                    iconCircle("heart.fill")
                                } trailing: {
                                    chevron
                                }
                            }
                            .buttonStyle(.plain)

                            Divider().padding(.leading, 58)

                            NavigationLink {
                                DailyReminderView()
                            } label: {
                                ProfileRow(title: "Daily Reminder", subtitle: "Set a notification") {
                                    iconCircle("bell.fill")
                                } trailing: {
                                    chevron
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
                .background(GTColor.background)
            }
            .background(GTColor.background)
        }
    }

    // MARK: Row building blocks

    /// One labeled group: a small caption above a white rounded card
    /// containing the group's rows.
    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .gtCardBackground()
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(.systemGray3))
    }

    private func iconCircle(
        _ systemName: String,
        background: Color = GTColor.tipSoft,
        tint: Color = GTColor.tip
    ) -> some View {
        Circle()
            .fill(background)
            .frame(width: 44, height: 44)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }

}

/// A single settings row: leading icon, title + subtitle, trailing
/// accessory (a chevron for navigation rows, a Toggle for the Theme row).
private struct ProfileRow<Icon: View, Trailing: View>: View {
    let title: String
    let subtitle: String
    let icon: Icon
    let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailing
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
