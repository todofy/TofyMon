use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ProjectState {
    pub id: String,
    pub name: String,
    pub config_path: String,
    pub root: String,
    pub desired_state: DesiredState,
    pub actual_state: ActualState,
    pub service_count: usize,
    pub running_count: usize,
    pub failed_count: usize,
    pub services: Vec<ServiceState>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceState {
    pub id: String,
    pub name: String,
    pub desired_state: DesiredState,
    pub actual_state: ActualState,
    pub pid: Option<u32>,
    pub process_group_id: Option<i32>,
    pub uptime_seconds: Option<u64>,
    pub restart_count: u32,
    pub last_exit_code: Option<i32>,
    pub last_started_at: Option<DateTime<Utc>>,
    pub last_healthy_at: Option<DateTime<Utc>>,
    pub cpu_percent: Option<f32>,
    pub memory_bytes: Option<u64>,
    pub latest_log_line: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum DesiredState {
    #[default]
    Stopped,
    Running,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum ActualState {
    #[default]
    Stopped,
    Starting,
    Running,
    Unhealthy,
    Restarting,
    Failed,
    Unknown,
}
