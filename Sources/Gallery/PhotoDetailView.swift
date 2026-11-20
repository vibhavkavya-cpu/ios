import SwiftUI

struct PhotoDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State var currentID: UUID
    @State private var showEXIF: Bool = true
    @State private var exportToast: String?
    @State private var reEditItem: CapturedPhotoItem?

    init(initialItemID: UUID) {
        _currentID = State(initialValue: initialItemID)
    }

    private var currentItem: CapturedPhotoItem? {
        appState.libraryManager.items.first(where: { $0.id == currentID })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if appState.libraryManager.items.isEmpty {
                Color.black.onAppear { dismiss() }
            } else {
                TabView(selection: $currentID) {
                    ForEach(appState.libraryManager.items) { item in
                        ZStack {
                            if let image = appState.libraryManager.loadProcessedImage(for: item) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .tag(item.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showEXIF.toggle()
                            }
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if showEXIF, let item = currentItem {
                    VStack {
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Text(item.metadata.filterName.uppercased())
                                    .font(RetroTheme.monoLabel(12, weight: .semibold))
                                    .foregroundColor(RetroTheme.amberAccent)
                                if item.metadata.isRawDNG {
                                    Text("DNG")
                                        .font(RetroTheme.monoLabel(9, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(RetroTheme.amberAccent)
                                }
                            }

                            Spacer()

                            Button(role: .destructive) {
                                let target = item
                                if let next = appState.libraryManager.items.first(where: { $0.id != target.id }) {
                                    currentID = next.id
                                }
                                appState.libraryManager.deletePhoto(target)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .background(Color.black.opacity(0.75))

                        Spacer()

                        if let toast = exportToast {
                            Text(toast)
                                .font(RetroTheme.monoLabel(11, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(RetroTheme.amberAccent)
                                .padding(.bottom, 8)
                        }

                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                exifCell(title: "ISO", value: "\(item.metadata.iso)")
                                exifCell(title: "SHUTTER", value: item.metadata.shutterSpeed)
                                exifCell(title: "FLASH", value: item.metadata.flashFired ? "ON" : "OFF")
                                exifCell(title: "DATE", value: formattedDate(item.metadata.capturedAt))
                            }

                            Divider().background(RetroTheme.hairline)

                            HStack(spacing: 24) {
                                Button {
                                    reEditItem = item
                                } label: {
                                    Label("RE-EDIT", systemImage: "slider.horizontal.3")
                                        .font(RetroTheme.monoLabel(11, weight: .semibold))
                                        .foregroundColor(.white)
                                }

                                Spacer()

                                Button {
                                    appState.libraryManager.exportItemToPhotos(item) { ok in
                                        exportToast = ok ? "SAVED TO PHOTOS" : "PHOTOS ACCESS DENIED"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                            exportToast = nil
                                        }
                                    }
                                } label: {
                                    Label(item.metadata.isRawDNG ? "EXPORT RAW+JPG" : "EXPORT", systemImage: "square.and.arrow.up")
                                        .font(RetroTheme.monoLabel(11, weight: .semibold))
                                        .foregroundColor(RetroTheme.amberAccent)
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.85))
                    }
                }
            }
        }
        .sheet(item: $reEditItem) { item in
            FilterEditorView(
                initialParameters: item.metadata.appliedParameters,
                sampleOriginalData: appState.libraryManager.loadOriginalData(for: item),
                reEditTargetItem: item
            )
            .environmentObject(appState)
        }
    }

    private func exifCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(RetroTheme.monoLabel(9))
                .foregroundColor(RetroTheme.mutedText)
            Text(value)
                .font(RetroTheme.monoLabel(11, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yy HH:mm"
        return f.string(from: date)
    }
}
