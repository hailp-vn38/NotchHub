import AppKit
import SwiftUI

public enum DetailNavigationRequest: Equatable, Sendable {
    case placeholder
}

public enum DetailNavigationOutcome: Equatable, Sendable {
    case opened
    case focused
}

@MainActor
public protocol DetailNavigating: AnyObject {
    @discardableResult
    func open(_ request: DetailNavigationRequest) -> DetailNavigationOutcome
}

@MainActor
public protocol DetailWindowPresenting: AnyObject {
    func present(_ request: DetailNavigationRequest)
    func focus()
    func close()
    func setCloseHandler(_ handler: @escaping @MainActor () -> Void)
}

/// Owns the lifecycle of the separately requested long-form Detail view.
@MainActor
public final class DetailWindowCoordinator: DetailNavigating {
    private let window: any DetailWindowPresenting
    private var openRequest: DetailNavigationRequest?

    public init(window: (any DetailWindowPresenting)? = nil) {
        self.window = window ?? MacOSDetailWindowPresenter()
        self.window.setCloseHandler { [weak self] in
            self?.openRequest = nil
        }
    }

    @discardableResult
    public func open(_ request: DetailNavigationRequest) -> DetailNavigationOutcome {
        let outcome: DetailNavigationOutcome = openRequest == request ? .focused : .opened
        if outcome == .opened {
            window.present(request)
            openRequest = request
        }
        window.focus()
        return outcome
    }

    @discardableResult
    public func close() -> DetailWindowCloseOutcome {
        guard openRequest != nil else { return .alreadyClosed }
        window.close()
        openRequest = nil
        return .closed
    }
}

public enum DetailWindowCloseOutcome: Equatable, Sendable {
    case closed
    case alreadyClosed
}

@MainActor
public protocol DetailNavigationInput: AnyObject {
    func setDetailNavigationHandler(_ handler: @escaping @MainActor (DetailNavigationRequest) -> Void)
}

@MainActor
private final class MacOSDetailWindowPresenter: NSObject, DetailWindowPresenting, NSWindowDelegate {
    private var window: NSWindow?
    private var closeHandler: (@MainActor () -> Void)?

    func present(_ request: DetailNavigationRequest) {
        let window = window ?? makeWindow()
        window.contentView = NSHostingView(
            rootView: DetailWindowRootView(close: { [weak self] in
                self?.window?.performClose(nil)
            }))
        window.title = title(for: request)
        self.window = window
    }

    func focus() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.performClose(nil)
    }

    func setCloseHandler(_ handler: @escaping @MainActor () -> Void) {
        closeHandler = handler
    }

    func windowWillClose(_: Notification) {
        closeHandler?()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        return window
    }

    private func title(for request: DetailNavigationRequest) -> String {
        switch request {
        case .placeholder: "NotchHub Detail"
        }
    }
}

private struct DetailWindowRootView: View {
    let close: () -> Void

    var body: some View {
        ContentUnavailableView(
            "Detail placeholder",
            systemImage: "text.page",
            description: Text("Long-form content belongs in this separate Detail view.")
        )
        .frame(minWidth: 440, minHeight: 280)
        .toolbar {
            Button("Back", action: close)
        }
        .onExitCommand(perform: close)
    }
}
