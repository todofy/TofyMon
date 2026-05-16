use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::process::Command;

#[derive(Parser)]
#[command(name = "tofy")]
#[command(about = "TofyDaemon CLI")]
struct Cli {
    #[arg(short, long, global = true)]
    verbose: bool,
    
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Start {
        config: PathBuf,
    },
    Stop {
        config: PathBuf,
    },
    Status {
        config: PathBuf,
        #[arg(long)]
        json: bool,
    },
}

fn resolve_config_path(path: PathBuf) -> anyhow::Result<PathBuf> {
    let abs_path = std::fs::canonicalize(&path).unwrap_or(path.clone());
    if abs_path.is_dir() {
        let config_file = abs_path.join("tofy.config.json");
        if config_file.exists() {
            return Ok(config_file);
        }
        anyhow::bail!("No tofy.config.json found in directory: {:?}", abs_path);
    }
    if !abs_path.exists() {
        anyhow::bail!("Config file not found: {:?}", abs_path);
    }
    Ok(abs_path)
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    
    let socket_path = std::env::var("HOME")
        .map(|h| PathBuf::from(h).join("Library/Application Support/TofyDaemon/tofy.sock"))
        .unwrap_or_else(|_| PathBuf::from("/tmp/tofy.sock"));
        
    let socket_str = socket_path.to_string_lossy().to_string();
    if cli.verbose {
        println!("🔍 Socket path: {}", socket_str);
    }

    match cli.command {
        Commands::Start { config } => {
            let config_path = resolve_config_path(config)?;
            let mut json_body: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(&config_path)?)?;
            
            let config_dir = config_path.parent().unwrap_or(std::path::Path::new(".")).to_path_buf();
            
            // 1. Resolve 'root' to absolute
            let root_path = if let Some(root_str) = json_body["root"].as_str() {
                let abs = config_dir.join(root_str);
                std::fs::canonicalize(&abs).unwrap_or(abs)
            } else {
                config_dir.clone()
            };
            json_body["root"] = serde_json::Value::String(root_path.to_string_lossy().to_string());

            // 2. Resolve service-level paths (cwd, log) relative to root
            if let Some(services) = json_body["services"].as_array_mut() {
                for svc in services {
                    if let Some(cwd) = svc["cwd"].as_str() {
                        let abs_cwd = root_path.join(cwd);
                        svc["cwd"] = serde_json::Value::String(abs_cwd.to_string_lossy().to_string());
                    }
                    if let Some(log) = svc["log"].as_str() {
                        let abs_log = root_path.join(log);
                        svc["log"] = serde_json::Value::String(abs_log.to_string_lossy().to_string());
                    }
                }
            }

            let id = json_body["id"].as_str().ok_or_else(|| anyhow::anyhow!("Missing 'id' in config"))?.to_string();
            let final_json = serde_json::to_string(&json_body)?;

            if cli.verbose {
                println!("📂 Config path: {:?}", config_path);
                println!("📝 Sending JSON: {}", final_json);
            }

            // 1. Register
            let reg_output = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg("-X")
                .arg("POST")
                .arg("-H")
                .arg("Content-Type: application/json")
                .arg("-d")
                .arg(&final_json)
                .arg("http://localhost/v1/projects")
                .output()?;
            
            if cli.verbose {
                println!("📡 Register response: {}", String::from_utf8_lossy(&reg_output.stdout));
            }

            // 2. Start
            let url = format!("http://localhost/v1/projects/{}/start", id);
            let start_output = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg("-X")
                .arg("POST")
                .arg(&url)
                .output()?;

            if cli.verbose {
                println!("🚀 Start response: {}", String::from_utf8_lossy(&start_output.stdout));
            }

            println!("🚀 Started project: {}", id);
        }
        Commands::Stop { config } => {
            let config_path = resolve_config_path(config)?;
            let json_body: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(&config_path)?)?;
            let id = json_body["id"].as_str().ok_or_else(|| anyhow::anyhow!("Missing 'id' in config"))?.to_string();

            if cli.verbose {
                println!("🛑 Stopping project: {}", id);
            }

            let url = format!("http://localhost/v1/projects/{}/stop", id);
            let output = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg("-X")
                .arg("POST")
                .arg(&url)
                .output()?;

            if cli.verbose {
                println!("🛑 Stop response: {}", String::from_utf8_lossy(&output.stdout));
            }

            println!("🛑 Stopped project: {}", id);
        }
        Commands::Status { config, json: _ } => {
            let config_path = resolve_config_path(config)?;
            let json_body: serde_json::Value = serde_json::from_str(&std::fs::read_to_string(&config_path)?)?;
            let id = json_body["id"].as_str().ok_or_else(|| anyhow::anyhow!("Missing 'id' in config"))?.to_string();

            let url = format!("http://localhost/v1/projects/{}", id);
            let output = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg(&url)
                .output()?;

            let response = String::from_utf8_lossy(&output.stdout);
            println!("{}", response);
        }
    }

    Ok(())
}
