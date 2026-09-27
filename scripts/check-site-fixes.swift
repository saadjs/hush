// Run on macOS: swift scripts/check-site-fixes.swift Rules/blockerList.json
// Uses WebKit's real rule engine and live probe endpoints in an isolated session.
import AppKit
import WebKit

final class SiteFixCheck: NSObject, WKNavigationDelegate {
    let identifier = "Hush-site-fix-check-\(UUID().uuidString)"
    let cases: [(host: String, allowed: Bool)] = [
        ("bromabakery.com", true),
        ("preppykitchen.com", true),
        ("www.preppykitchen.com", true),
        ("example.com", false),
        ("notbromabakery.com", false),
    ]
    let view: WKWebView
    var index = 0

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        super.init()
        view.navigationDelegate = self
    }

    func run(rules: String) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier, encodedContentRuleList: rules
        ) { list, error in
            guard let list else {
                self.finish("Rule compilation failed: \(String(describing: error))")
                return
            }
            self.view.configuration.userContentController.add(list)
            self.loadNext()
        }
    }

    func loadNext() {
        guard index < cases.count else { finish(nil); return }
        view.loadHTMLString(
            "<html><body><div class='adthrive-ad'>Ad fixture</div></body></html>",
            baseURL: URL(string: "https://\(cases[index].host)/")
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.callAsyncJavaScript("""
        const urls = [
            'https://ads.adthrive.com/abd/abd.js',
            'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'
        ];
        async function fetchProbe(url) {
            try {
                const r = await fetch(url, {credentials: 'omit', cache: 'no-store'});
                return r.ok && (await r.text()).length > 0;
            } catch { return false; }
        }
        function xhrProbe(url) {
            return new Promise(resolve => {
                const xhr = new XMLHttpRequest();
                xhr.open('GET', url);
                xhr.onload = () => resolve(xhr.status === 200 && xhr.responseText.length > 0);
                xhr.onerror = () => resolve(false);
                xhr.send();
            });
        }
        function scriptProbe(url) {
            return new Promise(resolve => {
                const script = document.createElement('script');
                script.onload = () => resolve(true);
                script.onerror = () => resolve(false);
                script.src = url;
                document.head.append(script);
            });
        }
        return await Promise.race([
            (async () => ({
                fetches: await Promise.all(urls.map(fetchProbe)),
                xhr: await xhrProbe(urls[0]),
                scripts: await Promise.all(urls.map(scriptProbe)),
                otherAdRequest: await fetchProbe(urls[0] + '?hush-test=1'),
                adHidden: getComputedStyle(document.querySelector('.adthrive-ad')).display === 'none'
            }))(),
            new Promise((_, reject) => setTimeout(() => reject(new Error('Probe timeout')), 10000))
        ]);
        """, arguments: [:], in: nil, in: .page, completionHandler: { result in
            let test = self.cases[self.index]
            guard case .success(let value) = result,
                  let checks = value as? [String: Any],
                  checks["fetches"] as? [Bool] == [test.allowed, test.allowed],
                  checks["xhr"] as? Bool == test.allowed,
                  checks["scripts"] as? [Bool] == [false, false],
                  checks["otherAdRequest"] as? Bool == false,
                  checks["adHidden"] as? Bool == true else {
                self.finish("FAIL \(test.host): \(result)")
                return
            }
            print("PASS \(test.host): probe scope, script blocking, other ad requests, cosmetic filtering")
            self.index += 1
            self.loadNext()
        })
    }

    func finish(_ error: String?) {
        if let error { print(error) }
        WKContentRuleListStore.default().removeContentRuleList(forIdentifier: identifier) { _ in
            exit(error == nil ? 0 : 1)
        }
    }
}

guard CommandLine.arguments.count == 2 else {
    print("Usage: swift scripts/check-site-fixes.swift Rules/blockerList.json")
    exit(1)
}
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let check = SiteFixCheck()
check.run(rules: try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8))
DispatchQueue.main.asyncAfter(deadline: .now() + 90) { check.finish("Test timed out") }
app.run()
