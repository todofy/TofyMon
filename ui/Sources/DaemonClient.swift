import Foundation
import Combine

struct TofyProject: Codable {
    let id: String
    let name: String
    let actualState: String
    let services: [TofyService]
}

struct GhostProcess: Codable, Identifiable {
    var id: UInt32 { pid }
    let pid: UInt32
    let memoryBytes: UInt64
    let cpuPercent: Float
    let runTime: UInt64
}

struct TofyService: Codable, Identifiable {
    let id: String
    let name: String
    let actualState: String
    let pid: UInt32?
    let uptimeSeconds: UInt64?
    let restartCount: UInt32
    let url: String?
    let hasGhostProcesses: Bool
    let ghostProcesses: [GhostProcess]
}

class DaemonClient: ObservableObject {
    @Published var projects: [TofyProject] = []
    @Published var selectedProjectId: String? = nil
    @Published var errorMsg: String?
    
    private var timer: Timer?
    
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
                let jsonStr = try self.curlSocket(method: "GET", path: "/v1/projects")
                if let data = jsonStr.data(using: .utf8) {
                    let decoder = JSONDecoder()
                    let projs = try decoder.decode([TofyProject].self, from: data)
                    DispatchQueue.main.async {
                        self.projects = projs
                        self.errorMsg = nil
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMsg = "Daemon unavailable."
                }
            }
        }
    }
    
    func stopProject(id: String) {
        DispatchQueue.global(qos: .background).async {
            let _ = try? self.curlSocket(method: "POST", path: "/v1/projects/\(id)/stop")
            self.fetchStatus()
        }
    }
    
    func startProject(id: String) {
        DispatchQueue.global(qos: .background).async {
            let _ = try? self.curlSocket(method: "POST", path: "/v1/projects/\(id)/start")
            self.fetchStatus()
        }
    }
    
    func killGhostProcess(pid: UInt32) {
        DispatchQueue.global(qos: .background).async {
            let _ = try? self.curlSocket(method: "POST", path: "/v1/process/\(pid)/kill")
            self.fetchStatus()
        }
    }


    var selectedProject: TofyProject? {
        if let id = selectedProjectId {
            return projects.first { $0.id == id }
        }
        return nil
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
