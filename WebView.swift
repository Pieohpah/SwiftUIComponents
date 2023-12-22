//
//  WebView.swift
//  PreemB2C
//
//  Created by Peter Herber on 2023-06-13.
//

import SwiftUI
import WebKit

class WebViewDelegate: NSObject {
    let logger = LogManager.shared.logger(WebViewDelegate.self)
}

struct WebView: UIViewRepresentable {
    let url: URL
    var delegate: WKNavigationDelegate = WebViewDelegate()
    var scriptHandler: WebScriptMessageHandler?

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfiguration = WKWebViewConfiguration()
        if let scripts = self.scriptHandler {
            for script in scripts.webViewScripts() {
                for sh in script.handlers {
                    let userContentController = WKUserContentController()
                    userContentController.add(scripts, name:  sh.handlerName)
                    webViewConfiguration.userContentController = userContentController
                }
            }
        }

        let wv = WKWebView(frame: UIScreen.main.bounds, configuration: webViewConfiguration)
        wv.navigationDelegate = delegate
        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

extension WebViewDelegate: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        logger.debug("Policy \(navigationAction.request.url?.absoluteString ?? "-")")
        return decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.debug("DidFinish \(navigation.debugDescription)")
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("Error \(error) - \(navigation.debugDescription)")
    }
}


protocol WebScriptMessageHandler: WKScriptMessageHandler {
    func webViewScripts() -> [WebViewScript]
    func webEventHandler(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
}

struct WebEventHandler {
    var handlerName: String
    var script: String
}

struct WebViewScript {
    var urlMatchString: String
    var handlers: [WebEventHandler]
}

extension WKWebView {
    func injectScript(match: String, scripts: [WebViewScript]) {
        let matches = scripts.filter({ s in
            match.starts(with:s.urlMatchString)
        })
        if matches.count > 0 {
            for match in matches {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self = self else {return}
                    for handler in match.handlers {
                        self.evaluateJavaScript(handler.script) { data, error in
                            LogManager.shared.trace("Injected Javascript: script returned \(data.debugDescription) - Error: \(error?.localizedDescription ?? "-")")
                        }
                    }
                }
            }
        }
    }
}
