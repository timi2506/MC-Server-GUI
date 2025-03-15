import Foundation

struct ServerInstance: Hashable {
    var name: String
    var folder: URL
    var jar: URL
    var log: String = ""
    var process: Process = Process()
    var pipe: Pipe = Pipe()
    var inputPipe: Pipe = Pipe()
    var minRAM: CGFloat
    var maxRAM: CGFloat
    var GUI: Bool?
    var properties: [String: String] = [
        "server-port" : "",
        "online-mode" : "true",
        "motd" : "A Minecraft Server"
    ]
    var propertyFiles: [PropertyFile] = []
    
    mutating func sendCommand(_ command: String) {
        if process.isRunning {
            let data = (command + "\n").data(using: .utf8)
            inputPipe.fileHandleForWriting.write(data!)
        }
    }
}

struct SaveableServerInstance: Hashable, Codable {
    var name: String
    var folder: URL
    var jar: URL
    var log: String = ""
    var minRAM: CGFloat
    var maxRAM: CGFloat
    var GUI: Bool?
    var propertyFiles: [PropertyFile]
}

struct PropertyFile: Hashable, Codable, Identifiable {
    let id = UUID().uuidString
    var name: String
    var fileURL: URL
}
