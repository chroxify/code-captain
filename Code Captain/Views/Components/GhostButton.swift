//
//  GhostButton.swift
//  Code Captain
//
//  Created by Christo Todorov on 20.07.25.
//

import SwiftUI

struct GhostButton<Content: View>: View {
    let action: () -> Void
    let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            content()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.08))
                        .opacity(isHovered ? 1 : 0)
                )
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
