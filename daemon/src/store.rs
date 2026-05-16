use std::path::{Path, PathBuf};
use std::fs;
use anyhow::{Context, Result};
// use uuid::Uuid;
use crate::config::ProjectConfig;

#[allow(dead_code)]
pub struct Store {
    base_dir: PathBuf,
}

#[allow(dead_code)]
impl Store {
    pub fn new() -> Result<Self> {
        let home = std::env::var("HOME").context("HOME not set")?;
        let base_dir = Path::new(&home).join("Library/Application Support/TofyDaemon");
        fs::create_dir_all(&base_dir)?;
        Ok(Self { base_dir })
    }

    pub fn save_project_config(&self, config: &ProjectConfig) -> Result<String> {
        let instance_id = config.id.clone();
        let project_dir = self.base_dir.join("projects").join(&instance_id);
        fs::create_dir_all(&project_dir)?;
        
        let path = project_dir.join("project.json");
        let temp_path = project_dir.join("project.json.tmp");
        
        let json = serde_json::to_string_pretty(config)?;
        fs::write(&temp_path, json)?;
        fs::rename(temp_path, path)?;
        
        Ok(instance_id)
    }

    pub fn load_project_configs(&self) -> Result<Vec<(String, ProjectConfig)>> {
        let mut configs = Vec::new();
        let projects_dir = self.base_dir.join("projects");
        if !projects_dir.exists() {
            return Ok(configs);
        }
        for entry in fs::read_dir(projects_dir)? {
            let entry = entry?;
            let instance_id = entry.file_name().into_string().unwrap();
            let path = entry.path().join("project.json");
            if path.exists() {
                let json = fs::read_to_string(&path)?;
                if let Ok(config) = serde_json::from_str(&json) {
                    configs.push((instance_id, config));
                }
            }
        }
        Ok(configs)
    }
}
