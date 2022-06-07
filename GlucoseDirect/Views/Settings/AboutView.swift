//
//  AboutView.swift
//  GlucoseDirect
//

import SwiftUI

// MARK: - AboutView

struct AboutView: View {
    @EnvironmentObject var store: AppStore

    @State var showingDeleteLogsAlert = false

    var body: some View {
        Section(
            content: {
                HStack {
                    Text("App version")
                    Spacer()
                    Text("\(AppConfig.appVersion) (\(AppConfig.appBuild))")
                }

                if let appAuthor = AppConfig.appAuthor, !appAuthor.isEmpty {
                    HStack {
                        Text("App author")
                        Spacer()
                        Text(appAuthor)
                    }
                }

                if let appSupportMail = AppConfig.appSupportMail, !appSupportMail.isEmpty {
                    HStack {
                        Text("App email")
                        Spacer()
                        Link(appSupportMail, destination: URL(string: "mailto:\(appSupportMail)")!)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                }

                HStack {
                    Text("App website")
                    Spacer()
                    Link("GitHub", destination: URL(string: AppConfig.githubURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App faq")
                    Spacer()
                    Link("GitHub", destination: URL(string: AppConfig.faqURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App facebook group")
                    Spacer()
                    Link("Facebook", destination: URL(string: AppConfig.facebookURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App donate")
                    Spacer()
                    Link("PayPal", destination: URL(string: AppConfig.donateURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                HStack {
                    Text("App translation")
                    Spacer()
                    Link("Crowdin", destination: URL(string: AppConfig.crowdinURL)!)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Button(
                    action: {
                        store.dispatch(.sendLogs)
                    },
                    label: {
                        Label("Send log file", systemImage: "square.and.arrow.up")
                    }
                )

                Button(
                    action: {
                        showingDeleteLogsAlert = true
                    },
                    label: {
                        Label("Delete log files", systemImage: "trash")
                    }
                ).alert(isPresented: $showingDeleteLogsAlert) {
                    Alert(
                        title: Text("Are you sure you want to delete all log files?"),
                        primaryButton: .destructive(Text("Delete all")) {
                            store.dispatch(.deleteLogs)
                        },
                        secondaryButton: .cancel()
                    )
                }
            },
            header: {
                Label("About \(AppConfig.appName)", systemImage: "info")
            }
        )
    }
}