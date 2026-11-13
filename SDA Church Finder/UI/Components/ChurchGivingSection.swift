import SwiftUI
import WebKit

struct ChurchGivingSection: View {
    let churchName: String
    let city: String
    let state: String
    let givingURL: URL?
    let adventistGivingOrgID: String?
    var isLoading: Bool = false
    var onLinkAdventistGiving: ((String, URL) -> Void)? = nil

    @State private var selectedWebURL: GivingWebItem?
    @State private var showingManualLinkAlert = false
    @State private var manualOrgIDInput = ""

    private var activeGivingURL: URL {
        givingURL ?? ChurchLiveDetailsService.adventistGivingPortalURL()
    }

    private var isDirectAdventistGiving: Bool {
        adventistGivingOrgID != nil || (givingURL?.host?.lowercased().contains("adventistgiving.org") == true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow(text: "Tithes & offerings")
                Spacer()
                if let orgID = adventistGivingOrgID, !orgID.isEmpty {
                    Text("OrgID · \(orgID)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AdventDesign.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(AdventDesign.orange)
                }
            }

            Text("Online giving")
                .font(.headline)
                .foregroundStyle(AdventDesign.paper)

            if isLoading && givingURL == nil {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Checking church website for AdventistGiving envelope…")
                        .font(.caption)
                        .foregroundStyle(AdventDesign.muted)
                }
                .padding(.vertical, 4)
            } else if isDirectAdventistGiving {
                Text("Return tithes and local church offerings directly to \(churchName) through the official AdventistGiving digital envelope.")
                    .font(.caption)
                    .foregroundStyle(AdventDesign.muted)
                    .lineSpacing(3)
            } else if let givingURL {
                Text("Support \(churchName) through its published online giving page (\(givingURL.host ?? "church portal")).")
                    .font(.caption)
                    .foregroundStyle(AdventDesign.muted)
                    .lineSpacing(3)
            } else {
                Text("Search for \(churchName) on AdventistGiving to open this congregation’s digital envelope. The church name has been copied to your clipboard.")
                    .font(.caption)
                    .foregroundStyle(AdventDesign.muted)
                    .lineSpacing(3)
            }

            Button {
                if !isDirectAdventistGiving {
                    let searchWord = ChurchLiveDetailsService.cleanCongregationName(churchName)
                    UIPasteboard.general.string = searchWord.isEmpty ? churchName : searchWord
                }
                selectedWebURL = GivingWebItem(url: activeGivingURL)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title3)
                        .foregroundStyle(AdventDesign.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDirectAdventistGiving ? "Give via AdventistGiving" : (givingURL != nil ? "Open church giving portal" : "Search on AdventistGiving"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AdventDesign.ink)
                        Text(adventistGivingOrgID != nil ? "Direct congregation envelope · \(churchName)" : (givingURL?.host ?? "Find \(churchName) (name copied to clipboard)"))
                            .font(.caption2)
                            .foregroundStyle(AdventDesign.ink.opacity(0.78))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AdventDesign.ink)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(AdventDesign.orange, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("church.givingButton")

            if !isDirectAdventistGiving {
                Button {
                    showingManualLinkAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link.badge.plus")
                        Text("Already know the OrgID? Link manually")
                    }
                    .font(.caption)
                    .foregroundStyle(AdventDesign.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .adventPanel()
        .sheet(item: $selectedWebURL) { item in
            GivingWebSheet(
                initialURL: item.url,
                churchName: churchName,
                onDiscoveredOrgID: { orgID, url in
                    onLinkAdventistGiving?(orgID, url)
                }
            )
        }
        .alert("Link AdventistGiving", isPresented: $showingManualLinkAlert) {
            TextField("OrgID (e.g. AN4MCL) or URL", text: $manualOrgIDInput)
            Button("Link Church") {
                let trimmed = manualOrgIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
                if let extractedID = ChurchLiveDetailsService.extractAdventistGivingOrgID(from: trimmed) ?? (trimmed.count >= 4 && trimmed.count <= 8 && trimmed.allSatisfy { $0.isLetter || $0.isNumber } ? trimmed.uppercased() : nil),
                   let directURL = ChurchLiveDetailsService.normalizedAdventistGivingURL(forOrgID: extractedID) {
                    onLinkAdventistGiving?(extractedID, directURL)
                }
                manualOrgIDInput = ""
            }
            Button("Cancel", role: .cancel) {
                manualOrgIDInput = ""
            }
        } message: {
            Text("Enter this church’s AdventistGiving OrgID or donation link to connect its digital envelope and conference directly.")
        }
    }
}

private struct GivingWebItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct GivingWebSheet: View {
    let initialURL: URL
    let churchName: String
    var onDiscoveredOrgID: ((String, URL) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var discoveredOrgID: String?
    @State private var discoveredURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let orgID = discoveredOrgID {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Linked to \(churchName) (OrgID: \(orgID))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AdventDesign.paper)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.18))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AdventDesign.orange)
                        Text("Search and tap your church on AdventistGiving to link it to this listing.")
                            .font(.caption)
                            .foregroundStyle(AdventDesign.muted)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AdventDesign.panel)
                }

                GivingWebView(
                    url: initialURL,
                    onURLChange: { newURL in
                        if let orgID = ChurchLiveDetailsService.extractAdventistGivingOrgID(from: newURL.absoluteString) {
                            if discoveredOrgID != orgID {
                                discoveredOrgID = orgID
                                discoveredURL = newURL
                                onDiscoveredOrgID?(orgID, newURL)
                            }
                        }
                    }
                )
            }
            .navigationTitle("AdventistGiving")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .tint(AdventDesign.orange)
        .preferredColorScheme(.dark)
    }
}

struct GivingWebView: UIViewRepresentable {
    let url: URL
    let onURLChange: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onURLChange: onURLChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        let scriptSource = """
        (function() {
            function notify() {
                try {
                    window.webkit.messageHandlers.routeChanged.postMessage(window.location.href);
                } catch(e) {}
            }
            var originalPush = history.pushState;
            history.pushState = function() {
                originalPush.apply(history, arguments);
                notify();
            };
            var originalReplace = history.replaceState;
            history.replaceState = function() {
                originalReplace.apply(history, arguments);
                notify();
            };
            window.addEventListener('hashchange', notify);
            window.addEventListener('popstate', notify);
        })();
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        contentController.add(context.coordinator, name: "routeChanged")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 27_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onURLChange: (URL) -> Void

        init(onURLChange: @escaping (URL) -> Void) {
            self.onURLChange = onURLChange
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    self.onURLChange(url)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let targetURL = navigationAction.request.url {
                onURLChange(targetURL)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let currentURL = webView.url {
                onURLChange(currentURL)
            }
        }
    }
}
