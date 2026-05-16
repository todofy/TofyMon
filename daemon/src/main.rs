mod api;
pub mod config;
mod process;
pub mod state;
mod store;
mod supervisor;

use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt::init();
    tracing::info!("Starting TofyDaemon");

    let supervisor = Arc::new(Mutex::new(supervisor::Supervisor::new()));
    
    let socket_path = std::env::var("HOME")
        .map(|h| PathBuf::from(h).join("Library/Application Support/TofyDaemon/tofy.sock"))
        .unwrap_or_else(|_| PathBuf::from("/tmp/tofy.sock"));

    if let Some(parent) = socket_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    api::start_api(socket_path, supervisor).await?;

    Ok(())
}
