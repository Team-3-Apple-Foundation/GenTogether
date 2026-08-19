//
//  DailyReminderView.swift
//  GenTogether
//
//  Pushed from ProfileView's "Daily Reminder" row. Schedules a repeating
//  local notification at a user-picked time. This needs real notification
//  permission, which the user can grant, deny, or revoke later from
//  system Settings at any point — none of that happens through this
//  screen, so the Toggle can never just trust its own last-saved value;
//  see refreshAuthorizationState() below.
//

import SwiftUI
import UserNotifications

struct DailyReminderView: View {
    @AppStorage("dailyReminderHour") private var reminderHour = 10
    @AppStorage("dailyReminderMinute") private var reminderMinute = 0

    // What the user last asked for — NOT the same as "is this actually
    // scheduled right now". If they revoke notification permission in
    // Settings after turning this on, this stays true until
    // refreshAuthorizationState() notices the mismatch and corrects it.
    @AppStorage("dailyReminderEnabled") private var reminderEnabledPreference = false

    @State private var isReminderOn = false
    @State private var showPermissionDeniedAlert = false
    @State private var showTimeSheet = false
    @State private var pendingTime = Date()

    @Environment(\.dismiss) private var dismiss

    private let reminderIdentifier = "dailyReminder"

    var body: some View {
        VStack(spacing: 0) {
            GTHeader(title: "Profile", leading: AnyView(backButton))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleBlock
                    reminderCard
                    changeButton
                }
                .padding(20)
            }
            .background(GTColor.background)
        }
        .background(GTColor.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await refreshAuthorizationState()
        }
        .alert("Notifications are turned off", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") { openSystemSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To get a daily reminder, allow notifications for GenTogether in Settings.")
        }
        .sheet(isPresented: $showTimeSheet) {
            timeSheet
        }
    }

    // MARK: Sections

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily reminder")
                .font(.title.bold())
            Text("Set a time and we'll remind you to play. Practice builds confidence.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var reminderCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedTime)
                    .font(.title2.weight(.bold))
                Text("Daily Reminder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: reminderToggleBinding)
                .labelsHidden()
                .tint(GTColor.brand)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    private var changeButton: some View {
        Button {
            pendingTime = currentTime
            showTimeSheet = true
        } label: {
            Text("Change Daily Reminder")
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.bordered)
        .tint(GTColor.brand)
    }

    private var timeSheet: some View {
        VStack(spacing: 20) {
            Text("Change Daily Reminder")
                .font(.headline)
                .padding(.top, 20)

            DatePicker(
                "Reminder time",
                selection: $pendingTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()

            HStack(spacing: 12) {
                Button {
                    showTimeSheet = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    saveTime()
                } label: {
                    Text("Save")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(GTColor.brand)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    // MARK: Toggle handling

    /// Routes user taps through the permission flow while keeping the
    /// on-appear reconciliation (which writes `isReminderOn` directly, not
    /// through this binding) from being mistaken for a user action.
    private var reminderToggleBinding: Binding<Bool> {
        Binding(
            get: { isReminderOn },
            set: { newValue in
                isReminderOn = newValue
                Task { await handleToggle(newValue) }
            }
        )
    }

    private func handleToggle(_ turningOn: Bool) async {
        guard turningOn else {
            reminderEnabledPreference = false
            cancelReminder()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            reminderEnabledPreference = true
            scheduleReminder()

        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted {
                reminderEnabledPreference = true
                scheduleReminder()
            } else {
                reminderEnabledPreference = false
                isReminderOn = false
                showPermissionDeniedAlert = true
            }

        default:
            // .denied (or any other non-granted state): iOS won't show the
            // system permission prompt a second time once denied, so
            // asking again would silently do nothing — send them to
            // Settings instead.
            reminderEnabledPreference = false
            isReminderOn = false
            showPermissionDeniedAlert = true
        }
    }

    /// Reconciles the Toggle with the real, current system permission —
    /// run every time this screen appears, since the user could have
    /// changed notification permission from system Settings since the
    /// last time we checked, and `reminderEnabledPreference` alone
    /// wouldn't reflect that.
    private func refreshAuthorizationState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let systemAllows = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        isReminderOn = systemAllows && reminderEnabledPreference

        if reminderEnabledPreference && !systemAllows {
            reminderEnabledPreference = false
        }
    }

    // MARK: Scheduling

    private func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Time to practice!"
        content.body = "Take a few minutes to sharpen your eye for AI-generated images."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Time helpers

    private var currentTime: Date {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private var formattedTime: String {
        currentTime.formatted(date: .omitted, time: .shortened)
    }

    private func saveTime() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: pendingTime)
        reminderHour = components.hour ?? reminderHour
        reminderMinute = components.minute ?? reminderMinute
        showTimeSheet = false

        if isReminderOn {
            scheduleReminder()
        }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(.systemGray5)))
        }
    }
}

#Preview {
    NavigationStack {
        DailyReminderView()
    }
}
