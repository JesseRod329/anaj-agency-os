import Foundation
import PDFKit
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#elseif os(iOS)
import UIKit
typealias PlatformImage = UIImage
#endif
import UniformTypeIdentifiers

struct ProcessedAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let type: AttachmentType
    var content: String? // Text content for docs, or Base64 for images
    var previewImage: PlatformImage? // Thumbnail
    
    var name: String { url.lastPathComponent }
    
    enum AttachmentType: String, Equatable, Codable {
        case image
        case document
        case folder
    }
    
    func toCodable() -> CodableAttachment {
        CodableAttachment(id: id, name: name, type: type, content: content)
    }
}

struct CodableAttachment: Codable, Identifiable {
    let id: UUID
    let name: String
    let type: ProcessedAttachment.AttachmentType
    let content: String?
}

class DocumentProcessor {
    
    /// Extract text from various document formats or prepare images
    static func process(urls: [URL]) async -> [ProcessedAttachment] {
        var results: [ProcessedAttachment] = []
        
        for url in urls {
            // Security: access security scoped resources if needed
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            
            guard let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                  let utType = UTType(typeID) else { continue }
            
            if utType.conforms(to: .image) {
                if let image = loadImage(from: url),
                   let base64 = image.base64String() {
                    results.append(ProcessedAttachment(url: url, type: .image, content: base64, previewImage: image))
                }
            } else if utType.conforms(to: .pdf) {
                if let text = extractTextFromPDF(url: url) {
                    results.append(ProcessedAttachment(url: url, type: .document, content: text, previewImage: pdfThumbnail(url: url)))
                }
            } else if utType.conforms(to: .text) || utType.conforms(to: .sourceCode) {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    results.append(ProcessedAttachment(url: url, type: .document, content: text, previewImage: iconFor(type: utType)))
                }
            }
        }
        return results
    }
    
    // MARK: - Helpers
    
    private static func loadImage(from url: URL) -> PlatformImage? {
        #if os(macOS)
        return NSImage(contentsOf: url)
        #elseif os(iOS)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
        #endif
    }
    
    private static func extractTextFromPDF(url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        var fullText = ""
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            fullText += (page.string ?? "") + "\n"
        }
        return fullText
    }
    
    private static func pdfThumbnail(url: URL) -> PlatformImage? {
        guard let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 50, height: 50), for: .cropBox)
    }
    
    private static func iconFor(type: UTType) -> PlatformImage? {
        #if os(macOS)
        return NSWorkspace.shared.icon(for: type)
        #else
        return nil // On iOS, we'd typically use a generic document icon or nil
        #endif
    }
}

#if os(macOS)
extension NSImage {
    func base64String() -> String? {
        guard let tiffRepresentation = self.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        
        // Convert to JPEG for efficiency
        guard let data = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else { return nil }
        return data.base64EncodedString()
    }
}
#elseif os(iOS)
extension UIImage {
    func base64String() -> String? {
        guard let data = self.jpegData(compressionQuality: 0.7) else { return nil }
        return data.base64EncodedString()
    }
}
#endif
