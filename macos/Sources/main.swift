// ProxyToggle — a menu bar switch for the macOS system HTTP/HTTPS proxy.
//
// `helperSource` is not declared here: build.sh generates Sources/HelperSource.swift
// from scripts/proxyctl so the shell helper has a single source of truth.

import AppKit
import SystemConfiguration
import ServiceManagement

let helperPath  = "/usr/local/bin/proxyctl"
let sudoersPath = "/etc/sudoers.d/proxyctl"

struct ProxyState {
    var service = "-"
    var httpOn = false, httpsOn = false
    var host = "", port = "", secureHost = "", securePort = ""

    var mixed: Bool { httpOn != httpsOn }
    var on: Bool { httpOn && httpsOn }
}

@discardableResult
func sh(_ path: String, _ args: [String]) -> (code: Int32, out: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    guard (try? p.run()) != nil else { return (-1, "") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var store: SCDynamicStore?
    var state = ProxyState()
    var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        item.button?.action = #selector(click(_:))
        item.button?.target = self
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        render()

        guard ensureHelper() else {
            setTitle("⚠ PROXY", .systemRed)
            item.button?.toolTip = "特権ヘルパーの設置に失敗しました。ProxyToggle を再起動してください。"
            return
        }

        watchSystemChanges()
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in self.refresh() }
        refresh()
    }

    // MARK: - Privileged helper (one admin prompt, first launch only)

    /// Installs the root-owned helper plus a sudoers rule scoped to that one binary.
    /// Everything after this runs without further authentication.
    func ensureHelper() -> Bool {
        let fm = FileManager.default
        if fm.isExecutableFile(atPath: helperPath) && fm.fileExists(atPath: sudoersPath) { return true }

        let tmp = NSTemporaryDirectory() + "proxytoggle-install.sh"
        let installer = """
        #!/bin/sh
        set -e
        /bin/mkdir -p /usr/local/bin
        /bin/cat > \(helperPath) <<'PROXYCTL_EOF'
        \(helperSource)
        PROXYCTL_EOF
        /usr/sbin/chown root:wheel \(helperPath)
        /bin/chmod 755 \(helperPath)
        /bin/echo '\(NSUserName()) ALL=(root) NOPASSWD: \(helperPath)' > \(sudoersPath)
        /usr/sbin/chown root:wheel \(sudoersPath)
        /bin/chmod 440 \(sudoersPath)
        """
        guard (try? installer.write(toFile: tmp, atomically: true, encoding: .utf8)) != nil else { return false }

        var error: NSDictionary?
        let source = "do shell script \"/bin/sh \\\"\(tmp)\\\"\" with administrator privileges"
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        try? fm.removeItem(atPath: tmp)

        return error == nil && fm.isExecutableFile(atPath: helperPath)
    }

    // MARK: - State

    func refresh() {
        DispatchQueue.global(qos: .utility).async {
            let fields = sh(helperPath, ["status"]).out
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "|")
            guard fields.count >= 7 else { return }
            let next = ProxyState(service: fields[0],
                                  httpOn: fields[1] == "Yes", httpsOn: fields[4] == "Yes",
                                  host: fields[2], port: fields[3],
                                  secureHost: fields[5], securePort: fields[6])
            DispatchQueue.main.async {
                self.state = next
                self.render()
            }
        }
    }

    func setTitle(_ text: String, _ color: NSColor) {
        item.button?.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.foregroundColor: color,
                         .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)])
    }

    func render() {
        let mark: String, color: NSColor
        if busy {
            mark = "◌"; color = .secondaryLabelColor
        } else if state.mixed {
            mark = "◐"; color = .systemOrange
        } else if state.on {
            mark = "●"; color = .systemGreen
        } else {
            mark = "○"; color = .secondaryLabelColor
        }
        setTitle("\(mark) PROXY", color)
        item.button?.toolTip = """
        \(state.service)
        HTTP  \(state.host):\(state.port) [\(state.httpOn ? "有効" : "無効")]
        HTTPS \(state.secureHost):\(state.securePort) [\(state.httpsOn ? "有効" : "無効")]
        """
    }

    /// Repaint immediately when the proxy is changed from System Settings or the CLI.
    func watchSystemChanges() {
        var ctx = SCDynamicStoreContext(version: 0,
                                        info: Unmanaged.passUnretained(self).toOpaque(),
                                        retain: nil, release: nil, copyDescription: nil)
        let callback: SCDynamicStoreCallBack = { _, _, info in
            guard let info else { return }
            let me = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { me.refresh() }
        }
        store = SCDynamicStoreCreate(nil, "ProxyToggle" as CFString, callback, &ctx)
        if let store {
            SCDynamicStoreSetNotificationKeys(store,
                                              ["State:/Network/Global/Proxies" as CFString] as CFArray,
                                              nil)
            SCDynamicStoreSetDispatchQueue(store, .main)
        }
    }

    // MARK: - Actions

    @objc func click(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() } else { toggle() }
    }

    @objc func toggle() {
        guard !busy else { return }
        busy = true
        render()
        DispatchQueue.global(qos: .userInitiated).async {
            sh("/usr/bin/sudo", ["-n", helperPath, "toggle"])
            DispatchQueue.main.async {
                self.busy = false
                self.refresh()
            }
        }
    }

    func showMenu() {
        let menu = NSMenu()
        let header = NSMenuItem(title: "ネットワーク: \(state.service)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(withTitle: "  HTTP   \(state.host):\(state.port)  [\(state.httpOn ? "有効" : "無効")]",
                     action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(withTitle: "  HTTPS  \(state.secureHost):\(state.securePort)  [\(state.httpsOn ? "有効" : "無効")]",
                     action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: state.on ? "OFF にする" : "ON にする",
                     action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "ネットワーク設定を開く…",
                     action: #selector(openSettings), keyEquivalent: "").target = self
        if #available(macOS 13.0, *) {
            let login = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!)
    }

    @objc func toggleLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if service.status == .enabled { try? service.unregister() } else { try? service.register() }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
