// HoverTooltip.swift
// A faster stand-in for the native `.help()` tooltip. macOS's built-in tooltip delay
// (~1.5s) isn't configurable from SwiftUI, so for the scene cast/summary tooltip — where
// a snappier response actually matters while scanning the Boneyard or calendar — this
// renders its own small bubble after a short, adjustable hover delay instead.
//
// Deliberately NOT implemented with `.popover`: a popover is a real NSPopover child
// window, and macOS treats the click that dismisses an open popover specially — it
// doesn't pass through to the anchor view as a normal click, which was silently
// swallowing the first click-and-drag attempt on a Boneyard row any time the tooltip
// had popped up first.
//
// Also deliberately NOT a plain per-row `.overlay(...)`: both the Boneyard (a tightly
// packed vertical list) and the calendar (a LazyVGrid of day columns) can end up
// showing the tooltip overlapping a neighboring row or an adjacent day column, and
// Apple explicitly does not guarantee paint order for overlapping content in lazy
// containers — so a per-row overlay can end up rendering *behind* that neighbor,
// producing unreadable interleaved text. Instead, every `.fastTooltip(...)` reports
// its hover state and on-screen position upward via a preference, and a single
// `.tooltipContainer()` — attached once per scrollable area, outside the lazy
// content entirely — renders the one active tooltip as a single top-level overlay.
// That overlay can never be "behind" anything, in any direction, regardless of how
// its content is laid out underneath.

import SwiftUI

// MARK: - Shared preference plumbing

private struct TooltipInfo {
    let text: String
    let anchor: Anchor<CGRect>
}

private struct TooltipPreferenceKey: PreferenceKey {
    static var defaultValue: TooltipInfo? = nil
    static func reduce(value: inout TooltipInfo?, nextValue: () -> TooltipInfo?) {
        // At most one row is ever hovered at a time; whichever reports non-nil wins.
        if let next = nextValue() { value = next }
    }
}

private struct TooltipSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 180, height: 40)
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

// MARK: - Per-row modifier

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
            .anchorPreference(key: TooltipPreferenceKey.self, value: .bounds) { anchor in
                showTooltip ? TooltipInfo(text: text, anchor: anchor) : nil
            }
    }
}

// MARK: - Bubble

private struct TooltipBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 260, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TooltipSizeKey.self, value: geo.size)
                }
            )
    }
}

// MARK: - Container-level overlay

private struct TooltipHost: View {
    let info: TooltipInfo
    let containerSize: CGSize

    @State private var size: CGSize = TooltipSizeKey.defaultValue

    var body: some View {
        GeometryReader { proxy in
            let rect = proxy[info.anchor]
            let halfW = size.width / 2
            let x = min(max(rect.midX, halfW + 8), max(containerSize.width - halfW - 8, halfW + 8))
            let y = max(rect.minY - size.height / 2 - 10, size.height / 2 + 8)

            TooltipBubble(text: info.text)
                .onPreferenceChange(TooltipSizeKey.self) { size = $0 }
                .position(x: x, y: y)
        }
        .allowsHitTesting(false)   // never intercepts clicks, so it can never block a drag
        .transition(.opacity)
    }
}

extension View {
    /// A custom hover tooltip (default 0.5s delay) showing `text` in a small bubble —
    /// use in place of `.help()` wherever the system's ~1.5s tooltip delay feels too slow.
    /// Must be inside a view that has `.tooltipContainer()` applied somewhere above it.
    func fastTooltip(_ text: String, delay: TimeInterval = 0.5) -> some View {
        modifier(HoverTooltip(text: text, delay: delay))
    }

    /// Attach once per independent scrollable area (the Boneyard list, the calendar)
    /// so every `.fastTooltip` inside it renders through one shared, top-level overlay
    /// instead of a fragile per-row overlay. See the file header for why this matters.
    func tooltipContainer() -> some View {
        self.overlayPreferenceValue(TooltipPreferenceKey.self) { info in
            GeometryReader { proxy in
                if let info {
                    TooltipHost(info: info, containerSize: proxy.size)
                }
            }
        }
    }
}
