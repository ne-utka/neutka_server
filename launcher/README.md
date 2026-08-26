# SpringRP Launcher

SpringRP Launcher is a Windows desktop launcher for the SpringRP Minecraft
project. It is built with Tauri 2, Vue 3, TypeScript, Vite, Rust and WebView2.

The current version authenticates a Minecraft account, installs and updates the
SpringRP client distribution, downloads the matching Mojang runtime and starts
the Fabric game process from the local launcher interface.

## Microsoft authentication

The launcher uses the OAuth 2.0 Device Authorization Grant. It opens the
Microsoft verification page in the user's default browser and never asks the
user to enter a Microsoft password inside the launcher.

The application requests only these delegated scopes:

- `XboxLive.signin`, to sign the user in to Xbox Live and Minecraft Services;
- `offline_access`, so Microsoft may return a refresh token.

Authentication is performed directly from the desktop application against
Microsoft, Xbox Live and Minecraft Services:

1. `login.microsoftonline.com` issues and completes the device-code flow.
2. `user.auth.xboxlive.com` authenticates the Xbox Live account.
3. `xsts.auth.xboxlive.com` issues the XSTS authorization token.
4. `api.minecraftservices.com` authenticates Minecraft and returns the
   Minecraft Java profile.

The launcher reads only the Minecraft profile ID and player name needed to
show the signed-in account. To display the avatar, the frontend requests a
rendered player head from `mc-heads.net` using that player name. Authentication
tokens are held in process memory; the current implementation does not write
them to disk, send them to the
SpringRP server or expose them to the Vue frontend. Signing out clears the
in-memory session, and closing the launcher discards it.

Microsoft application (client) ID:
`d901c992-cb44-480a-b86d-d59b74083e04`.

See the [Privacy Policy](PRIVACY.md) for the complete data-handling statement.

## Current functionality

- Microsoft/Xbox/Minecraft device-code authentication;
- validation that the account has a Minecraft: Java Edition profile;
- display of the Minecraft player name and an avatar fetched from
  `mc-heads.net`;
- local sign-out that clears the active authentication session;
- launcher home and settings interface;
- installation and updating of the SpringRP modpack;
- installation of the official Minecraft client, assets, libraries and Java
  runtime;
- authenticated game startup using the Minecraft profile returned by
  Microsoft Services.

Not implemented in the current build:

- connecting the disabled website-authentication button;
- persistent Microsoft sessions between launcher restarts;
- analytics, advertising or telemetry.

## Development

### Prerequisites

- Windows 10 or newer with WebView2;
- Node.js 20+;
- Rust stable with the MSVC toolchain;
- Microsoft C++ Build Tools and Windows SDK.

Install dependencies and run the desktop development build:

```powershell
npm install
npm run tauri dev
```

Run static checks:

```powershell
npm run build
cargo check --manifest-path src-tauri/Cargo.toml
```

Runtime configuration belongs in the Tauri application-data directory and
must not be committed. The files in `config/` are schema examples only.

See [docs/architecture.md](docs/architecture.md) for implementation boundaries
and extension points.

## Support and privacy requests

Contact: [va@llebedev.ru](mailto:va@llebedev.ru)

SpringRP Launcher is an independent project and is not affiliated with or
endorsed by Microsoft, Xbox or Mojang Studios.
