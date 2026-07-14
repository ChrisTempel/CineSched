// HoverTooltip.swift
// A faster stand-in for the native `.help()` tooltip. macOS's built-in tooltip delay
// (~1.5s) isn't configurable from SwiftUI, so for the scene cast/summary tooltip — where
// a snappier response actually matters while scanning the Boneyard or calendar — this
// renders its own small bubble after a short, adjustable hover delay instead.

import SwiftUI

private struct HoverTooltip: ViewModifier {
    let text: String
    var delay: TimeInterval = 0.5

    @State private var isHovering  = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovering = hovering
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        if !Task.isCancelled && isHovering {
                            showTooltip = true
                        }
                    }
                } else {
                    showTooltip = false
                }
            }
            .popover(isPresented: $showTooltip, arrowEdge: .trailing) {
                Text(text)
                    .font(.caption)
                    .padding(10)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 260, alignment: .leading)
            }
    }
}

extension View {
    /// A custom hover tooltip (default 0.5s delay) showing `text` in a small popover —
    /// use in place of `.help()` wherever the system's ~1.5s tooltip delay feels too slow.
    /// Renders as a real popover window, so (unlike a plain overlay) it isn't clipped by
    /// an enclosing List or ScrollView.
    func fastTooltip(_ text: String, delay: TimeInterval = 0.5) -> some View {
        modifier(HoverTooltip(text: text, delay: delay))
    }
}
