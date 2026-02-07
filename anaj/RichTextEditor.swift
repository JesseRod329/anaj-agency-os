//
//  RichTextEditor.swift
//  ANAJ
//
//  True WYSIWYG Rich Text Editor for macOS
//

#if os(macOS)
import SwiftUI
import AppKit

struct RichTextEditor: View {
    @Binding var text: String // Persists as HTML
    var placeholder: String = "Add a description..."
    
    // Command handling
    @State private var commandSender = PassthroughSubject<EditorCommand, Never>()
    @State private var selectedColor: Color = .white
    
    // State to track active styles (future implementation for Phase 2)
    @State private var isBoldActive = false
    @State private var isItalicActive = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Formatting Toolbar
            HStack(spacing: AppSpacing.xs) {
                // Headings (Title)
                EditorToolbarButton(icon: "textformat.size", label: nil, tooltip: "Title / Heading", isActive: false) {
                    commandSender.send(.fontSize(24))
                }
                
                ToolbarDivider()
                
                // Bold & Italic
                HStack(spacing: 2) {
                    EditorToolbarButton(icon: nil, label: "B", tooltip: "Bold (⌘B)", isActive: isBoldActive) {
                        commandSender.send(.bold)
                        // Optimistic toggle for UI feedback (real state sync coming in Phase 2)
                        isBoldActive.toggle()
                    }
                    EditorToolbarButton(icon: nil, label: "I", tooltip: "Italic (⌘I)", isActive: isItalicActive) {
                        commandSender.send(.italic)
                        isItalicActive.toggle()
                    }
                }
                .padding(2)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                
                ToolbarDivider()
                
                // Styles
                EditorToolbarButton(icon: "underline", label: nil, tooltip: "Underline", isActive: false) {
                    commandSender.send(.underline)
                }
                EditorToolbarButton(icon: "strikethrough", label: nil, tooltip: "Strikethrough", isActive: false) {
                    commandSender.send(.strikethrough)
                }
                
                ToolbarDivider()
                
                // Color Picker
                EditorColorPicker(selectedColor: $selectedColor) { newColor in
                    commandSender.send(.color(NSColor(newColor)))
                }
                
                Spacer()
                
                // Lists
                EditorToolbarButton(icon: "list.bullet", label: nil, tooltip: "Bullet List", isActive: false) {
                    commandSender.send(.bullet)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.bgSecondary)
            
            // WYSIWYG Editor
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppFonts.body())
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, 4) // Match NSTextView padding
                        .padding(.vertical, 0)
                        .allowsHitTesting(false)
                }
                
                MacEditorTextView(text: $text, commandPublisher: commandSender)
            }
            .padding(AppSpacing.md)
            .frame(minHeight: 120)
        }
        .background(AppColors.bgPrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 16)
            .overlay(AppColors.borderSubtle)
            .padding(.horizontal, 2)
    }
}

// MARK: - Editor Commands
enum EditorCommand: Equatable {
    case bold
    case italic
    case underline
    case strikethrough
    case color(NSColor)
    case fontSize(CGFloat)
    case bullet
}

import Combine

// MARK: - Mac Editor Implementation
struct MacEditorTextView: NSViewRepresentable {
    @Binding var text: String
    var commandPublisher: PassthroughSubject<EditorCommand, Never>
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textColor = .white
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 0, height: 0) // Reset inset to align with placeholder
        
        // Setup initial text from HTML if possible
        if let data = text.data(using: .utf8) {
            if let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributed)
                // Reset text color to white if the HTML didn't specify
                textView.textColor = .white 
            } else {
                textView.string = text
            }
        }
        
        context.coordinator.setupSubscriptions(publisher: commandPublisher, textView: textView)
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = nsView.documentView as! NSTextView
        // Only update if text is empty (reset) to avoid cursor jumping
        if text.isEmpty && !textView.string.isEmpty {
            textView.string = ""
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacEditorTextView
        var cancellables = Set<AnyCancellable>()
        
        init(_ parent: MacEditorTextView) {
            self.parent = parent
        }
        
        func setupSubscriptions(publisher: PassthroughSubject<EditorCommand, Never>, textView: NSTextView) {
            publisher.sink { [weak textView] command in
                guard let textView = textView else { return }
                self.handleCommand(command, in: textView)
            }.store(in: &cancellables)
        }
        
        func handleCommand(_ command: EditorCommand, in textView: NSTextView) {
            let range = textView.selectedRange()
            guard range.length > 0 || command == .bullet else { return } // Apply to selection
            
            let storage = textView.textStorage
            
            switch command {
            case .bold:
                if let font = textView.font {
                    let newFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                    storage?.addAttribute(.font, value: newFont, range: range)
                }
            case .italic:
                if let font = textView.font {
                    let newFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                    storage?.addAttribute(.font, value: newFont, range: range)
                }
            case .underline:
                storage?.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .strikethrough:
                storage?.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .color(let color):
                storage?.addAttribute(.foregroundColor, value: color, range: range)
            case .fontSize(let size):
                if let font = textView.font {
                     let newFont = NSFontManager.shared.convert(font, toSize: size)
                     storage?.addAttribute(.font, value: newFont, range: range)
                }
            case .bullet:
                 textView.insertText("• ", replacementRange: range)
            }
            
            // Trigger save
            textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Convert to HTML for storage
            if let storage = textView.textStorage {
                if let htmlData = try? storage.data(from: NSRange(location: 0, length: storage.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    if let htmlString = String(data: htmlData, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self.parent.text = htmlString
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Components (Reused)

struct ToolbarFormatButton: View {
    let icon: String
    let label: String
    let tooltip: String
    var isProminent: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .italic(label == "I")
                .foregroundStyle(isHovered ? .white : .white.opacity(0.8))
                .frame(width: 32, height: 28)
                .background(isHovered ? Color.blue.opacity(0.3) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovered ? .white : .white.opacity(0.6))
                .frame(width: 30, height: 28)
                .background(isHovered ? Color.white.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

struct RichTextDisplay: View {
    let text: String
    @State private var attributedText: NSAttributedString?
    
    var body: some View {
        Group {
            if let attributed = attributedText {
                Text(AttributedString(attributed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text) // Fallback
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .onAppear {
            parseHTML()
        }
        .onChange(of: text) { _, _ in
            parseHTML()
        }
    }
    
    private func parseHTML() {
        guard let data = text.data(using: .utf8) else { return }
        // Process on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            if let attributed = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
                
                // Adjust color for dark mode reading if needed, HTML often hardcodes black
                let mutable = NSMutableAttributedString(attributedString: attributed)
                mutable.addAttribute(.foregroundColor, value: NSColor.white, range: NSRange(location: 0, length: mutable.length))
                
                DispatchQueue.main.async {
                    self.attributedText = mutable
                }
            }
        }
    }
}
#endif
