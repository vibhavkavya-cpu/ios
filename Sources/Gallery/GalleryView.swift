import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoID: UUID?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()

                if appState.libraryManager.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(RetroTheme.mutedText)
                        Text("NO EXPOSURES ON ROLL")
                            .font(RetroTheme.monoLabel(12))
                            .foregroundColor(RetroTheme.mutedText)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(appState.libraryManager.items) { item in
                                Button {
                                    selectedPhotoID = item.id
                                } label: {
                                    GeometryReader { geo in
                                        ZStack(alignment: .bottomTrailing) {
                                            if let img = appState.libraryManager.loadThumbnail(for: item) {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: geo.size.width, height: geo.size.width)
                                                    .clipped()
                                            } else {
                                                Rectangle()
                                                    .fill(RetroTheme.surface)
                                                    .frame(width: geo.size.width, height: geo.size.width)
                                            }

                                            if item.metadata.isRawDNG {
                                                Text("RAW")
                                                    .font(RetroTheme.monoLabel(8, weight: .bold))
                                                    .foregroundColor(.black)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(RetroTheme.amberAccent)
                                                    .padding(4)
                                            }
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CAMERA ROLL (\(appState.libraryManager.items.count))")
                        .font(RetroTheme.monoLabel(12, weight: .semibold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("DONE") {
                        dismiss()
                    }
                    .font(RetroTheme.monoLabel(12, weight: .semibold))
                    .foregroundColor(RetroTheme.amberAccent)
                }
            }
            .toolbarBackground(RetroTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .fullScreenCover(item: Binding(
                get: {
                    appState.libraryManager.items.first(where: { $0.id == selectedPhotoID })
                },
                set: { selectedPhotoID = $0?.id }
            )) { item in
                PhotoDetailView(initialItemID: item.id)
                    .environmentObject(appState)
            }
        }
    }
}
