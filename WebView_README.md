# WebView

## General

A SwiftUI component built with a UIKit WKWebView. The WebView takes an initial URL, and optionally a WKNavigationDelegate and an optional WebScriptMessageHandler.

The WKNavigationDelegate gives the program access to the webviews decidePolicyFor, didFinish and didFail event handlers. With no delegate one default is provided, that logs when the event handlers are called

The WebScriptMessageHandler is a superset of WKScriptMessageHandler. If supplied, it feeds the webview with injected event handlers on specified URLs.

## Use

### SwiftUI code:

> WebView(url: url)

or

> WebView(url: url, delegate: vm)

or

> WebView(url: url, delegate: vm, scriptHandler: vm)



### Setup script handler _(optional)_

#### Adopting WebScriptMessageHandler

You have to supply 3 functions:

- userContentController
- webEventHandler
- webViewScripts

**userContentController** just routes calls to webEventHandler. You could handle events right here, but for naming and context it's better to route.

> **func** userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
>
> ​    **return** webEventHandler(userContentController, didReceive: message)
>
>   }

**webViewScripts** is the function that provides the javascripts that should be injected on which web page. It's like the configuration for web scripts.

The function returns an array of WebViewScripts. You can construct a WebViewScript like:

> WebViewScript(urlMatchString: "https://www.sample.com/page", handlers: [
>
> WebEventHandler(handlerName: "pageHandler", script: "document.querySelector('#button-id').addEventListener('click', function() { window.webkit.messageHandlers.pageHandler.postMessage('test-action'); });")
>
> ])

urlMatchString is a string that is matched with the current URL. If the current URL starts with the urlMatchingString the connected scripts are injected on that page.

WebEventHandler.handlerName is the key to the handler, and has to be in the script as well. In the example the handler is called _pageHandler_, so in the script it must post Messages on: window.webkit.messageHandlers._pageHandler_. 

In the script you can post messages with any string, and the handlerName and postMessage then ends up in the eventMessage in the _webEventHandler_ when the event occurs.

**webEventHandler** recieves a WKScriptMessage called eventMessage. 

You can switch actions on the eventMessage.name, that you provided, in WebViewScripts. It can be any arbitrary string and can be seen as a group for handlers. Like a name grouping all events on a web page.

You can then switch the page action depending on the eventMessage.body. It's the web page's specific event, like a click-action. 

> **func** webEventHandler(_ userContentController: WKUserContentController, didReceive eventMessage: WKScriptMessage) {
>
> ​    **if** eventMessage.name == "pageHandler", **let** eventAction = eventMessage.body **as**? String {
>
> ​      **if** eventAction == "test-action" {
>
> ​        print("Take action")
>
> ​      }
>
> ​    }
>
>   }



### Rigging it up

To be able to handle scripts you also have to set up a WKNavigationDelegate in the WebView-constructor.

In the WKNavigationDelegates webView.didFinish function you simply include:

> **func** webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
>
> ​    **if** **let** url = webView.url {
>
> ​      webView.injectScript(match: url.absoluteString, scripts: WebScriptMessageHandler.webViewScripts())
>
> ​    }
>
>   }



## Take it out for a spin!

