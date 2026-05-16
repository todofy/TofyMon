import SwiftUI

struct Dashboard: View {
    @StateObject private var client = DaemonClient()
    @State private var isSidebarOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Main Content
            VStack(spacing: 0) {
                // Minimalist Header
                HStack(spacing: 16) {
                    Spacer()
                        .frame(width: 80) // Space for traffic lights

                    Text("TofyMon")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                    
                    Spacer()
                    
                    if let project = client.selectedProject {
                        HStack(spacing: 4) {
                            ForEach(project.services) { service in
                                let isRunning = service.actualState == "running"
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(isRunning ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)
                                    .shadow(color: (isRunning ? Color.green : Color.red).opacity(0.4), radius: 3)
                            }
                        }
                    }

                    Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSidebarOpen.toggle() } }) {
                        Image(systemName: "sidebar.right")
                            .font(.system(size: 15))
                            .foregroundColor(.primary.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 16)
                }
                .frame(height: 60)
                .background(Color.black.opacity(0.05))

                if let errorMsg = client.errorMsg {
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "bolt.horizontal.icloud.fill")
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundColor(.secondary.opacity(0.2))
                        Text(errorMsg)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            if let project = client.selectedProject {
                                ProjectView(client: client, project: project)
                            } else if client.selectedProjectId == nil {
                                // "All" View
                                ForEach(client.projects) { project in
                                    ProjectView(client: client, project: project)
                                        .padding(.bottom, 20)
                                }
                            } else {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .opacity(0.5)
                                    .padding(.top, 100)
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Dimming Background
            if isSidebarOpen {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isSidebarOpen = false
                        }
                    }
                    .transition(.opacity)
            }

            // Sidebar Overlay
            if isSidebarOpen {
                SidebarView(client: client, isOpen: $isSidebarOpen)
                    .transition(.move(edge: .leading))
                    .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { client.startPolling() }
        .onDisappear { client.stopPolling() }
    }
}

struct SidebarView: View {
    @ObservedObject var client: DaemonClient
    @Binding var isOpen: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROJECTS")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.secondary)
                .tracking(1.5)
                .padding(.horizontal, 16)
                .padding(.top, 52) // Padding for traffic lights
            
            SidebarItem(title: "All Projects", isSelected: client.selectedProjectId == nil) {
                withAnimation {
                    client.selectedProjectId = nil
                    isOpen = false
                }
            }
            
            ForEach(client.projects) { project in
                SidebarItem(title: project.name, isSelected: client.selectedProjectId == project.id) {
                    withAnimation {
                        client.selectedProjectId = project.id
                        isOpen = false
                    }
                }
            }
            
            Spacer()
        }
        .frame(width: 240)
        .background(
            ZStack {
                SidebarBlurView(material: .sidebar, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                Color.primary.opacity(0.02)
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 1), alignment: .trailing
        )
    }
}

struct SidebarBlurView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct SidebarItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                Spacer()
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.primary.opacity(0.05) : Color.clear)
            .cornerRadius(8)
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProjectView: View {
    @ObservedObject var client: DaemonClient
    let project: TofyProject
    
    var body: some View {
        VStack(spacing: 20) {
            // Project Status Hero
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(project.name) (\(project.services.count))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.primary, .primary.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Spacer()
                ControlButtons(client: client, project: project)
            }
            .padding(.horizontal, 24)

            // Services List
            VStack(spacing: 16) {
                ForEach(project.services) { service in
                    ServiceCard(service: service)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct ControlButtons: View {
    @ObservedObject var client: DaemonClient
    let project: TofyProject
    
    var body: some View {
        let isRunning = project.actualState == "running"
        HStack(spacing: 14) {
            Button(action: { isRunning ? client.stopProject(id: project.id) : client.startProject(id: project.id) }) {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        ZStack {
                            Circle().fill(isRunning ? Color.red : Color.green).opacity(0.8)
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                    )
                    .shadow(color: (isRunning ? Color.red : Color.green).opacity(0.3), radius: 10, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { client.fetchStatus() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.primary.opacity(0.04)))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ServiceCard: View {
    let service: TofyService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                // Icon with subtle glow
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.03))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: serviceIcon(service.id))
                        .font(.system(size: 15))
                        .foregroundColor(.primary.opacity(0.6))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(service.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.9))
                    
                    if let pid = service.pid {
                        Text("PID \(String(pid))")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                
                Spacer()
                
                StatusBadge(status: service.actualState)
            }
            
            if service.actualState == "running" {
                HStack(spacing: 20) {
                    if let uptime = service.uptimeSeconds {
                        Label {
                            Text(formatUptime(uptime))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        } icon: {
                            Image(systemName: "clock.fill").font(.system(size: 9))
                        }
                        .foregroundColor(.secondary.opacity(0.7))
                    }
                    
                    if service.restartCount > 0 {
                        Label {
                            Text("\(service.restartCount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        } icon: {
                            Image(systemName: "arrow.counterclockwise.circle.fill").font(.system(size: 9))
                        }
                        .foregroundColor(.orange.opacity(0.8))
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                )
        )
    }
    
    private func serviceIcon(_ id: String) -> String {
        let sid = id.lowercased()
        if sid.contains("api") { return "server.rack" }
        if sid.contains("telegram") || sid.contains("listener") { return "paperplane.fill" }
        if sid.contains("admin") || sid.contains("dashboard") { return "gauge.medium" }
        if sid.contains("calendar") { return "calendar" }
        if sid.contains("task") || sid.contains("daemon") { return "brain.fill" }
        return "cpu.fill"
    }
    
    private func formatUptime(_ seconds: UInt64) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%dh %dm", h, m) : String(format: "%dm %ds", m, s)
    }
}

struct StatusBadge: View {
    let status: String
    var body: some View {
        let isRunning = status == "running"
        let color: Color = isRunning ? .green : (status == "failed" ? .red : .secondary)
        
        Text(status.uppercased())
            .font(.system(size: 9, weight: .black))
            .foregroundColor(color.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            )
    }
}
extension TofyProject: Identifiable {}

