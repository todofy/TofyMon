import SwiftUI

struct Dashboard: View {
    @StateObject private var client = DaemonClient()

    var body: some View {
        VStack(spacing: 0) {
            // Modern Floating Header
            HStack {
                Text("TofyMon")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.4))
                    .padding(.leading, 75)
                
                Spacer()
                
                if let project = client.project {
                    HStack(spacing: 6) {
                        ForEach(project.services) { service in
                            let isRunning = service.actualState == "running"
                            Circle()
                                .fill(isRunning ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                                .shadow(color: (isRunning ? Color.green : Color.red).opacity(0.5), radius: 3)
                        }
                    }
                    .padding(.trailing, 20)
                }
            }
            .frame(height: 44)
            .background(Color.black.opacity(0.1))

            if let errorMsg = client.errorMsg {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 44, weight: .thin))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(errorMsg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let project = client.project {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Project Identity Area
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name.uppercased())
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.secondary)
                                    .tracking(2)
                                
                                Text(project.actualState == "running" ? "Active" : "Paused")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary.opacity(0.9))
                            }
                            Spacer()
                            ControlButtons(client: client, isRunning: project.actualState == "running")
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // Service Cards Grid
                        VStack(spacing: 14) {
                            ForEach(project.services) { service in
                                ServiceCard(service: service)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { client.startPolling() }
        .onDisappear { client.stopPolling() }
    }
}

struct ControlButtons: View {
    @ObservedObject var client: DaemonClient
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { isRunning ? client.stopProject() : client.startProject() }) {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .shadow(color: (isRunning ? Color.red : Color.green).opacity(0.3), radius: 8)
                    
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { client.fetchStatus() }) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ServiceCard: View {
    let service: TofyService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                // Dynamic Icon based on service ID
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.04))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: serviceIcon(service.id))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    
                    if let pid = service.pid {
                        Text("Process ID: \(String(pid))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                
                Spacer()
                
                StatusBadge(status: service.actualState)
            }
            
            if service.actualState == "running" {
                HStack(spacing: 18) {
                    if let uptime = service.uptimeSeconds {
                        InfoCapsule(icon: "clock.fill", text: formatUptime(uptime))
                    }
                    
                    if service.restartCount > 0 {
                        InfoCapsule(icon: "arrow.counterclockwise.circle.fill", text: "\(service.restartCount)", color: .orange)
                    }
                    
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
    
    private func serviceIcon(_ id: String) -> String {
        switch id {
        case let s where s.contains("api"): return "network"
        case let s where s.contains("telegram"): return "paperplane.fill"
        case let s where s.contains("admin"): return "command"
        case let s where s.contains("calendar"): return "calendar"
        case let s where s.contains("task"): return "checkmark.seal.fill"
        default: return "cpu"
        }
    }
    
    private func formatUptime(_ seconds: UInt64) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%dh %dm", h, m) : String(format: "%dm %ds", m, s)
    }
}

struct InfoCapsule: View {
    let icon: String
    let text: String
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundColor(color.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.05))
        .cornerRadius(6)
    }
}

struct StatusBadge: View {
    let status: String
    var body: some View {
        let isRunning = status == "running"
        let color: Color = isRunning ? .green : (status == "failed" ? .red : .secondary)
        
        Text(status.uppercased())
            .font(.system(size: 9, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(isRunning ? 0.7 : 0.3))
            )
            .shadow(color: color.opacity(isRunning ? 0.4 : 0), radius: 4)
    }
}



