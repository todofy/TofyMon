# TofyMon 🚀

A premium, native macOS service supervisor for managing local project process groups. 

TofyMon consists of three parts:
1.  **TofyDaemon**: A Rust-powered supervisor that manages process lifecycles via Unix sockets.
2.  **TofyCLI**: A command-line tool to register projects and control services.
3.  **TofyUI**: A glassmorphism-inspired SwiftUI dashboard for real-time monitoring.

---

## 🚀 How to Run

Follow these steps in order to get the full TofyMon experience:

### 1. Build the Core Components
First, build the Rust daemon and CLI:
```bash
cargo build --workspace
```

### 2. Start the Supervisor (Daemon)
The daemon must be running in the background to manage services.
```bash
./target/debug/daemon
```
*Tip: Keep this terminal open or run it as a background service.*

### 3. Register a Project (e.g., Iris)
Use the CLI to tell TofyMon which services to monitor by pointing it to a `tofy.config.json` file:
```bash
./target/debug/tofy start -c path/to/your/tofy.config.json
```

### 4. Launch the Dashboard
Open the **`ui`** folder in **Xcode** and press **Cmd + R**. 
*   The dashboard will automatically connect to the running daemon.
*   Toggle the **Sidebar** (top-right icon) to switch between projects.
*   Monitor real-time health squares and individual service stats.

---

## 🛠 Features
- **Process Group Management**: Automatically handles children processes and prevents zombies.
- **IPC over Unix Sockets**: High-performance, local-only communication.
- **Glassmorphism UI**: Beautiful, translucent macOS dashboard with SF Pro typography.
- **Real-time Health Grid**: Visual square-grid indicating status across all services at a glance.
- **Zero-Downtime Migration**: Drop-in replacement for legacy shell-based watchdogs.
