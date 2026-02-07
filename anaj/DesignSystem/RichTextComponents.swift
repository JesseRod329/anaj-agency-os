//
//  RichTextComponents.swift
//  ANAJ
//
//  Shared components for the Rich Text Editor
//

import SwiftUI

struct EditorToolbarButton: View {
    let icon: String?
    let label: String?
    let tooltip: String
    let isActive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                } else if let label = label {
                    Text(label)
                        .font(AppFonts.body(14).weight(.bold))
                        .if(label == "I") { $0.italic() }
                }
            }
            .foregroundStyle(isActive || isHovered ? AppColors.textPrimary : AppColors.textSecondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(isActive ? AppColors.accentBlue.opacity(0.3) : (isHovered ? AppColors.surfaceHighlight : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}

struct EditorColorPicker: View {
    @Binding var selectedColor: Color
    let onSelect: (Color) -> Void
    
    @State private var showCustomPicker = false
    
    // Preset colors aligned with design system where possible, plus standard editor colors
    let presetColors: [Color] = [
        .white, 
        .gray,
        .red, 
        .orange, 
        .yellow, 
        .green, 
        .mint,
        .cyan, 
        .blue, 
        .indigo,
        .purple, 
        .pink,
        .brown
    ]
    
    var body: some View {
        Menu {
            ForEach(presetColors, id: \.self) { color in
                Button {
                    selectedColor = color
                    onSelect(color)
                } label: {
                    HStack {
                        if color == selectedColor {
                            Image(systemName: "checkmark")
                        }
                        Circle().fill(color).frame(width: 12, height: 12)
                        Text(colorName(color))
                    }
                }
            }
            Divider()
            Button("Custom Color...") {
                showCustomPicker = true
            }
        } label: {
            HStack(spacing: 4) {
                Text("A")
                    .font(AppFonts.body(14).weight(.bold))
                    .foregroundStyle(selectedColor)
                    .overlay(
                        Rectangle()
                            .fill(selectedColor)
                            .frame(height: 2)
                            .offset(y: 8)
                    )
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .popover(isPresented: $showCustomPicker) {
            VStack {
                ColorPicker("Text Color", selection: $selectedColor)
                    .padding()
                Button("Apply") {
                    onSelect(selectedColor)
                    showCustomPicker = false
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
            .frame(width: 200)
        }
    }
    
    private func colorName(_ color: Color) -> String {
        switch color {
        case .white: return "White"
        case .gray: return "Gray"
        case .black: return "Black"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .mint: return "Mint"
        case .cyan: return "Cyan"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .brown: return "Brown"
        default: return "Custom"
        }
    }
}
