import SwiftUI

@main
struct TofyUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            Dashboard()
                .frame(minWidth: 400, idealWidth: 400, maxWidth: 500, minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.level = .floating // Always on top
        }
    }
}
import Foundation

struct TofyProject: Codable {
    let id: String
    let name: String
    let actualState: String
    let services: [TofyService]
}

struct TofyService: Codable, Identifiable {
    let id: String
    let name: String
    let actualState: String
    let pid: UInt32?
    let uptimeSeconds: UInt64?
    let restartCount: UInt32
}

class DaemonClient: ObservableObject {
    @Published var project: TofyProject?
    @Published var errorMsg: String?
    
    private var timer: Timer?
    private let projectId = "iris"
    
    func startPolling() {
        fetchStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.fetchStatus()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchStatus() {
        DispatchQueue.global(qos: .background).async {
            do {
                let jsonStr = try self.curlSocket(method: "GET", path: "/v1/projects/\(self.projectId)")
                if let data = jsonStr.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let proj = try decoder.decode(TofyProject.self, from: data)
                    DispatchQueue.main.async {
                        self.project = proj
                        self.errorMsg = nil
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMsg = "Daemon unavailable or project not registered."
                }
            }
        }
    }
    
    func stopProject() {
        DispatchQueue.global(qos: .background).async {
            let _ = try? self.curlSocket(method: "POST", path: "/v1/projects/\(self.projectId)/stop")
            self.fetchStatus()
        }
    }
    
    func startProject() {
        DispatchQueue.global(qos: .background).async {
            let _ = try? self.curlSocket(method: "POST", path: "/v1/projects/\(self.projectId)/start")
            self.fetchStatus()
        }
    }

    private func curlSocket(method: String, path: String) throws -> String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? ""
        var socketPath = "\(home)/Library/Application Support/TofyDaemon/tofy.sock"
        if !FileManager.default.fileExists(atPath: socketPath) {
            socketPath = "/tmp/tofy.sock"
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        task.arguments = ["-s", "-X", method, "--unix-socket", socketPath, "http://localhost\(path)"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if task.terminationStatus != 0 {
            throw NSError(domain: "DaemonClient", code: Int(task.terminationStatus), userInfo: nil)
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
}
import SwiftUI

struct Dashboard: View {
    @StateObject private var client = DaemonClient()

    var body: some View {
        ZStack {
            // Background
            Color(NSColor.windowBackgroundColor)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TofyDaemon")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(client.project?.name ?? "Iris")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if let project = client.project {
                        let isRunning = project.actualState == "running"
                        Button(action: {
                            if isRunning {
                                client.stopProject()
                            } else {
                                client.startProject()
                            }
                        }) {
                            Text(isRunning ? "Stop All" : "Start All")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(isRunning ? .white : .primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isRunning ? Color.red.opacity(0.8) : Color.blue.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(24)
                
                Divider()
                
                // Content
                if let errorMsg = client.errorMsg {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(errorMsg)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let project = client.project {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(project.services) { service in
                                ServiceRow(service: service)
                            }
                        }
                        .padding(24)
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            client.startPolling()
        }
        .onDisappear {
            client.stopPolling()
        }
    }
}

struct ServiceRow: View {
    let service: TofyService
    
    var body: some View {
        let isRunning = service.actualState == "running"
        let statusColor = isRunning ? Color.green : Color.red
        
        HStack(spacing: 16) {
            // Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.5), radius: 4, x: 0, y: 0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    if let pid = service.pid {
                        Text("PID: \(pid)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    if let uptime = service.uptimeSeconds {
                        let hours = uptime / 3600
                        let minutes = (uptime % 3600) / 60
                        let seconds = uptime % 60
                        Text(String(format: "Uptime: %02d:%02d:%02d", hours, minutes, seconds))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    if service.restartCount > 0 {
                        Text("Restarts: \(service.restartCount)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // State Badge
            Text(service.actualState.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}
