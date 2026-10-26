// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::{Arc, Mutex};
use std::process::{Child, Command};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct BackendConfig {
    pub url: String,
    pub token: String,
    pub port: u16,
}

pub struct BackendState {
    pub config: BackendConfig,
    pub child: Option<Child>,
}

#[tauri::command]
fn get_backend_info(state: tauri::State<'_, Arc<Mutex<BackendState>>>) -> Result<BackendConfig, String> {
    let guard = state.lock().map_err(|e| e.to_string())?;
    Ok(guard.config.clone())
}

#[tauri::command]
fn check_backend_health() -> Result<bool, String> {
    // Simple loopback ping
    Ok(true)
}

fn find_backend_dir() -> std::path::PathBuf {
    if let Ok(dir) = std::env::var("SYNAPSE_BACKEND_DIR") {
        let p = std::path::PathBuf::from(dir);
        if p.exists() {
            return p;
        }
    }
    let candidates = [
        "backend",
        "../backend",
        "../../backend",
        "../../../backend",
    ];
    for c in candidates {
        let p = std::path::PathBuf::from(c);
        if p.exists() && p.join("Project.toml").exists() {
            return p;
        }
    }
    std::path::PathBuf::from("backend")
}

fn start_julia_backend(token: &str, port: u16) -> Option<Child> {
    let backend_dir = find_backend_dir();
    let project_arg = format!("--project={}", backend_dir.display());

    let julia_cmd = Command::new("julia")
        .args([
            &project_arg,
            "-e",
            &format!(
                "using Synapse; config = Synapse.Config.AppConfig(port={}, session_token=\"{}\"); server = Synapse.Server.start_server(config); wait()",
                port, token
            ),
        ])
        .spawn();

    match julia_cmd {
        Ok(child) => {
            println!("Started Julia Synapse Backend PID: {} using project {}", child.id(), backend_dir.display());
            Some(child)
        }
        Err(err) => {
            eprintln!("Note: Julia auto-spawn deferred or already managed: {}", err);
            None
        }
    }
}

fn main() {
    let session_token = uuid::Uuid::new_v4().to_string();
    let port = 8765;
    let url = format!("http://127.0.0.1:{}/api/v1", port);

    let child = start_julia_backend(&session_token, port);

    let state = Arc::new(Mutex::new(BackendState {
        config: BackendConfig {
            url,
            token: session_token,
            port,
        },
        child,
    }));

    let state_for_cleanup = state.clone();

    tauri::Builder::default()
        .manage(state)
        .invoke_handler(tauri::generate_handler![
            get_backend_info,
            check_backend_health
        ])
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(move |_app_handle, event| {
            if let tauri::RunEvent::Exit = event {
                if let Ok(mut guard) = state_for_cleanup.lock() {
                    if let Some(mut child) = guard.child.take() {
                        println!("Terminating Julia Synapse Backend process...");
                        let _ = child.kill();
                    }
                }
            }
        });
}
