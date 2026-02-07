//
//  IconPicker.swift
//  ANAJ
//
//  Reusable icon picker with SF Symbols and emoji support
//

import SwiftUI

struct IconPicker: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    // Preset SF Symbols organized by category
    let projectIcons: [(category: String, icons: [String])] = [
        ("General", ["folder.fill", "doc.fill", "tray.fill", "archivebox.fill", "shippingbox.fill"]),
        ("Development", ["terminal.fill", "chevron.left.forwardslash.chevron.right", "hammer.fill", "wrench.and.screwdriver.fill", "gearshape.fill"]),
        ("Design", ["paintbrush.fill", "paintpalette.fill", "pencil.and.ruler.fill", "wand.and.stars", "sparkles"]),
        ("Business", ["briefcase.fill", "building.2.fill", "chart.bar.fill", "dollarsign.circle.fill", "creditcard.fill"]),
        ("Creative", ["camera.fill", "video.fill", "music.note", "mic.fill", "gamecontroller.fill"]),
        ("Communication", ["bubble.left.fill", "envelope.fill", "phone.fill", "video.bubble.fill", "antenna.radiowaves.left.and.right"]),
        ("Status", ["star.fill", "heart.fill", "bolt.fill", "flame.fill", "flag.fill"]),
        ("Objects", ["lightbulb.fill", "globe", "airplane", "car.fill", "house.fill"])
    ]
    
    // Popular emojis
    let emojis = ["🚀", "💼", "📱", "💻", "🎨", "📝", "🎯", "⚡️", "🔥", "✨", "💡", "📊", "🎬", "🎵", "📸", "🏠", "🌍", "🛠️", "⭐️", "❤️", "🎮", "📚", "🔮", "🌟", "💎", "🏆", "🎪", "🎭", "🎪", "🎨"]
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Icon")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.black.opacity(0.3))
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Icons").tag(0)
                Text("Emoji").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            ScrollView {
                if selectedTab == 0 {
                    // SF Symbols Grid
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(projectIcons, id: \.category) { category in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(category.category)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                                    ForEach(category.icons, id: \.self) { icon in
                                        PickerIconButton(icon: icon, isSelected: selectedIcon == icon) {
                                            selectedIcon = icon
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                } else {
                    // Emoji Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                        ForEach(emojis, id: \.self) { emoji in
                            EmojiButton(emoji: emoji, isSelected: selectedIcon == emoji) {
                                selectedIcon = emoji
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Icon Button

struct PickerIconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? .blue : .white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.2) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Emoji Button

struct EmojiButton: View {
    let emoji: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color.blue.opacity(0.2) : (isHovered ? Color.white.opacity(0.1) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Project Icon Display

struct ProjectIcon: View {
    let icon: String
    var size: CGFloat = 24
    var background: Color = .white.opacity(0.1)
    
    var body: some View {
        Group {
            if icon.first?.isLetter == false && icon.count <= 2 {
                // It's an emoji
                Text(icon)
                    .font(.system(size: size * 0.8))
            } else {
                // It's an SF Symbol
                Image(systemName: icon)
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size + 8, height: size + 8)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    IconPicker(selectedIcon: .constant("folder.fill"))
}
