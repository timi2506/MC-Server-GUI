import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State var instances: [ServerInstance] = []
    @State var saveInstances: [SaveableServerInstance] = []
    @AppStorage("InstanceData") var instanceData: Data = Data()
    @State var newCommand = ""
    @State var port = ""
    let totalRAM: CGFloat = CGFloat(ProcessInfo.processInfo.physicalMemory / 1_048_576) // Convert bytes to MB
    @State var onlineMode = "true"
    @State var exportLog = false
    @State var showProcessInfo = false
    @State var showModsView = false
    @State var logFileName = ""
    @State var newMotd = "A Minecraft Sercer"
    @State var importInstance = false
    @State var dropIsTargeted = false
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Manage Instances") {
                    List {
                        if instances.count == 0 {
                            Text("No Instances yet").foregroundStyle(.gray)
                        } else {
                            Section("Swipe to Delete") {
                                ForEach(instances, id: \.self) { instance in
                                    Text(instance.name)
                                }
                                .onDelete(perform: deleteInstance)
                            }
                        }
                    }
                    .listStyle(DefaultListStyle())
                }
                if instances.count == 0 {
                    Text("No Instances yet").foregroundStyle(.gray)
                } else {
                    Section("Instances") {
                        ForEach(instances.indices, id: \.self) { index in
                            if instances.indices.contains(index) {
                                NavigationLink(instances[index].name) {
                                    VStack {
                                        HStack {
                                            Text("Log").bold()
                                            Spacer()
                                            Group {
                                                Button("Export Log") {
                                                    exportLog = true
                                                }
                                                .fileImporter(isPresented: $exportLog, allowedContentTypes: [.folder], onCompletion: { folder in
                                                    do {
                                                        showAlertWithTextField("Enter a Filename for the Log File (for example: ", completion: { string in
                                                            if let string {
                                                                let fileName = string
                                                                logFileName = fileName
                                                            } else {
                                                                let fileName = "log.txt"
                                                                logFileName = fileName
                                                            }
                                                            
                                                        })
                                                        let url = try folder.get()
                                                        try instances[index].log.write(to: url.appendingPathComponent(logFileName, conformingTo: .data), atomically: true, encoding: .utf8)
                                                        logFileName = ""
                                                        
                                                    } catch {
                                                        logFileName = ""
                                                        showError(error.localizedDescription)
                                                    }
                                                })
                                                Button("Copy Log") {
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(instances[index].log, forType: .string)
                                                }
                                                Button("Clear Log") {
                                                    instances[index].log = ""
                                                }
                                            } .disabled(instances[index].log.isEmpty)
                                        }
                                        .padding(.horizontal)
                                        .padding(.top)
                                        ScrollViewReader { proxy in
                                            ScrollView(.vertical) {
                                                VStack(spacing: 0) {
                                                    Group {
                                                        if instances[index].log.isEmpty {
                                                            Text("No Log yet - Start the instance to collect Logs")
                                                        } else {
                                                            Text(instances[index].log)
                                                        }
                                                    }
                                                    .monospaced()
                                                    .multilineTextAlignment(.leading)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .onChange(of: instances[index].log) { newText in
                                                        let colorizedText = parseANSIColorCodes(newText)
                                                        instances[index].log = colorizedText.string
                                                        proxy.scrollTo("bottom", anchor: .bottom)
                                                    }
                                                    .padding(.bottom, -30)
                                                    Text("emptyness").foregroundStyle(.clear).font(.caption).padding(-50).id("bottom")
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                        TextField("Command", text: $newCommand, onCommit: {
                                            instances[index].sendCommand(newCommand)
                                            newCommand = ""
                                        })
                                        .disabled(!instances[index].process.isRunning)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding()
                                        ScrollView(.vertical) {
                                            HStack {
                                                Text("Options").bold()
                                                Spacer()
                                            }
                                            Group {
                                                HStack {
                                                    Stepper("Minimum RAM (in MB)", value: $instances[index].minRAM, in: 200...totalRAM, step: 100)
                                                    Slider(
                                                        value: $instances[index].minRAM,
                                                        in: 200...totalRAM,
                                                        step: 500
                                                        
                                                    )
                                                    Text(Int(instances[index].minRAM).description).frame(width: 50)
                                                }
                                                .onChange(of: instances[index].minRAM) { newMinRam in
                                                    if newMinRam >= instances[index].maxRAM {
                                                        instances[index].maxRAM = newMinRam + 100
                                                    }
                                                }
                                                
                                                HStack {
                                                    Stepper("Maximum RAM (in MB)", value: $instances[index].maxRAM, in: 200...totalRAM, step: 100)
                                                    Slider(
                                                        value: $instances[index].maxRAM,
                                                        in: 200...totalRAM,
                                                        step: 500
                                                        
                                                    )
                                                    Text(Int(instances[index].maxRAM).description).frame(width: 50)
                                                }
                                                .onChange(of: instances[index].maxRAM) { newMaxRam in
                                                    if newMaxRam <= instances[index].minRAM {
                                                        instances[index].minRAM = instances[index].maxRAM - 100
                                                    }
                                                }
                                                HStack {
                                                    Text("Server Performance GUI")
                                                    if instances[index].GUI == nil {
                                                        Circle()
                                                            .foregroundStyle(.red)
                                                            .frame(width: 10, height: 10)
                                                    } else {
                                                        Circle()
                                                            .foregroundStyle(instances[index].GUI ?? false ? .green : .red)
                                                            .frame(width: 10, height: 10)
                                                    }
                                                    Spacer()
                                                    Button("Toggle") {
                                                        if instances[index].GUI ?? false {
                                                            instances[index].GUI!.toggle()
                                                        } else {
                                                            instances[index].GUI = true
                                                        }
                                                    }
                                                }
                                                HStack {
                                                    Text("Server Port")
                                                    TextField("Server Port", text: $port, onCommit: {
                                                        instances[index].properties["server-port"] = port
                                                        saveServerProperties(instances[index].properties, to: instances[index].folder.appendingPathComponent("server.properties"))
                                                    })
                                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    Button("Default") {
                                                        instances[index].properties["server-port"] = "25565"
                                                        port = "25565"
                                                        saveServerProperties(instances[index].properties, to: instances[index].folder.appendingPathComponent("server.properties"))
                                                        
                                                    }
                                                }
                                                .onChange(of: instances[index].properties["server-port"]) { newValue in
                                                    port = newValue ?? ""
                                                }
                                                .onAppear {
                                                    port = instances[index].properties["server-port"] ?? ""
                                                }
                                                HStack {
                                                    Text("Message of the Day")
                                                    TextField("Message", text: $newMotd, onCommit: {
                                                        instances[index].properties["motd"] = newMotd
                                                        saveServerProperties(instances[index].properties, to: instances[index].folder.appendingPathComponent("server.properties"))
                                                    })
                                                }
                                                .onChange(of: instances[index].properties["motd"]) { newValue in
                                                    newMotd = newValue ?? "A Minecraft Server"
                                                }
                                                .onAppear {
                                                    newMotd = instances[index].properties["motd"] ?? "A Minecraft Server"
                                                }
                                                VStack(alignment: .leading) {
                                                    HStack {
                                                        Text("Online Mode")
                                                        Circle()
                                                            .foregroundStyle(onlineMode == "true" ? .green : .red)
                                                            .frame(width: 10, height: 10)
                                                        Spacer()
                                                        Button("Toggle") {
                                                            if instances[index].properties["online-mode"] == "true" {
                                                                instances[index].properties["online-mode"] = "false"
                                                            } else {
                                                                instances[index].properties["online-mode"] = "true"
                                                            }
                                                            saveServerProperties(instances[index].properties, to: instances[index].folder.appendingPathComponent("server.properties"))
                                                        }
                                                        
                                                    }
                                                    Text("If this is disabled, cracked Clients will be able to join your Server\nit Is HIGHLY recommended to get a plugin like [LoginSecurity](https://www.spigotmc.org/resources/loginsecurity.19362/) to avoid players being able to join as another Player when using Offline Mode")
                                                        .font(.caption)
                                                        .foregroundStyle(.gray)
                                                }
                                                .onChange(of: instances[index].properties["online-mode"]) { newValue in
                                                    onlineMode = newValue ?? "true"
                                                }
                                                .onAppear {
                                                    onlineMode = instances[index].properties["online-mode"] ?? "true"
                                                }
                                                
                                                
                                            }
                                            .disabled(instances[index].process.isRunning)
                                            VStack {
                                                HStack {
                                                    Text("Plugins")
                                                    Spacer()
                                                    Button("Download Plugins from Hangar") {
                                                        showModsView = true
                                                    }
                                                }
                                                HStack {
                                                    Image(systemName: "arrow.down.app.dashed")
                                                    Text("Drop plugin .jar here")
                                                }
                                                .foregroundStyle(dropIsTargeted ? .green : .gray)
                                                    
                                            }
                                            .padding()
                                            .background {
                                                RoundedRectangle(cornerRadius: 15)
                                                    .foregroundStyle(.gray.opacity(dropIsTargeted ? 0.25 : 0.10))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 15)
                                                            .stroke(.gray.opacity(0.5), lineWidth: 0.25)
                                                    )
                                            }
                                            .onDrop(of: [UTType.fileURL], isTargeted: $dropIsTargeted) { providers in
                                                handleDrop(providers, folder: instances[index].folder)
                                            }
                                            .popover(isPresented: $showModsView) {
                                                PaperMC(presented: $showModsView, folder: instances[index].folder)
                                                
                                            }
                                            
                                        }
                                        .scrollIndicators(.never)
                                    }
                                    .onAppear {
                                        instances[index].properties = readServerProperties(instances[index].folder.appendingPathComponent("server.properties", conformingTo: .data))
                                        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                                            if instances.indices.contains(index) {
                                                if instances[index].process.isRunning {
                                                    print("Still running")
                                                } else {
                                                    print("Not running!")
                                                    let log = instances[index].log
                                                    instances[index].log = ""
                                                    instances[index].log = log
                                                }
                                            }
                                        }
                                    }
                                    .navigationTitle(instances[index].name)
                                    .toolbar {
                                        ToolbarItem(placement: .primaryAction) {
                                            Button("Show in Finder", systemImage: "folder.fill") {
                                                NSWorkspace.shared.open(instances[index].folder)
                                            }
                                        }
                                        ToolbarItem(placement: .primaryAction) {
                                            Button("Stop", systemImage: "stop.fill") {
                                                stopJavaProcess(jarProcess: $instances[index].process, log: $instances[index].log, index: index)
                                            }
                                            .disabled(!instances[index].process.isRunning)
                                        }
                                        ToolbarItem(placement: .primaryAction) {
                                            Button("Run", systemImage: "play.fill") {
                                                instances[index].log = ""
                                                runJavaProcess(jar: instances[index].jar, folder: instances[index].folder, log: $instances[index].log, jarProcess: $instances[index].process, pipeVar: $instances[index].pipe, inputPipeVar: $instances[index].inputPipe, minRAM: instances[index].minRAM, maxRAM: instances[index].maxRAM, GUI: instances[index].GUI ?? false)
                                            }
                                            .disabled(instances[index].process.isRunning)
                                        }
                                        ToolbarItem(placement: .status) {
                                            HStack {
                                                Circle()
                                                    .foregroundStyle(instances[index].process.isRunning ? .green : .red)
                                                    .frame(width: 10, height: 10)
                                                Text(instances[index].process.isRunning ? "Running" : "Not running")
                                                    .foregroundStyle(.gray)
                                                    .onChange(of: instances[index].process.isRunning) { newValue in
                                                        if newValue {
                                                            sendNotification(title: "Server started.", body: "The Server Process \"\(instances[index].name)\" has started.", id: instances[index].name)
                                                        } else {
                                                            sendNotification(title: "Server stopped.", body: "The Server Process \"\(instances[index].name)\" has stopped.", id: instances[index].name)
                                                        }
                                                    }
                                            } .onTapGesture {
                                                if instances[index].process.isRunning {
                                                    showProcessInfo = true
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .popover(isPresented: $showProcessInfo) {
                                        List {
                                            Section("Process Info") {
                                                Group {
                                                    Text("Process Identifier: \(instances[index].process.processIdentifier.description)")
                                                        .monospaced()
                                                        .onChange(of: instances[index].process.isRunning) { newValue in
                                                            if !newValue {
                                                                showProcessInfo = false
                                                            }
                                                        }
                                                }
                                            }
                                            
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                Button("Add Server", systemImage: "plus") {
                    addInstance = true
                }
                Button("Import Server", systemImage: "square.and.arrow.down") {
                    importInstance = true
                }
            }
            .onChange(of: instances) { _ in
                saveTheInstances()
            }
            .onAppear {
                loadInstances()
            }
            
            if instances.count == 0 {
                Text("Add an Instance first using the 􀅼 Button in the Top Right")
                    .font(.title)
            } else {
                Text("Select an Instance in the Sidebar on the Left")
                    .font(.title)
            }
            
        }
        .popover(isPresented: $addInstance) {
            popover
        }
        .popover(isPresented: $importInstance) {
            importPopover
        }
        
    }
    func handleDrop(_ providers: [NSItemProvider], folder: URL) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, error) in
                let pluginsFolder = folder.appendingPathComponent("plugins", conformingTo: .folder)
                if let data = data as? Data, let fileURL = URL(dataRepresentation: data, relativeTo: nil) {
                    if fileURL.pathExtension == "jar" {
                        do {
                            if FileManager.default.fileExists(atPath: pluginsFolder.path()) {
                                try FileManager.default.copyItem(at: fileURL, to: pluginsFolder.appendingPathComponent(fileURL.lastPathComponent, conformingTo: .data))
                            } else {
                                try FileManager.default.createDirectory(at: pluginsFolder, withIntermediateDirectories: true)
                                try FileManager.default.copyItem(at: fileURL, to: pluginsFolder.appendingPathComponent(fileURL.lastPathComponent, conformingTo: .data))
                            }
                            sendNotification(title: "Success", body: "Added Plugin: \(fileURL.lastPathComponent)", id: "dropJar")
                        } catch {
                            sendNotification(title: "Error", body: error.localizedDescription, id: "dropJar")
                            print(error.localizedDescription)
                        }
                    } else {
                        sendNotification(title: "Error", body: "The file you dropped is not a jar file", id: "dropJar")
                        print("The file you dropped is not a jar file")
                    }
                }
            }
        }
        return true
    }
    
    @State var addInstance = false
    @State var newInstanceName = ""
    
    @State var selectFolder = false
    @State var folderURL: URL?
    
    @State var selectJar = false
    @State var jarPathURL: URL?
    
    var popover: some View {
        VStack {
            List {
                Section("Create New Instance") {
                    TextField("New Instance Name", text: $newInstanceName)
                    HStack {
                        if let folderURL {
                            Text(folderURL.path())
                        } else {
                            Text("No Folder selected")
                        }
                        Spacer()
                        Button("Select Folder") {
                            selectFolder = true
                        }
                        .fileImporter(isPresented: $selectFolder, allowedContentTypes: [.folder], onCompletion: { result in
                            do {
                                try folderURL = result.get()
                            } catch {
                                showError(error.localizedDescription)
                            }
                        })
                    }
                    HStack {
                        if let jarPathURL {
                            Text(jarPathURL.path())
                        } else {
                            Text("No Server JAR selected")
                        }
                        Spacer()
                        Button("Select JAR") {
                            selectJar = true
                        }
                        .fileImporter(isPresented: $selectJar, allowedContentTypes: [.data], onCompletion: { result in
                            do {
                                try jarPathURL = result.get()
                            } catch {
                                showError(error.localizedDescription)
                            }
                        })
                    }
                    HStack {
                        Spacer()
                        Button("Add Instance") {
                            do {
                                if FileManager().fileExists(atPath: folderURL!.appendingPathComponent("server.jar").path()) {
                                    showError("The server.jar file already exists in the selected Folder, please select a different Folder or delete the server.jar from the Folder")
                                } else {
                                    try FileManager().copyItem(at: jarPathURL!, to: folderURL!.appendingPathComponent("server.jar"))
                                    let eulaText = "eula=true"
                                    try eulaText.write(to: folderURL!.appendingPathComponent("eula.txt", conformingTo: .data), atomically: true, encoding: .utf8)
                                    instances.append(ServerInstance(name: newInstanceName, folder: folderURL!, jar: folderURL!.appendingPathComponent("server.jar"), minRAM: 500, maxRAM: 1000))
                                    addInstance = false
                                    folderURL = nil
                                    jarPathURL = nil
                                    newInstanceName = ""
                                }
                                
                            } catch {
                                showError(error.localizedDescription)
                            }
                        }
                        .disabled(newInstanceName.isEmpty || folderURL == nil || jarPathURL == nil)
                        Spacer()
                    }
                } .listStyle(InsetListStyle())
            }
        }
    }
    @State var newImportInstanceName = ""
    
    @State var selectImportFolder = false
    @State var folderImportURL: URL?
    @State var importJarName = ""
    
    var importPopover: some View {
        VStack {
            List {
                Section("Import existing Instance") {
                    TextField("New Instance Name", text: $newImportInstanceName)
                    HStack {
                        if let folderImportURL {
                            Text(folderImportURL.path())
                        } else {
                            Text("No Folder selected")
                        }
                        Spacer()
                        Button("Select Folder") {
                            selectImportFolder = true
                        }
                        .fileImporter(isPresented: $selectImportFolder, allowedContentTypes: [.folder], onCompletion: { result in
                            do {
                                try folderImportURL = result.get()
                            } catch {
                                showError(error.localizedDescription)
                            }
                        })
                    }
                    HStack {
                        Text("Current JAR-File Name")
                        TextField("Current Server JAR-File Name", text: $importJarName)
                        Text(".jar")
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Button("Import Instance") {
                            do {
                                if FileManager().fileExists(atPath: folderImportURL!.appendingPathComponent(importJarName + ".jar", conformingTo: .data).path().replacingOccurrences(of: "%20", with: " ")) {
                                    let eulaText = "eula=true"
                                    try eulaText.write(to: folderImportURL!.appendingPathComponent("eula.txt", conformingTo: .data), atomically: true, encoding: .utf8)
                                    instances.append(ServerInstance(name: newImportInstanceName, folder: folderImportURL!, jar: folderImportURL!.appendingPathComponent(importJarName + ".jar"), minRAM: 500, maxRAM: 1000))
                                    importInstance = false
                                    folderImportURL = nil
                                    newImportInstanceName = ""
                                } else {
                                    showError("The Server JAR \"\(importJarName).jar\" doesn't exist")
                                }
                                
                            } catch {
                                showError(error.localizedDescription)
                            }
                        }
                        .disabled(newImportInstanceName.isEmpty || folderImportURL == nil || importJarName.isEmpty)
                        Spacer()
                    }
                } .listStyle(InsetListStyle())
            }
        }
    }
    
    func runJavaProcess(jar: URL, folder: URL, log: Binding<String>, jarProcess: Binding<Process>, pipeVar: Binding<Pipe>, inputPipeVar: Binding<Pipe>, minRAM: CGFloat, maxRAM: CGFloat, GUI: Bool) {
        let jarPath = jar.absoluteString.replacingOccurrences(of: "file://", with: "")
        
        let process = Process()
        process.currentDirectoryURL = folder
        process.launchPath = "/usr/bin/java"
        process.arguments = ["-Xms\(Int(minRAM))M", "-Xmx\(Int(maxRAM))M", "-jar", "\(jarPath.replacingOccurrences(of: "%20", with: " "))", String(GUI ? "" : "nogui")]
        
        let pipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = inputPipe
        
        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { handle in
            if let output = String(data: handle.availableData, encoding: .utf8), !output.isEmpty {
                DispatchQueue.main.async {
                    log.wrappedValue += output + "\n"
                }
            }
        }
        
        jarProcess.wrappedValue = process
        pipeVar.wrappedValue = pipe
        inputPipeVar.wrappedValue = inputPipe
        
        do {
            try process.run()
        } catch {
            log.wrappedValue = "Failed to launch process: \(error.localizedDescription)"
        }
    }
    
    func stopJavaProcess(jarProcess: Binding<Process>, log: Binding<String>, index: Int) {
        instances[index].sendCommand("stop")
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            print("Waiting to stop")
        }
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            print("Waiting to stop")
        }
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("Waiting to stop")
        }
    }
    func loadInstances() {
        let decoder = JSONDecoder()
        do {
            try saveInstances = decoder.decode([SaveableServerInstance].self, from: instanceData)
        } catch {
            showError(error.localizedDescription)
        }
        instances = []
        
        for instance in saveInstances {
            instances.append(ServerInstance(name: instance.name, folder: instance.folder, jar: instance.jar, minRAM: instance.minRAM, maxRAM: instance.maxRAM, GUI: instance.GUI ?? false))
        }
    }
    func saveTheInstances() {
        saveInstances = []
        for instance in instances {
            saveInstances.append(
                SaveableServerInstance(name: instance.name, folder: instance.folder, jar: instance.jar, log: instance.log, minRAM: instance.minRAM, maxRAM: instance.maxRAM, GUI: instance.GUI ?? false)
            )
        }
        let encoder = JSONEncoder()
        do {
            try instanceData = encoder.encode(saveInstances)
        } catch {
            showError(error.localizedDescription)
        }
    }
    func readServerProperties(_ url: URL) -> [String: String] {
        var properties: [String: String] = [:]
        
        do {
            let fileContents = try String(contentsOf: url, encoding: .utf8)
            
            for line in fileContents.split(separator: "\n") {
                // Ignore comments and empty lines
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                let parts = trimmedLine.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    properties[key] = value
                }
            }
        } catch {
            showError(error.localizedDescription)
        }
        
        return properties
    }
    func saveServerProperties(_ properties: [String: String], to url: URL) {
        var fileContents = ""
        
        for (key, value) in properties {
            fileContents += "\(key)=\(value)\n"
        }
        
        do {
            try fileContents.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            showError(error.localizedDescription)
        }
    }
    func deleteInstance(at offsets: IndexSet) {
        let firstalert = NSAlert()
        firstalert.messageText = "Are you sure you want to delete this Instance?"
        firstalert.informativeText = "This action cannot be undone"
        firstalert.alertStyle = .critical
        
        firstalert.addButton(withTitle: "Yes")
        firstalert.addButton(withTitle: "No")
        
        let firstresponse = firstalert.runModal()
        if firstresponse == .alertFirstButtonReturn {
            for index in offsets {
                let folder = instances[index].folder
                let alert = NSAlert()
                alert.messageText = "Do you want to delete the folder too?"
                alert.informativeText = folder.path()
                alert.alertStyle = .critical
                
                
                alert.addButton(withTitle: "Yes")
                alert.addButton(withTitle: "No")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    do {
                        try FileManager.default.removeItem(at: folder)
                    } catch {
                        showError(error.localizedDescription)
                    }
                } else {
                    print("Not deleting dir")
                }
            }
            instances.remove(atOffsets: offsets)
            
        } else {
            print("Cancelled deletion")
        }
        
        
    }
    func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

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
}

import AppKit

func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Error"
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
func showAlertWithTextField(_ message: String, completion: @escaping (String?) -> Void) {
    let alert = NSAlert()
    alert.messageText = "Alert"
    alert.informativeText = message
    alert.alertStyle = .informational
    
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    textField.placeholderString = "Enter something..."
    
    alert.accessoryView = textField
    
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        completion(textField.stringValue)
    } else {
        completion(nil)
    }
}

func parseANSIColorCodes(_ text: String) -> NSAttributedString {
    let attributedString = NSMutableAttributedString(string: text)
    
    // Define ANSI color codes and their corresponding UIColor values
    let ansiColorCodes: [String: NSColor] = [
        "\u{001b}[31m": .red,
        "\u{001b}[32m": .green,
        "\u{001b}[33m": .yellow,
        "\u{001b}[34m": .blue,
        "\u{001b}[35m": .magenta,
        "\u{001b}[36m": .cyan,
        "\u{001b}[37m": .white,
        "\u{001b}[0m": .black  // Reset color
    ]
    
    // Find ANSI escape codes in the text using a regular expression
    let regex = try! NSRegularExpression(pattern: "\u{001b}\\[[0-9;]*m", options: [])
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))
    
    // Apply color to matching ANSI codes
    for match in matches {
        let codeRange = match.range
        let code = (text as NSString).substring(with: codeRange)
        
        if let color = ansiColorCodes[code] {
            attributedString.addAttribute(.foregroundColor, value: color, range: codeRange)
        }
    }
    
    return attributedString
}

func getInstalledMemoryInMB() -> UInt64? {
    var size: Int = 0
    let result = sysctlbyname("hw.memsize", &size, nil, nil, 0)
    
    if result == 0 {
        // Convert bytes to MB (1 MB = 1024 * 1024 bytes)
        return UInt64(size) / 1_048_576
    } else {
        return nil
    }
}

struct PluginFileManagerView: View {
    let rootFolderURL: URL
    @State private var items: [URL] = []
    @State private var selectedItem: URL?
    @State private var showDeleteAlert = false
    @State private var itemToDelete: URL?
    
    // Fetches contents of a folder
    func loadContents(of folderURL: URL) {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
            self.items = contents
        } catch {
            print("Failed to load contents: \(error)")
        }
    }
    
    // Deletes a file or folder
    func deleteItem(at url: URL) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: url)
            loadContents(of: rootFolderURL)
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    var body: some View {
        List {
            if items.isEmpty {
                Text("No Mods yet")
            } else {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Image(systemName: item.hasDirectoryPath ? "folder.fill" : "doc.fill")
                        Text(item.lastPathComponent)
                            .lineLimit(1)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contentShape(Rectangle())
                }
            }
        }
        .frame(minHeight: 250)
        .onAppear {
            loadContents(of: rootFolderURL)
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Warning!"),
                message: Text("Are you sure you want to delete \"\(itemToDelete?.lastPathComponent ?? "Unknown File")\"?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let itemToDelete = itemToDelete {
                        deleteItem(at: itemToDelete)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}
