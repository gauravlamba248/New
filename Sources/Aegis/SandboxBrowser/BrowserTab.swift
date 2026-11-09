import Foundation
import Combine
import SwiftUI

/// Represents a distinct browser tab with an isolated WebKit view model, session state, and lifecycle controls.
@MainActor
public final class BrowserTab: Identifiable, ObservableObject {
    public let id: UUID
    public let viewModel: SecureWebViewModel

    @Published public var title: String = "New Tab"
    @Published public var urlString: String = ""
    @Published public var isLoading: Bool = false
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false

    private var cancellables = Set<AnyCancellable>()

    public init(id: UUID = UUID(), mode: BrowserMode = .normal, initialURL: URL? = nil) {
        self.id = id
        self.viewModel = SecureWebViewModel()
        self.viewModel.browserMode = mode
        self.title = (mode == .normal) ? "New Tab" : "Secure Tab"

        bindViewModel()

        if let url = initialURL {
            self.viewModel.navigate(to: url)
        }
    }

    private func bindViewModel() {
        viewModel.$title
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTitle in
                guard let self = self else { return }
                if self.viewModel.isSessionActive && !newTitle.isEmpty && !newTitle.contains("Empty Browser") {
                    self.title = newTitle
                } else {
                    self.title = (self.viewModel.browserMode == .normal) ? "New Tab" : "Secure Tab"
                }
            }
            .store(in: &cancellables)

        viewModel.$currentURLString
            .receive(on: DispatchQueue.main)
            .assign(to: &$urlString)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        viewModel.$canGoBack
            .receive(on: DispatchQueue.main)
            .assign(to: &$canGoBack)

        viewModel.$canGoForward
            .receive(on: DispatchQueue.main)
            .assign(to: &$canGoForward)
    }

    /// Suspends media and background activity when tab is unfocused to preserve CPU & Energy
    public func hibernate() {
        viewModel.webView?.setAllMediaPlaybackSuspended(true, completionHandler: nil)
        viewModel.webView?.pauseAllMediaPlayback(completionHandler: nil)
    }

    /// Resumes normal playback and rendering when tab becomes active
    public func resume() {
        viewModel.webView?.setAllMediaPlaybackSuspended(false, completionHandler: nil)
    }

    /// Completely closes this tab, freeing memory, halting media, and clearing WebKit state
    public func close() {
        cancellables.removeAll()
        viewModel.closeAndDismantleSession()
    }
}
