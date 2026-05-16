use axum::{
    extract::{Path, State},
    routing::{get, post},
    Json, Router,
};
use hyper_util::rt::{TokioExecutor, TokioIo};
use hyper_util::server::conn::auto::Builder;
use hyper_util::service::TowerToHyperService;
use std::sync::Arc;
use std::path::PathBuf;
use tokio::net::UnixListener;
use tokio::sync::Mutex;
use crate::supervisor::Supervisor;
use crate::config::ProjectConfig;
use crate::state::ProjectState;

type SharedState = Arc<Mutex<Supervisor>>;

pub async fn start_api(socket_path: PathBuf, supervisor: SharedState) -> anyhow::Result<()> {
    let app = Router::new()
        .route("/v1/projects", get(list_projects).post(register_project))
        .route("/v1/projects/{id}", get(get_project))
        .route("/v1/projects/{id}/start", post(start_project))
        .route("/v1/projects/{id}/stop", post(stop_project))
        .route("/v1/process/{pid}/kill", post(kill_process))
        .with_state(supervisor);

    let _ = std::fs::remove_file(&socket_path);
    let listener = UnixListener::bind(&socket_path)?;

    tracing::info!("Listening on {:?}", socket_path);

    loop {
        let (stream, _addr) = listener.accept().await?;
        let io = TokioIo::new(stream);
        let app = app.clone();
        
        tokio::spawn(async move {
            let hyper_service = TowerToHyperService::new(app);
            let res = Builder::new(TokioExecutor::new())
                .serve_connection(io, hyper_service)
                .await;
                
            if let Err(e) = res {
                let err_str = e.to_string();
                if !err_str.contains("error shutting down connection") {
                    tracing::error!("Error serving connection: {}", e);
                }
            }
        });
    }
}

async fn list_projects(
    State(state): State<SharedState>,
) -> Json<Vec<ProjectState>> {
    let sup = state.lock().await;
    Json(sup.list_projects())
}

async fn register_project(
    State(state): State<SharedState>,
    Json(config): Json<ProjectConfig>,
) -> Json<String> {
    let mut sup = state.lock().await;
    let id = config.id.clone();
    sup.register(config);
    Json(id)
}

async fn get_project(
    State(state): State<SharedState>,
    Path(id): Path<String>,
) -> Result<Json<ProjectState>, axum::http::StatusCode> {
    let sup = state.lock().await;
    match sup.get_project_state(&id) {
        Some(st) => Ok(Json(st)),
        None => Err(axum::http::StatusCode::NOT_FOUND),
    }
}

async fn start_project(
    State(state): State<SharedState>,
    Path(id): Path<String>,
) -> Result<(), axum::http::StatusCode> {
    let mut sup = state.lock().await;
    sup.start_project(&id).map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(())
}

async fn stop_project(
    State(state): State<SharedState>,
    Path(id): Path<String>,
) -> Result<(), axum::http::StatusCode> {
    let mut sup = state.lock().await;
    sup.stop_project(&id).map_err(|_| axum::http::StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(())
}

async fn kill_process(
    Path(pid): Path<u32>,
) -> Result<(), axum::http::StatusCode> {
    use sysinfo::{System, Pid};
    let mut sys = System::new_all();
    sys.refresh_all();
    if let Some(process) = sys.process(Pid::from_u32(pid)) {
        process.kill();
        Ok(())
    } else {
        Err(axum::http::StatusCode::NOT_FOUND)
    }
}
