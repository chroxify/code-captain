//
//  FloatingSidebarScroll.swift
//  Code Captain
//
//  Created by Christo Todorov on 19.07.25.
//

import AppKit
import SwiftUI

struct FloatingSidebarScroll<Content: View>: NSViewRepresentable {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    class Coordinator {
        var visualEffectView: NSVisualEffectView?

        init(visualEffectView: NSVisualEffectView?) {
            self.visualEffectView = visualEffectView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidBecomeKey),
                name: NSWindow.didBecomeKeyNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResignKey),
                name: NSWindow.didResignKeyNotification,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func windowDidBecomeKey(_ notification: Notification) {
            visualEffectView?.state = .active
        }

        @objc func windowDidResignKey(_ notification: Notification) {
            visualEffectView?.state = .inactive
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(visualEffectView: nil)
    }

    func makeNSView(context: Context) -> NSView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.backgroundColor = NSColor.clear.cgColor

        context.coordinator.visualEffectView = visualEffectView

        // Hosting the List (or any Content) directly here
        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        visualEffectView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(
                equalTo: visualEffectView.leadingAnchor
            ),
            hostingView.trailingAnchor.constraint(
                equalTo: visualEffectView.trailingAnchor
            ),
            hostingView.topAnchor.constraint(
                equalTo: visualEffectView.topAnchor
            ),
            hostingView.bottomAnchor.constraint(
                equalTo: visualEffectView.bottomAnchor
            ),
        ])

        return visualEffectView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let visualEffectView = nsView as? NSVisualEffectView else {
            return
        }

        // Find the NSHostingView child
        guard
            let hostingView = visualEffectView.subviews.compactMap({
                $0 as? NSHostingView<Content>
            }).first
        else {
            return
        }

        hostingView.rootView = content()
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        // Now find the internal NSScrollView inside hostingView's subviews (SwiftUI List embeds one)
        if let scrollView = findScrollView(in: hostingView) {
            scrollView.scrollerStyle = .overlay
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
        }

        if let window = nsView.window, window.isKeyWindow {
            visualEffectView.state = .active
        } else {
            visualEffectView.state = .inactive
        }
    }

    // Helper to recursively find NSScrollView inside a view hierarchy
    private func findScrollView(in view: NSView) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        for subview in view.subviews {
            if let found = findScrollView(in: subview) {
                return found
            }
        }
        return nil
    }
}
