use std::collections::HashMap;
use crate::config::{ProjectConfig, ServiceConfig};
use crate::state::{ActualState, DesiredState, ProjectState, ServiceState};
use crate::process::ProcessHandle;
use anyhow::Result;

pub struct Supervisor {
    projects: HashMap<String, ProjectSupervisor>,
}

pub struct ProjectSupervisor {
    config: ProjectConfig,
    services: HashMap<String, ServiceContext>,
}

struct ServiceContext {
    config: ServiceConfig,
    state: ServiceState,
    handle: Option<ProcessHandle>,
}

impl Supervisor {
    pub fn new() -> Self {
        Self {
            projects: HashMap::new(),
        }
    }

    pub fn register(&mut self, config: ProjectConfig) {
        let mut services = HashMap::new();
        for svc in &config.services {
            let state = ServiceState {
                id: svc.id.clone(),
                name: svc.name.clone(),
                desired_state: DesiredState::Stopped,
                actual_state: ActualState::Stopped,
                pid: None,
                process_group_id: None,
                uptime_seconds: None,
                restart_count: 0,
                last_exit_code: None,
                last_started_at: None,
                last_healthy_at: None,
                cpu_percent: None,
                memory_bytes: None,
                latest_log_line: None,
                url: svc.url.clone(),
                has_ghost_processes: false,
                ghost_processes: Vec::new(),
            };
            services.insert(svc.id.clone(), ServiceContext {
                config: svc.clone(),
                state,
                handle: None,
            });
        }

        let ps = ProjectSupervisor {
            config: config.clone(),
            services,
        };
        self.projects.insert(config.id.clone(), ps);
    }

    pub fn start_project(&mut self, id: &str) -> Result<()> {
        if let Some(ps) = self.projects.get_mut(id) {
            for (svc_id, ctx) in ps.services.iter_mut() {
                if ctx.config.enabled {
                    ctx.state.desired_state = DesiredState::Running;
                    
                    if ctx.handle.is_some() {
                        continue;
                    }

                    if let Some(ref cmd) = ctx.config.command {
                        let spawn_cwd = ctx.config.cwd.as_ref().or(Some(&ps.config.root));
                        match ProcessHandle::spawn(
                            cmd,
                            spawn_cwd,
                            &ctx.config.env,
                            ctx.config.stdout_log.as_ref().or(ctx.config.log.as_ref()),
                            ctx.config.stderr_log.as_ref().or(ctx.config.log.as_ref()),
                        ) {
                            Ok(handle) => {
                                let pid = handle.pid();
                                ctx.state.actual_state = ActualState::Running;
                                ctx.state.pid = Some(pid);
                                ctx.state.process_group_id = Some(pid as i32);
                                ctx.handle = Some(handle);
                                tracing::info!("🚀 Started service {} (pid {})", svc_id, pid);
                            }
                            Err(e) => {
                                tracing::error!(
                                    "❌ Failed to start service {}: {} | Cmd: {:?} | Cwd: {:?}",
                                    svc_id, e, cmd, spawn_cwd
                                );
                                ctx.state.actual_state = ActualState::Failed;
                            }
                        }
                    }
                }
            }
        }
        Ok(())
    }

    pub fn stop_project(&mut self, id: &str) -> Result<()> {
        if let Some(ps) = self.projects.get_mut(id) {
            for (_, ctx) in ps.services.iter_mut() {
                ctx.state.desired_state = DesiredState::Stopped;
                if let Some(mut handle) = ctx.handle.take() {
                    let _ = handle.stop();
                    let _ = handle.kill();
                    ctx.state.actual_state = ActualState::Stopped;
                    ctx.state.pid = None;
                    ctx.state.process_group_id = None;
                }
            }
        }
        Ok(())
    }

    pub fn get_project_state(&self, id: &str) -> Option<ProjectState> {
        let ps = self.projects.get(id)?;
        
        let mut running_count = 0;
        let mut failed_count = 0;
        let mut services = Vec::new();

        use sysinfo::System;
        let mut sys = System::new_all();
        sys.refresh_all();

        for ctx in ps.services.values() {
            match ctx.state.actual_state {
                ActualState::Running => running_count += 1,
                ActualState::Failed => failed_count += 1,
                _ => {}
            }
            
            let mut state = ctx.state.clone();
            
            // Ghost process detection
            if let Some(ref cmd) = ctx.config.command {
                if !cmd.is_empty() {
                    let exe_name = &cmd[0];
                    let mut count = 0;
                    let mut ghosts = Vec::new();
                    for process in sys.processes().values() {
                        if let Some(exe) = process.exe() {
                            if exe.to_string_lossy().contains(exe_name) {
                                // If it's not the one we spawned
                                if state.pid != Some(process.pid().as_u32()) {
                                    count += 1;
                                    ghosts.push(crate::state::GhostProcess {
                                        pid: process.pid().as_u32(),
                                        memory_bytes: process.memory(),
                                        cpu_percent: process.cpu_usage(),
                                        run_time: process.run_time(),
                                    });
                                }
                            }
                        }
                    }
                    state.has_ghost_processes = count > 0;
                    state.ghost_processes = ghosts;
                }
            }

            services.push(state);
        }

        Some(ProjectState {
            id: ps.config.id.clone(),
            name: ps.config.name.clone(),
            config_path: "".to_string(), // TODO
            root: ps.config.root.to_string_lossy().to_string(),
            desired_state: DesiredState::Running,
            actual_state: ActualState::Running,
            service_count: ps.services.len(),
            running_count,
            failed_count,
            services,
        })
    }

    pub fn list_projects(&self) -> Vec<ProjectState> {
        let mut results = Vec::new();
        for id in self.projects.keys() {
            if let Some(state) = self.get_project_state(id) {
                results.push(state);
            }
        }
        results
    }
}
