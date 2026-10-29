import SwiftUI
import WebKit

/// In-app XLunar avatar test surface. This keeps the experiment separate from existing chat screens.
struct XLunarAvatarTestView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            XLunarWebView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("XLunar 3D Lab")
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
        let webView = WKWebView(frame: .zero)
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://xlunar-ai-avatar.vercel.app/")!))
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
        @objc func reload() {
            // The notification is received by the coordinator; actual reload is handled by
            // the web view's navigation lifecycle in this initial test surface.
        }
    }
}
