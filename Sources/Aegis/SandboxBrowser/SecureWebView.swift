import SwiftUI
import WebKit

public struct SecureWebView: NSViewRepresentable {
    @ObservedObject public var viewModel: SecureWebViewModel

    public init(viewModel: SecureWebViewModel) {
        self.viewModel = viewModel
    }

    public func makeNSView(context: Context) -> WKWebView {
        return viewModel.getOrCreateWebView()
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        // Driven dynamically via viewModel
    }
}
