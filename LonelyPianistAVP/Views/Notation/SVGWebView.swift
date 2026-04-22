import SwiftUI
import WebKit

struct SVGWebView: UIViewRepresentable {
    let svg: String

    func makeUIView(context _: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        let html = """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
            <style>
              body { margin: 0; background: white; }
              svg { width: 100%; height: auto; display: block; }
            </style>
          </head>
          <body>
            \(svg)
          </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

