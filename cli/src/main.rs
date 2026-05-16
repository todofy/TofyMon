use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::process::Command;

#[derive(Parser)]
#[command(name = "tofy")]
#[command(about = "TofyDaemon CLI")]
struct Cli {
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

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    
    let socket_path = std::env::var("HOME")
        .map(|h| PathBuf::from(h).join("Library/Application Support/TofyDaemon/tofy.sock"))
        .unwrap_or_else(|_| PathBuf::from("/tmp/tofy.sock"));
        
    let socket_str = socket_path.to_string_lossy().to_string();

    match cli.command {
        Commands::Start { config } => {
            let abs_path = std::fs::canonicalize(&config).unwrap_or(config);
            let json_body = std::fs::read_to_string(&abs_path).unwrap_or_else(|_| "{}".to_string());
            let parsed: serde_json::Value = serde_json::from_str(&json_body).unwrap_or(serde_json::json!({}));
            let id = parsed["id"].as_str().unwrap_or("unknown").to_string();

            // 1. Register
            let _ = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg("-X")
                .arg("POST")
                .arg("-H")
                .arg("Content-Type: application/json")
                .arg("-d")
                .arg(&json_body)
                .arg("http://localhost/v1/projects")
                .output()?;

            // 2. Start
            let url = format!("http://localhost/v1/projects/{}/start", id);
            let _ = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg("-X")
                .arg("POST")
                .arg(&url)
                .output()?;

            println!("Started {}", id);
        }
        Commands::Stop { config } => {
            let abs_path = std::fs::canonicalize(&config).unwrap_or(config);
            let json_body = std::fs::read_to_string(&abs_path).unwrap_or_else(|_| "{}".to_string());
            let parsed: serde_json::Value = serde_json::from_str(&json_body).unwrap_or(serde_json::json!({}));
            let id = parsed["id"].as_str().unwrap_or("unknown").to_string();

            let url = format!("http://localhost/v1/projects/{}/stop", id);
            let _ = Command::new("curl")
                .arg("-s")
                .arg("--unix-socket")
                .arg(&socket_str)
                .arg("-X")
                .arg("POST")
                .arg(&url)
                .output()?;

            println!("Stopped {}", id);
        }
        Commands::Status { config, json: _ } => {
            let abs_path = std::fs::canonicalize(&config).unwrap_or(config);
            let json_body = std::fs::read_to_string(&abs_path).unwrap_or_else(|_| "{}".to_string());
            let parsed: serde_json::Value = serde_json::from_str(&json_body).unwrap_or(serde_json::json!({}));
            let id = parsed["id"].as_str().unwrap_or("unknown").to_string();

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
