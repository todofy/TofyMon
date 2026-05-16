import SwiftUI
import AppKit

struct Dashboard: View {
    @StateObject private var client = DaemonClient()
    @State private var isSidebarOpen = false

    @AppStorage("viewMode") var viewMode: String = "list"
    @State private var selectedServiceForDetails: TofyService? = nil
    
    @FocusState private var isDashboardFocused: Bool
    @State private var keyboardSelectedIndex: Int? = nil
    @AppStorage("fontSizeMultiplier") var fontSizeMultiplier: Double = 1.0
    
    private var visibleServices: [TofyService] {
        if let project = client.selectedProject {
            return project.services
        } else if client.selectedProjectId == nil {
            return client.projects.flatMap { $0.services }
        }
        return []
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background Layer
            ZStack {
                SidebarBlurView(material: .sidebar, blendingMode: .behindWindow)
                    .ignoresSafeArea()
                
                // Subtle Grid
                GridView()
                    .opacity(0.03)
                
                // Animated Particles
                ParticleBackgroundView()
                    .opacity(0.08)
            }
            .ignoresSafeArea()

            // Main Content
            VStack(spacing: 0) {
                // Minimalist Header
                HStack(spacing: 16) {
                    Spacer()
                        .frame(width: 80) // Space for traffic lights

                    Text("TofyMon")
                        .scaledFont(size: 18, weight: .black, design: .rounded)
                        .foregroundColor(.primary.opacity(0.8))
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Decrease Font Size
                        Button(action: {
                            withAnimation(.spring()) {
                                fontSizeMultiplier = max(0.6, fontSizeMultiplier - 0.1)
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Decrease Text Size")
                        
                        // Increase Font Size
                        Button(action: {
                            withAnimation(.spring()) {
                                fontSizeMultiplier = min(2.0, fontSizeMultiplier + 0.1)
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Increase Text Size")

                        // View Toggle
                        Button(action: { 
                            withAnimation(.spring()) { 
                                if viewMode == "list" { viewMode = "grid" }
                                else if viewMode == "grid" { viewMode = "table" }
                                else { viewMode = "list" }
                            } 
                        }) {
                            Image(systemName: viewMode == "grid" ? "square.grid.2x2" : (viewMode == "table" ? "tablecells" : "list.bullet"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Cycle View Mode (List/Grid/Table)")

                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isSidebarOpen.toggle() } }) {
                            Image(systemName: "sidebar.right")
                                .font(.system(size: 15))
                                .foregroundColor(.primary.opacity(0.5))
                                .frame(width: 32, height: 32)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 60)

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
                        VStack(spacing: 32) {
                            if let project = client.selectedProject {
                                ProjectView(client: client, project: project, viewMode: viewMode, keyboardSelectedServiceId: keyboardSelectedIndex != nil && keyboardSelectedIndex! < visibleServices.count ? visibleServices[keyboardSelectedIndex!].id : nil) { service in
                                    selectedServiceForDetails = service
                                    if let idx = visibleServices.firstIndex(where: { $0.id == service.id }) {
                                        keyboardSelectedIndex = idx
                                    }
                                }
                            } else if client.selectedProjectId == nil {
                                // "All" View
                                ForEach(client.projects) { project in
                                    ProjectView(client: client, project: project, viewMode: viewMode, keyboardSelectedServiceId: keyboardSelectedIndex != nil && keyboardSelectedIndex! < visibleServices.count ? visibleServices[keyboardSelectedIndex!].id : nil) { service in
                                        selectedServiceForDetails = service
                                        if let idx = visibleServices.firstIndex(where: { $0.id == service.id }) {
                                            keyboardSelectedIndex = idx
                                        }
                                    }
                                    .padding(.bottom, 20)
                                }
                            } else {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .opacity(0.5)
                                    .padding(.top, 100)
                            }
                        }
                        .padding(.vertical, 24)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Dimming Background
            if isSidebarOpen {
                Color.black.opacity(0.2)
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
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 10)
            }
            
            // Service Details Modal Overlay
            if let selectedService = selectedServiceForDetails {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedServiceForDetails = nil
                        }
                    }
                    .transition(.opacity)
                    .zIndex(200)
                
                // Get the most up-to-date service instance & project ID
                if let project = client.projects.first(where: { $0.services.contains(where: { $0.id == selectedService.id }) }) {
                    let latestService = project.services.first { $0.id == selectedService.id } ?? selectedService
                    
                    ServiceDetailsView(client: client, projectId: project.id, service: latestService) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedServiceForDetails = nil
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 550)
                    .offset(y: 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(201)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    ServiceDetailsView(client: client, projectId: "", service: selectedService) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedServiceForDetails = nil
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 550)
                    .offset(y: 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(201)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Hidden button to catch Return/Enter key
            if selectedServiceForDetails == nil {
                Button(action: {
                    if let index = keyboardSelectedIndex, index < visibleServices.count {
                        selectedServiceForDetails = visibleServices[index]
                    }
                }) {
                    EmptyView()
                }
                .keyboardShortcut(.defaultAction)
                .frame(width: 0, height: 0)
                .opacity(0)
            }
        }
        .focusable()
        .focused($isDashboardFocused)
        .onMoveCommand { direction in
            let services = visibleServices
            guard !services.isEmpty else { return }
            
            let current = keyboardSelectedIndex ?? -1
            var next = current
            
            switch direction {
            case .up:
                next = current > 0 ? current - 1 : services.count - 1
            case .down:
                next = current < services.count - 1 ? current + 1 : 0
            default:
                break
            }
            
            if next >= 0 && next < services.count {
                keyboardSelectedIndex = next
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isDashboardFocused = true
            client.startPolling()
        }
        .onDisappear { client.stopPolling() }
    }
}

struct GridView: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let step: CGFloat = 20
                for x in stride(from: 0, through: geo.size.width, by: step) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                }
                for y in stride(from: 0, through: geo.size.height, by: step) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.primary, lineWidth: 0.5)
        }
    }
}

struct ParticleBackgroundView: View {
    @State private var particles: [Particle] = (0..<15).map { _ in Particle() }
    
    struct Particle: Identifiable {
        let id = UUID()
        var x = CGFloat.random(in: 0...1)
        var y = CGFloat.random(in: 0...1)
        var size = CGFloat.random(in: 100...300)
        var opacity = Double.random(in: 0.1...0.3)
    }
    
    let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x * geo.size.width, y: particle.y * geo.size.height)
                        .blur(radius: 80)
                        .opacity(particle.opacity)
                        .animation(.easeInOut(duration: Double.random(in: 5...10)).repeatForever(autoreverses: true), value: particle.x)
                }
            }
        }
        .onReceive(timer) { _ in
            for i in 0..<particles.count {
                particles[i].x = CGFloat.random(in: 0...1)
                particles[i].y = CGFloat.random(in: 0...1)
            }
        }
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
                SidebarBlurView(material: .hudWindow, blendingMode: .withinWindow)
                    .ignoresSafeArea()
                Color.primary.opacity(0.01)
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(width: 0.5), alignment: .trailing
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
                        .shadow(color: Color.blue.opacity(0.5), radius: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.primary.opacity(0.06) : Color.clear)
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProjectView: View {
    @ObservedObject var client: DaemonClient
    let project: TofyProject
    let viewMode: String
    let keyboardSelectedServiceId: String?
    let onServiceSelected: (TofyService) -> Void
    
    @State private var tableWidth: CGFloat = 800
    
    var body: some View {
        VStack(spacing: 28) {
            // Project Status Hero
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(project.name)")
                        .scaledFont(size: 28, weight: .black, design: .rounded)
                        .foregroundColor(.primary.opacity(0.95))
                    
                    Text("\(project.services.count) Services Running")
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundColor(.secondary.opacity(0.6))
                        .tracking(0.5)
                }
                Spacer()
                ControlButtons(client: client, project: project)
            }
            .padding(.horizontal, 28)

            // Services List/Grid/Table
            if viewMode == "grid" {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                    ForEach(project.services) { service in
                        ServiceCard(service: service, isKeyboardSelected: service.id == keyboardSelectedServiceId) {
                            onServiceSelected(service)
                        }
                    }
                }
                .padding(.horizontal, 20)
            } else if viewMode == "table" {
                VStack(spacing: 0) {
                    let showPID = tableWidth > 450
                    let showURL = tableWidth > 550
                    let showUptimeRestarts = tableWidth > 650

                    // Table Header
                    HStack(spacing: 12) {
                        Text("ST").frame(width: 20, alignment: .center)
                        Text("NAME").frame(width: 140, alignment: .leading)
                        
                        if showPID {
                            Text("PID").frame(width: 50, alignment: .leading)
                        }
                        
                        if showURL {
                            Text("URL").frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                        }
                        
                        if showUptimeRestarts {
                            Text("UPTIME").frame(width: 60, alignment: .leading)
                            Text("RESTARTS").frame(width: 60, alignment: .trailing)
                        }
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    
                    ForEach(project.services) { service in
                        ServiceTableRow(
                            service: service,
                            showPID: showPID,
                            showURL: showURL,
                            showUptimeRestarts: showUptimeRestarts,
                            isKeyboardSelected: service.id == keyboardSelectedServiceId
                        ) {
                            onServiceSelected(service)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { tableWidth = geo.size.width }
                            .onChange(of: geo.size.width) { newWidth in
                                tableWidth = newWidth
                            }
                    }
                )
            } else {
                VStack(spacing: 14) {
                    ForEach(project.services) { service in
                        ServiceCard(service: service, isKeyboardSelected: service.id == keyboardSelectedServiceId) {
                            onServiceSelected(service)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
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
                    .frame(width: 38, height: 38)
                    .background(
                        ZStack {
                            Circle().fill(isRunning ? Color.red : Color.green).opacity(0.85)
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        }
                    )
                    .shadow(color: (isRunning ? Color.red : Color.green).opacity(0.4), radius: 12, y: 5)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: { client.fetchStatus() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.6))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.primary.opacity(0.04)))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ServiceCard: View {
    let service: TofyService
    let isKeyboardSelected: Bool
    let onDoubleTap: () -> Void
    @State private var isPulsing = false
    
    var body: some View {
        let isRunning = service.actualState == "running"
        HStack(spacing: 16) {
            // Service Icon with Pulse
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isRunning ? Color.green.opacity(0.1) : Color.primary.opacity(0.03))
                    .frame(width: 36, height: 36)
                
                Image(systemName: serviceIcon(service.id))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isRunning ? .green : .primary.opacity(0.3))
                
                if isRunning {
                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .opacity(isPulsing ? 0 : 0.8)
                        .onAppear {
                            withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                                isPulsing = true
                            }
                        }
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .scaledFont(size: 14, weight: .bold, design: .rounded)
                    .foregroundColor(.primary.opacity(0.9)  )
                    .onTapGesture(count: 2, perform: onDoubleTap)
                
                HStack(spacing: 8) {
                    if let pid = service.pid {
                        Text("PID \(String(pid))")
                            .scaledFont(size: 9, weight: .bold, design: .monospaced)
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    
                    if isRunning, let uptime = service.uptimeSeconds {
                        Text("•")
                            .scaledFont(size: 8)
                            .foregroundColor(.secondary.opacity(0.3))
                        Text(formatUptime(uptime))
                            .scaledFont(size: 9, weight: .bold, design: .monospaced)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }

                if let urlString = service.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "safari")
                                .font(.system(size: 9))
                            Text(urlString.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: ""))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .underline()
                        }
                        .foregroundColor(.blue.opacity(0.6))
                        .padding(.top, 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if service.hasGhostProcesses {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text("DUPLICATE INSTANCES RUNNING")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundColor(.orange)
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            // Status Indicator
            HStack(spacing: 8) {
                if service.restartCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(service.restartCount)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.orange.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }

                if isRunning {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: Color.green.opacity(0.5), radius: 3)
                        
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.green.opacity(0.8))
                            .tracking(0.5)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.05))
                    .clipShape(Capsule())
                } else {
                    StatusBadge(status: service.actualState)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                SidebarBlurView(material: .selection, blendingMode: .withinWindow)
                    .opacity(isRunning ? 0.35 : 0.1)
                
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isKeyboardSelected ? Color.blue : (isRunning ? Color.green.opacity(0.2) : Color.primary.opacity(0.1)), lineWidth: isKeyboardSelected ? 2 : 0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(isRunning ? 0.12 : 0.05), radius: 15, y: 8)
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
        let color: Color = status == "failed" ? .red : .secondary
        
        Text(status.uppercased())
            .font(.system(size: 9, weight: .black))
            .foregroundColor(color.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}
extension TofyProject: Identifiable {}

struct ServiceTableRow: View {
    let service: TofyService
    let showPID: Bool
    let showURL: Bool
    let showUptimeRestarts: Bool
    let isKeyboardSelected: Bool
    let onDoubleTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        let isRunning = service.actualState == "running"
        
        HStack(spacing: 12) {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: (isRunning ? Color.green : Color.red).opacity(0.5), radius: 3)
                .frame(width: 20, alignment: .center)
            Text(service.name)
                .scaledFont(size: 13, weight: .bold, design: .rounded)
                .foregroundColor(.primary.opacity(0.9))
                .frame(width: 140, alignment: .leading)
                .onTapGesture(count: 2, perform: onDoubleTap)
            
            if showPID {
                if let pid = service.pid {
                    Text(String(pid))
                        .scaledFont(size: 11, weight: .medium, design: .monospaced)
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 50, alignment: .leading)
                } else {
                    Text("-")
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(width: 50, alignment: .leading)
                }
            }
            
            if showURL {
                if let urlString = service.url, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Text(urlString.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: ""))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .underline()
                            .foregroundColor(.blue.opacity(0.7))
                            .lineLimit(1)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("-")
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer()
            }
            
            if showUptimeRestarts {
                if isRunning, let uptime = service.uptimeSeconds {
                    Text(formatUptime(uptime))
                        .scaledFont(size: 11, weight: .medium, design: .monospaced)
                        .foregroundColor(.secondary.opacity(0.6))
                        .frame(width: 60, alignment: .leading)
                } else {
                    Text("-")
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(width: 60, alignment: .leading)
                }
                
                if service.restartCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(service.restartCount)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.orange.opacity(0.8))
                    .frame(width: 60, alignment: .trailing)
                } else {
                    Text("-")
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(width: 60, alignment: .trailing)
                }
            }
            
            if service.hasGhostProcesses {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isKeyboardSelected ? Color.blue.opacity(0.15) : (Color.primary.opacity(isHovering ? 0.04 : 0.0)))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private func formatUptime(_ seconds: UInt64) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%dh %dm", h, m) : String(format: "%dm %ds", m, s)
    }
}

struct ServiceDetailsView: View {
    @ObservedObject var client: DaemonClient
    let projectId: String
    let service: TofyService
    let onClose: () -> Void
    
    @State private var logs: [String] = []
    @State private var timer: Timer? = nil
    @State private var isPollingLogs = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .scaledFont(size: 24, weight: .bold, design: .rounded)
                        .foregroundColor(.primary)
                    
                    HStack {
                        StatusBadge(status: service.actualState)
                        if let pid = service.pid {
                            Text("PID: \(pid)")
                                .scaledFont(size: 11, weight: .medium, design: .monospaced)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.bottom, 10)
            
            Divider()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Service Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Details")
                            .scaledFont(size: 14, weight: .bold, design: .rounded)
                            .foregroundColor(.primary.opacity(0.8))
                        
                        HStack(spacing: 40) {
                            DetailItem(title: "Restarts", value: "\(service.restartCount)")
                            if let uptime = service.uptimeSeconds {
                                DetailItem(title: "Uptime", value: formatUptime(uptime))
                            } else {
                                DetailItem(title: "Uptime", value: "-")
                            }
                            if let urlString = service.url {
                                DetailItem(title: "URL", value: urlString, isLink: true)
                            }
                        }
                    }
                    
                    // Ghost Processes
                    if !service.ghostProcesses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Duplicate Instances Detected")
                                    .scaledFont(size: 14, weight: .bold, design: .rounded)
                                    .foregroundColor(.orange)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(service.ghostProcesses) { ghost in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("PID: \(ghost.pid)")
                                                .scaledFont(size: 12, weight: .bold, design: .monospaced)
                                            Text("RAM: \(ghost.memoryBytes / 1024 / 1024) MB • CPU: \(String(format: "%.1f", ghost.cpuPercent))%")
                                                .scaledFont(size: 10)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            client.killGhostProcess(pid: ghost.pid)
                                        }) {
                                            Text("Kill Process")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.red.opacity(0.8))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(10)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Live Logs
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Live Logs")
                                .scaledFont(size: 14, weight: .bold, design: .rounded)
                                .foregroundColor(.primary.opacity(0.8))
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .opacity(isPollingLogs ? 1.0 : 0.3)
                            Text("LIVE")
                                .scaledFont(size: 9, weight: .black)
                                .foregroundColor(.secondary)
                        }
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    if logs.isEmpty {
                                        Text("No logs available")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary.opacity(0.5))
                                            .padding(.top, 60)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                    } else {
                                        ForEach(Array(logs.enumerated()), id: \.offset) { index, line in
                                            Text(line)
                                                .scaledFont(size: 10, design: .monospaced)
                                                .foregroundColor(.primary.opacity(0.85))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(index)
                                        }
                                    }
                                }
                                .padding(10)
                            }
                            .frame(height: 240)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                            .onChange(of: logs) { _ in
                                if !logs.isEmpty {
                                    proxy.scrollTo(logs.count - 1, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .padding(30)
        .padding(.bottom, 24)
        .background(SidebarBlurView(material: .hudWindow, blendingMode: .behindWindow).opacity(0.85))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.15), radius: 30, y: -10)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear { startLogPolling() }
        .onDisappear { stopLogPolling() }
    }
    
    func startLogPolling() {
        isPollingLogs = true
        fetchLogs()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.fetchLogs()
        }
    }
    
    func stopLogPolling() {
        isPollingLogs = false
        timer?.invalidate()
        timer = nil
    }
    
    func fetchLogs() {
        client.fetchLogs(projectId: projectId, serviceId: service.id) { result in
            switch result {
            case .success(let fetchedLogs):
                self.logs = fetchedLogs
            case .failure:
                break
            }
        }
    }
    
    private func formatUptime(_ seconds: UInt64) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return h > 0 ? String(format: "%dh %dm", h, m) : String(format: "%dm %ds", m, s)
    }
}

struct DetailItem: View {
    let title: String
    let value: String
    var isLink: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .scaledFont(size: 10, weight: .bold)
                .foregroundColor(.secondary.opacity(0.6))
            
            if isLink, let url = URL(string: value) {
                Link(destination: url) {
                    Text(value.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: ""))
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.blue.opacity(0.8))
                        .underline()
                }
            } else {
                Text(value)
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct ScaledFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    @AppStorage("fontSizeMultiplier") var fontSizeMultiplier: Double = 1.0
    
    func body(content: Content) -> some View {
        content.font(.system(size: size * CGFloat(fontSizeMultiplier), weight: weight, design: design))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        self.modifier(ScaledFontModifier(size: size, weight: weight, design: design))
    }
}


