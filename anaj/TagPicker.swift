//
//  TagPicker.swift
//  ANAJ
//
//  Reusable tag picker component
//

import SwiftUI
import SwiftData

struct TagPicker: View {
    @Binding var selectedTags: [Tag]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateTag = false
    @State private var newTagName = ""
    @State private var newTagColor = "#5AE6FF"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected Tags
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(selectedTags) { tag in
                            TagChip(tag: tag, isSelected: true) {
                                removeTag(tag)
                            }
                        }
                    }
                }
            }
            
            // Tag Selector Menu
            Menu {
                ForEach(allTags) { tag in
                    Button(action: { toggleTag(tag) }) {
                        HStack {
                            Image(systemName: tag.icon)
                                .foregroundStyle(tag.color)
                            Text(tag.name)
                            if selectedTags.contains(where: { $0.id == tag.id }) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button(action: { showCreateTag = true }) {
                    Label("Create Tag...", systemImage: "plus")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                    Text(selectedTags.isEmpty ? "Add Tags" : "Edit Tags")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
        }
        .popover(isPresented: $showCreateTag) {
            CreateTagView(isPresented: $showCreateTag)
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
    
    private func removeTag(_ tag: Tag) {
        selectedTags.removeAll { $0.id == tag.id }
    }
}

// MARK: - Tag Chip Display

struct TagChip: View {
    let tag: Tag
    var isSelected: Bool = false
    var onRemove: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.system(size: 10))
            Text(tag.name)
                .font(.system(size: 11, weight: .medium))
            
            if isSelected, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(tag.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tag.color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(tag.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Create Tag View

struct CreateTagView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var selectedColorHex = "#5AE6FF"
    @State private var selectedIcon = "tag.fill"
    
    private let icons = ["tag.fill", "star.fill", "flag.fill", "bookmark.fill", "heart.fill", "bolt.fill", "flame.fill", "leaf.fill"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Tag")
                .font(.system(size: 16, weight: .bold))
            
            TextField("Tag name", text: $name)
                .textFieldStyle(.plain)
                .padding(10)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Color Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(Tag.presetColors, id: \.hex) { preset in
                        Circle()
                            .fill(Color(hex: preset.hex) ?? .blue)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: selectedColorHex == preset.hex ? 2 : 0)
                            )
                            .onTapGesture { selectedColorHex = preset.hex }
                    }
                }
            }
            
            // Icon Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColorHex) ?? .blue : .secondary)
                            .frame(width: 32, height: 32)
                            .background(selectedIcon == icon ? Color.white.opacity(0.1) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }
            
            HStack {
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                Spacer()
                Button("Create") { createTag() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
    
    private func createTag() {
        let tag = Tag(name: name.trimmingCharacters(in: .whitespaces), colorHex: selectedColorHex, icon: selectedIcon)
        modelContext.insert(tag)
        try? modelContext.save()
        isPresented = false
    }
}

// MARK: - Inline Tag Display (for list rows)

struct TagsRow: View {
    let tags: [Tag]
    
    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 4) {
                ForEach(tags.prefix(3)) { tag in
                    TagChip(tag: tag)
                }
                if tags.count > 3 {
                    Text("+\(tags.count - 3)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }
}
