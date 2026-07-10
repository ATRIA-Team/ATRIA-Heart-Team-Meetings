//
//  HelpView.swift
//  ATRIAmac
//

import SwiftUI

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                stepsSection
                categoriesSection
                tipsSection
            }
            .padding(40)
            .frame(maxWidth: 680, alignment: .leading)
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ATRIA Companion App")
                        .font(.largeTitle.bold())
                    Text("macOS folder organiser for heart team meetings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Divider().padding(.top, 8)
        }
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle("How to prepare a patient package")

            stepRow(
                number: "1",
                icon: "arrow.down.circle.fill",
                title: "Drag patient files onto the tiles",
                body: "Drop PDFs or images onto Medical History, Vitals, Blood Tests, or Other. Drop DICOM folders onto Echo, CT, or Coro. Each tile accepts multiple files."
            )
            stepRow(
                number: "2",
                icon: "pencil.line",
                title: "Name the patient folder",
                body: "Type the patient or case name in the \"Folder name\" field on the left panel. This becomes the name of the exported .atria package."
            )
            stepRow(
                number: "3",
                icon: "folder.badge.plus",
                title: "Create the package",
                body: "Press Create Folder, then choose where to save it. ATRIA will organise all the dropped files into a single .atria package at that location."
            )
            stepRow(
                number: "4",
                icon: "icloud.and.arrow.up",
                title: "Upload to iCloud Drive",
                body: "Tap Upload to iCloud in the share row to move the package into your iCloud Drive, where the visionOS ATRIA app can load it directly during a meeting."
            )
            stepRow(
                number: "5",
                icon: "square.and.arrow.up",
                title: "Share directly (optional)",
                body: "Use the Share button to send the .atria package via AirDrop, Mail, or any other method. The recipient can open it on their Apple Vision Pro."
            )
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("File categories")
            Text("Each tile corresponds to a section visible in the visionOS viewer during the meeting.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(categoryRows, id: \.title) { row in
                    HStack(spacing: 14) {
                        Image(systemName: row.icon)
                            .frame(width: 28)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.title).font(.callout.bold())
                            Text(row.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(categoryRows.first?.title == row.title ? Color.clear :
                                categoryRows.last?.title == row.title ? Color.clear : Color.clear)
                    if row.title != categoryRows.last?.title {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private struct CategoryRow { let icon: String; let title: String; let detail: String }
    private let categoryRows: [CategoryRow] = [
        .init(icon: "list.bullet.clipboard.fill", title: "Medical History",  detail: "PDF summaries, referral letters, previous reports"),
        .init(icon: "stethoscope",                title: "Vitals",           detail: "Blood pressure logs, weight charts, monitoring PDFs"),
        .init(icon: "drop.fill",                  title: "Blood Tests",      detail: "Lab results, haematology and biochemistry PDFs"),
        .init(icon: "waveform.path.ecg.text.clipboard.fill", title: "Echo", detail: "Echocardiography DICOM folder"),
        .init(icon: "waveform.path.ecg.rectangle.fill",      title: "CT",   detail: "CT scan DICOM folder"),
        .init(icon: "heart.fill",                 title: "Coro",             detail: "Coronary angiography DICOM folder"),
        .init(icon: "heart.text.clipboard.fill",  title: "Other",            detail: "Any additional documents or images"),
    ]

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Tips")
            tipRow(icon: "arrow.counterclockwise", text: "To start over, quit and relaunch the app — all tiles will be cleared.")
            tipRow(icon: "xmark.circle", text: "Remove a file from a tile by clicking the × next to its name.")
            tipRow(icon: "externaldrive.badge.icloud", text: "iCloud upload requires that you are signed into iCloud and have iCloud Drive enabled in System Settings.")
            tipRow(icon: "eye", text: "Use Show in Finder to locate the package on disk before uploading or sharing.")
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
    }

    private func stepRow(number: String, icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(number)
                    .font(.headline.bold())
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(.secondary)
                    Text(title).font(.callout.bold())
                }
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HelpView()
}
