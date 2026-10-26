fn main() {
    let _ = std::fs::create_dir_all("resources");
    tauri_build::build()
}
