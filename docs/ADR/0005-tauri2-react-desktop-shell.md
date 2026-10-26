# ADR 0005: Tauri 2 and React for Desktop Shell

## Status
Accepted

## Context
Synapse needs a cross-platform desktop UI capable of running locally on Windows, macOS, and Linux, with low resource consumption, responsive graph rendering, and deep OS integration.

## Decision
We chose **Tauri 2** (Rust shell) coupled with **React 18 + TypeScript + Vite + Tailwind CSS** for the desktop frontend.

## Rationale
- Electron binaries frequently consume >200MB of RAM at idle. Tauri utilizes the OS webview (WebView2 on Windows, WebKitGTK on Linux, WebKit on macOS), reducing bundle size to <15MB and idle memory to <40MB.
- Tauri 2 provides granular security permissions, restricting frontend capabilities strictly to window management and local engine process supervision.
- React and TypeScript provide a mature UI ecosystem with SVG/Canvas support for interactive evidence graph visualization, rich document reading layouts, and fast state management.

## Consequences
- The frontend acts strictly as a presentation and interaction layer; all domain decisions and persistence remain in Julia.
