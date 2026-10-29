import SwiftUI
import WebKit

/// In-app XLunar avatar test surface. This keeps the experiment separate from existing chat screens.
struct XLunarAvatarTestView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            XLunarWebView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("ChatAI 3D")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Đóng") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            NotificationCenter.default.post(name: .xlunarReload, object: nil)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Tải lại XLunar")
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

private extension Notification.Name {
    static let xlunarReload = Notification.Name("ChatAI.XLunar.Reload")
}

private struct XLunarWebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Avatar3DBundle") {
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString("3D engine bundle missing. Rebuild with Codemagic.", baseURL: nil)
        }
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.reload),
            name: .xlunarReload,
            object: nil
        )
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator, name: .xlunarReload, object: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?

        @objc func reload() {
            webView?.reload()
        }
    }
}
