
import SwiftUI
import FullDiskAccess

@main
struct MC_Server_GUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    FullDiskAccess.promptIfNotGranted(
                        title: "Enable Full Disk Access for MC Server GUI",
                        message: "MC Server GUI requires Full Disk Access to properly access your server files.",
                        settingsButtonTitle: "Open Settings",
                        skipButtonTitle: "Later",
                        canBeSuppressed: false,
                        icon: nil
                    )
                }
            
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Quit All Java Processes") {
                    let alert = NSAlert()
                    alert.messageText = "Quit All Java Processes"
                    alert.informativeText = "Are you sure you want to quit all Java Processes? This will close any Java Program that might be running right now including the Minecraft Game!"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Quit Anyways")
                    alert.addButton(withTitle: "Cancel")

                    if alert.runModal() == .alertFirstButtonReturn {
                        forceQuitAllJavaProcesses()
                    }
                }
                .keyboardShortcut("Q", modifiers: [.command, .option])
            }
        }
        
    }
}

import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.messageText = "Warning"
        alert.informativeText = "Your Servers may continue to run if you quit MC Server GUI. To completely end them, make sure to stop them in the app first."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}

func forceQuitAllJavaProcesses() {
    // Command to find all Java processes and kill them
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", "pkill -f 'java'"]

    do {
        try task.run()
        task.waitUntilExit()
        print("All Java processes have been terminated.")
    } catch {
        showError("An error occurred: \(error.localizedDescription)")
    }
}
