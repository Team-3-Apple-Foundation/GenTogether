//
//  DailyReminderView.swift
//  GenTogether
//
//  Placeholder pushed from ProfileView's "Daily Reminder" row. Real
//  notification-scheduling controls come later — this exists so the
//  navigation link has somewhere to go without crashing.
//

import SwiftUI

struct DailyReminderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Daily Reminder")
                .font(.title.bold())
            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GTColor.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DailyReminderView()
    }
}
