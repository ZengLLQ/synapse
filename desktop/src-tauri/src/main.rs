// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::net::TcpStream;
use std::process::{Child, Command};
use std::sync::{Arc, Mutex};
use std::time::Duration;
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
fn check_backend_health(state: tauri::State<'_, Arc<Mutex<BackendState>>>) -> Result<bool, String> {
    let port = {
        let guard = state.lock().map_err(|e| e.to_string())?;
        guard.config.port
    };
    // Check if the loopback port is actively accepting TCP connections
    let is_connected = TcpStream::connect_timeout(
        &format!("127.0.0.1:{}", port).parse().unwrap(),
        Duration::from_millis(300),
    ).is_ok();
    Ok(is_connected)
}

fn find_project_toml_recursive(dir: &std::path::Path, max_depth: usize) -> Option<std::path::PathBuf> {
    if max_depth == 0 || !dir.exists() {
        return None;
    }
    if dir.join("Project.toml").exists() && dir.join("src").exists() {
        return Some(dir.to_path_buf());
    }
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if let Some(found) = find_project_toml_recursive(&path, max_depth - 1) {
                    return Some(found);
                }
            }
        }
    }
    None
}

fn find_backend_dir() -> std::path::PathBuf {
    // 1. Explicit environment variable override
    if let Ok(dir) = std::env::var("SYNAPSE_BACKEND_DIR") {
        let p = std::path::PathBuf::from(dir);
        if p.exists() && p.join("Project.toml").exists() {
            return p;
        }
    }

    // 2. Resource directory next to current executable
    if let Ok(exe) = std::env::current_exe() {
        if let Some(exe_dir) = exe.parent() {
            // Direct candidates
            let direct = [
                exe_dir.join("backend"),
                exe_dir.join("resources").join("backend"),
            ];
            for d in direct {
                if d.join("Project.toml").exists() && d.join("src").exists() {
                    return d;
                }
            }

            // Check macOS bundle structure: Contents/Resources/backend
            if let Some(contents_dir) = exe_dir.parent() {
                let mac_res = contents_dir.join("Resources");
                if mac_res.join("backend").join("Project.toml").exists() {
                    return mac_res.join("backend");
                }
                if mac_res.join("Project.toml").exists() && mac_res.join("src").exists() {
                    return mac_res;
                }
                if let Some(found) = find_project_toml_recursive(&mac_res, 4) {
                    return found;
                }
            }

            // Check resources folder
            if let Some(found) = find_project_toml_recursive(&exe_dir.join("resources"), 5) {
                return found;
            }
            if let Some(found) = find_project_toml_recursive(exe_dir, 3) {
                return found;
            }
        }
    }

    // 3. Development candidates relative to current working directory
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

fn find_julia() -> std::path::PathBuf {
    // 1. Explicit environment variable override
    if let Ok(bin) = std::env::var("JULIA_BIN") {
        let p = std::path::PathBuf::from(bin);
        if p.exists() {
            return p;
        }
    }
    if let Ok(dir) = std::env::var("JULIA_PATH") {
        let p = std::path::PathBuf::from(dir);
        let cand1 = p.join("julia.exe");
        if cand1.exists() {
            return cand1;
        }
        let cand2 = p.join("julia");
        if cand2.exists() {
            return cand2;
        }
    }

    // 2. Standard user paths on Windows
    #[cfg(target_os = "windows")]
    {
        if let Ok(userprofile) = std::env::var("USERPROFILE") {
            let juliaup = std::path::PathBuf::from(&userprofile).join(".juliaup").join("bin").join("julia.exe");
            if juliaup.exists() {
                return juliaup;
            }
        }
        if let Ok(localappdata) = std::env::var("LOCALAPPDATA") {
            let programs = std::path::PathBuf::from(&localappdata).join("Programs");
            if let Ok(entries) = std::fs::read_dir(&programs) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    let name = entry.file_name().to_string_lossy().to_string();
                    if name.starts_with("Julia") || name.starts_with("julia") {
                        let candidate = path.join("bin").join("julia.exe");
                        if candidate.exists() {
                            return candidate;
                        }
                    }
                }
            }
        }
        let prog_files = [
            std::env::var("ProgramFiles").unwrap_or_else(|_| "C:\\Program Files".to_string()),
            std::env::var("ProgramFiles(x86)").unwrap_or_else(|_| "C:\\Program Files (x86)".to_string()),
        ];
        for pf in &prog_files {
            let pf_path = std::path::PathBuf::from(pf);
            if let Ok(entries) = std::fs::read_dir(&pf_path) {
                for entry in entries.flatten() {
                    let path = entry.path();
                    let name = entry.file_name().to_string_lossy().to_string();
                    if name.starts_with("Julia") || name.starts_with("julia") {
                        let candidate = path.join("bin").join("julia.exe");
                        if candidate.exists() {
                            return candidate;
                        }
                    }
                }
            }
        }
    }

    // 3. Standard paths on macOS / Linux
    #[cfg(not(target_os = "windows"))]
    {
        let mac_candidates = [
            "/opt/homebrew/bin/julia",
            "/usr/local/bin/julia",
            "/usr/bin/julia",
        ];
        for c in mac_candidates {
            let p = std::path::PathBuf::from(c);
            if p.exists() {
                return p;
            }
        }
        if let Ok(home) = std::env::var("HOME") {
            let juliaup = std::path::PathBuf::from(&home).join(".juliaup").join("bin").join("julia");
            if juliaup.exists() {
                return juliaup;
            }
        }
        if let Ok(entries) = std::fs::read_dir("/Applications") {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("Julia") && name.ends_with(".app") {
                    let candidate = entry.path().join("Contents").join("Resources").join("julia").join("bin").join("julia");
                    if candidate.exists() {
                        return candidate;
                    }
                }
            }
        }
    }

    std::path::PathBuf::from("julia")
}

fn start_julia_backend(token: &str, port: u16) -> Option<Child> {
    // Check if loopback port is already responding (e.g. dev server already launched)
    if let Ok(_stream) = TcpStream::connect_timeout(
        &format!("127.0.0.1:{}", port).parse().unwrap(),
        Duration::from_millis(200),
    ) {
        println!("Julia backend port {} is already active on 127.0.0.1; attaching without re-spawn.", port);
        return None;
    }

    let backend_dir = find_backend_dir();
    let julia_bin = find_julia();
    let project_arg = format!("--project={}", backend_dir.display());

    println!("Starting Julia backend: {:?} with project: {:?}", julia_bin, backend_dir);

    let julia_cmd = Command::new(&julia_bin)
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
    let session_token = std::env::var("SYNAPSE_SESSION_TOKEN")
        .unwrap_or_else(|_| uuid::Uuid::new_v4().to_string());
    let port: u16 = std::env::var("SYNAPSE_PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(8765);
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_backend_dir_finds_real_project() {
        let backend = find_backend_dir();
        assert!(backend.exists(), "Backend directory must exist: {:?}", backend);
        assert!(backend.join("Project.toml").exists(), "Project.toml must exist in {:?}", backend);
    }

    #[test]
    fn test_find_julia_returns_non_empty() {
        let julia = find_julia();
        assert!(!julia.as_os_str().is_empty(), "Julia binary path must not be empty");
    }

    #[test]
    fn test_find_project_toml_recursive_nested() {
        let temp_dir = std::env::temp_dir().join(format!("synapse_test_{}", uuid::Uuid::new_v4()));
        let nested = temp_dir.join("a").join("b").join("c");
        std::fs::create_dir_all(&nested.join("src")).unwrap();
        std::fs::write(nested.join("Project.toml"), "name = \"Test\"\n").unwrap();

        let found = find_project_toml_recursive(&temp_dir, 4);
        assert_eq!(found, Some(nested));

        let _ = std::fs::remove_dir_all(&temp_dir);
    }
}

