import UserNotifications

func sendNotification(title: String, body: String, id: String) {
    requestNotificationPermission()
    let content = UNMutableNotificationContent()
    
    content.title = title
    content.body = body
    content.sound = UNNotificationSound.default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
    
    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
}
func requestNotificationPermission() {
    DispatchQueue.main.async(execute: {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting permission: \(error.localizedDescription)")
            } else {
                print("Permission granted: \(granted)")
            }
        }
    })
}
