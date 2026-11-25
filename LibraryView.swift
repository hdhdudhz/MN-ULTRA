import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct MediaItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let filename: String
}

@MainActor
final class MediaLibrary: ObservableObject {
    @Published var items: [MediaItem] = []
    @Published var selectedURL: URL?
    private let folder: URL

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = base.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil
        )) ?? []
        items = urls.filter { ["mp4", "mov", "m4v", "mp3", "m4a", "wav"].contains($0.pathExtension.lowercased()) }
            .map { MediaItem(id: UUID(), name: $0.deletingPathExtension().lastPathComponent, filename: $0.lastPathComponent) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func importFiles(_ urls: [URL]) {
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            let destination = folder.appendingPathComponent(source.lastPathComponent)
            let stem = destination.deletingPathExtension().lastPathComponent
            let ext = destination.pathExtension
            var target = destination
            var n = 2
            while FileManager.default.fileExists(atPath: target.path) {
                target = folder.appendingPathComponent("\(stem)-\(n).\(ext)")
                n += 1
            }
            try? FileManager.default.copyItem(at: source, to: target)
        }
        reload()
    }

    func play(_ item: MediaItem) {
        selectedURL = folder.appendingPathComponent(item.filename)
    }
}

struct LibraryView: View {
    @StateObject private var library = MediaLibrary()
    @State private var importing = false

    var body: some View {
        NavigationStack {
            Group {
                if let url = library.selectedURL {
                    VStack(spacing: 16) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(maxHeight: 360)
                        Text(url.deletingPathExtension().lastPathComponent)
                            .font(.headline)
                        Button("العودة للمكتبة") { library.selectedURL = nil }
                    }
                    .padding()
                } else if library.items.isEmpty {
                    ContentUnavailableView(
                        "مكتبتك فارغة",
                        systemImage: "play.rectangle",
                        description: Text("استورد ملفات الفيديو أو الصوت لتشغيلها دون إنترنت.")
                    )
                } else {
                    List(library.items) { item in
                        Button {
                            library.play(item)
                        } label: {
                            Label(item.name, systemImage: "play.circle")
                        }
                    }
                }
            }
            .navigationTitle("MN ULTRA")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "plus") }
                }
            }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [.movie, .video, .audio],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result { library.importFiles(urls) }
            }
        }
    }
}
