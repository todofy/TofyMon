use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectConfig {
    pub schema: String,
    pub id: String,
    pub name: String,
    pub root: PathBuf,
    #[serde(default)]
    pub keep_awake: bool,
    #[serde(default)]
    pub services: Vec<ServiceConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceConfig {
    pub id: String,
    pub name: String,
    pub command: Option<Vec<String>>,
    pub shell: Option<String>,
    pub cwd: Option<PathBuf>,
    #[serde(default)]
    pub env: HashMap<String, String>,
    #[serde(default)]
    pub env_files: Vec<PathBuf>,
    pub log: Option<PathBuf>,
    pub stdout_log: Option<PathBuf>,
    pub stderr_log: Option<PathBuf>,
    #[serde(default)]
    pub depends_on: Vec<String>,
    pub health: Option<HealthCheck>,
    pub restart: Option<RestartConfig>,
    #[serde(default = "default_true")]
    pub enabled: bool,
}

fn default_true() -> bool {
    true
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "camelCase")]
pub enum HealthCheck {
    Process,
    Tcp { host: String, port: u16 },
    Http { url: String, expected_status: Option<u16> },
    Command { command: Vec<String>, timeout_seconds: Option<u64> },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RestartConfig {
    #[serde(default)]
    pub policy: RestartPolicy,
    #[serde(default = "default_max_attempts")]
    pub max_attempts: u32,
    #[serde(default = "default_delay_seconds")]
    pub delay_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum RestartPolicy {
    #[default]
    Always,
    OnFailure,
    Never,
}

fn default_max_attempts() -> u32 { 3 }
fn default_delay_seconds() -> u64 { 5 }
