// SelectAllTextField.swift
// A macOS text field that selects all of its existing text whenever it becomes
// first responder — either because the user clicked into it, or because the app
// requested focus programmatically. This lets a user type over a pre-filled
// value (e.g. Duration on an imported scene) immediately, without first having
// to select or delete the existing text.
//
// Plain SwiftUI TextField has no hook for this on macOS, so this wraps a real
// NSTextField via NSViewRepresentable.

import SwiftUI
import AppKit

struct SelectAllTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String

    /// Parent flips this to `true` to request focus (and select-all).
    /// The view resets it back to `false` once handled.
    @Binding var focusTrigger: Bool

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if focusTrigger {
            // Deferred to the next runloop turn: right after a sheet is presented
            // (or right after we swap to a new scene) the window isn't always
            // ready to accept a new first responder in the same frame.
            DispatchQueue.main.async {
                if let window = nsView.window {
                    window.makeFirstResponder(nsView)
                }
                focusTrigger = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SelectAllTextField

        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        /// Fires whenever the field becomes first responder for editing —
        /// whether from a user click or from `window.makeFirstResponder(_:)`
        /// called above — so select-all happens consistently either way.
        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField,
                  let editor = field.currentEditor() else { return }
            editor.selectAll(nil)
        }
    }
}
