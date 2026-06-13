// Reads Wi-Fi RSSI (dBm) and SSID via CoreWLAN. No sudo needed (unlike wdutil).
// Output: "<rssi>|<ssid>" — rssi is 0 when Wi-Fi is off or not associated.
// SSID is empty without Location Services permission on macOS 14+; consumers
// must treat it as optional and key connectivity off RSSI.
// Compiled once by wifi_signal.sh into bin/wifi_reader (gitignored).
import Foundation
import CoreWLAN

if let iface = CWWiFiClient.shared().interface(), iface.powerOn() {
  print("\(iface.rssiValue())|\(iface.ssid() ?? "")")
} else {
  print("0|")
}
