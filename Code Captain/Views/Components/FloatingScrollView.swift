//
//  FloatingScrollView.swift
//  Code Captain
//
//  Created by Christo Todorov on 19.07.25.
//

import AppKit
import SwiftUI

enum FloatingScrollBackground {
    case sidebar
    case color(NSColor)
}

struct FloatingScrollView<Content: View>: NSViewRepresentable {
    let content: () -> Content
    let background: FloatingScrollBackground

    init(
        background: FloatingScrollBackground = .sidebar,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.background = background
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
        let containerView: NSView

        switch background {
        case .sidebar:
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .sidebar
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.backgroundColor = NSColor.clear.cgColor

            context.coordinator.visualEffectView = visualEffectView
            containerView = visualEffectView

        case .color(let color):
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .sidebar  // must be sidebar to suppress scroll track
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.backgroundColor = .clear

            // Add custom background color layer
            let backgroundLayer = CALayer()
            backgroundLayer.backgroundColor = color.cgColor
            backgroundLayer.frame = visualEffectView.bounds
            backgroundLayer.autoresizingMask = [
                .layerWidthSizable, .layerHeightSizable,
            ]
            visualEffectView.layer?.addSublayer(backgroundLayer)

            containerView = visualEffectView
        }

        let hostingView = NSHostingView(rootView: content())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor
            ),
            hostingView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor
            ),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor
            ),
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard
            let hostingView = nsView.subviews.compactMap({
                $0 as? NSHostingView<Content>
            }).first
        else {
            return
        }

        hostingView.rootView = content()
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        if let scrollView = findScrollView(in: hostingView) {
            scrollView.scrollerStyle = .overlay
            scrollView.drawsBackground = false
            scrollView.backgroundColor = .clear
        }

        if case .sidebar = background,
            let visualEffectView = nsView as? NSVisualEffectView
        {
            visualEffectView.state =
                nsView.window?.isKeyWindow == true ? .active : .inactive
        }
    }

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
