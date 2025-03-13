import SwiftUI

struct PaperMC: View {
    @Binding var presented: Bool
    @State var searchText = ""
    @State var reload = false
    @StateObject private var viewModel = WebViewModel()

    let folder: URL
    var body: some View {
        VStack {
            HStack {
                TextField("Search Paper Hangar", text: $searchText, onCommit: {
                    viewModel.loadURL("https://hangar.papermc.io/?query=\(searchText)&sort=-stars")
                })
                .textFieldStyle(.plain)
                Button("Open in Safari") {
                    NSWorkspace.shared.open(URL(string: "https://hangar.papermc.io/?query=\(searchText)&sort=-stars")!)
                }
                .onAppear {
                    viewModel.loadURL("https://hangar.papermc.io/?query=&sort=-stars")
                }
                
            }
            .padding(.horizontal)
            .padding(.top)
            
            
            NewWebView(model: viewModel)
                .onChange(of: viewModel.jarFile) { newValue in
                    let url = newValue
                    let pluginsFolder = folder.appendingPathComponent("plugins", conformingTo: .folder)
                    if url.lastPathComponent.contains(".jar") {}
                    let destinationURL = pluginsFolder.appendingPathComponent(url.lastPathComponent.contains(".jar") ? url.lastPathComponent : "\(url.lastPathComponent).jar")
                    print(destinationURL.absoluteString)
                    // Start downloading the file
                    let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
                        if let error = error {
                            DispatchQueue.main.async {
                                print(error.localizedDescription)
                                showError("Download failed: \(error.localizedDescription)")
                            }
                            return
                        }
                        
                        guard let localURL = localURL else {
                            DispatchQueue.main.async {
                                print("No file received")
                                showError("No file received")
                            }
                            return
                        }
                        presented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            do {
                                if !FileManager.default.fileExists(atPath: pluginsFolder.path()) {
                                    try FileManager.default.createDirectory(at: pluginsFolder, withIntermediateDirectories: true)
                                    print("Directory created")
                                }
                                if FileManager.default.fileExists(atPath: destinationURL.path()) {
                                    showError("Plugin already installed")
                                } else {
                                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                                    DispatchQueue.main.async {
                                        showSuccess("Plugin downloaded to: \(destinationURL.path)")
                                    }
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    showError(error.localizedDescription)
                                }
                            }
                        }
                    }
                    
                    task.resume()
                }
            Text("Plugins you download here will be added to the plugins folder of your Server automatically")
                .font(.caption)
                .foregroundStyle(.gray)
                .padding()
        }
        .frame(minWidth: 500, minHeight: 500)
    }
}
import WebKit

class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var webView: WKWebView
    @Published var jarFile: URL = URL(string: "https://google.com")!
    override init() {
        let config = WKWebViewConfiguration()
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        self.webView.navigationDelegate = self
    }
    
    func loadURL(_ urlString: String) {
        if let url = URL(string: urlString), url.scheme != nil {
            webView.load(URLRequest(url: url))
        } else if let url = URL(string: "https://" + urlString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame == nil {
            if checkURLType((navigationAction.request.url ?? URL(string: "https://google.com"))!) == "File" {
                print("URL TYPE FILE")
                jarFile = navigationAction.request.url ?? URL(string: "https://google.com")!
            } else if checkURLType((navigationAction.request.url ?? URL(string: "https://google.com"))!) == "Unknown" {
                print("URL TYPE UNKNOWN")
                jarFile = navigationAction.request.url ?? URL(string: "https://google.com")!
            } else {
                print("URL TYPE WEBSITE")
                webView.load(navigationAction.request)
            }
        }
        decisionHandler(.allow)
    }
}

struct NewWebView: NSViewRepresentable {
    @ObservedObject var model: WebViewModel
    
    func makeNSView(context: Context) -> WKWebView {
        return model.webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {}
}

func showSuccess(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Success"
    alert.informativeText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func checkURLType(_ url: URL) -> String {
    var result = "Unknown" // Default result
    DispatchQueue.main.async {
        do {
            let stringToCheck = try String(contentsOf: url)
            if stringToCheck.contains("<html>") || stringToCheck.contains("<body>") || stringToCheck.contains("<head>") {
                result = "Website"
            } else {
                result = "File"
            }
        } catch {
            result = "Unknown"
        }
    }
    return result
}
