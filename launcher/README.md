# SpringRP

Architecture-first Windows launcher shell built with Tauri 2, Vue 3,
TypeScript, Vite, Rust and WebView2.

This milestone contains boundaries and contracts only. It does not authenticate
players, download Minecraft, execute Java or include `NewLaunch.jar`.

## Prerequisites

- Windows 10 or newer with WebView2
- Node.js 20+
- Rust stable with the MSVC toolchain
- Microsoft C++ Build Tools and Windows SDK

## Development

```powershell
npm install
npm run tauri dev
```

Static checks:

```powershell
npm run build
cargo check --manifest-path src-tauri/Cargo.toml
```

Runtime configuration belongs in the Tauri app-data directory, not in the
repository. Copy the files from `config/*.example.toml` only when wiring the
configuration use cases.

See [docs/architecture.md](docs/architecture.md) for boundaries and extension
points.
