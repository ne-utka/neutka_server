# Runtime resources

`NewLaunch.jar` is an external game helper and is not stored in this
repository. Supply the reviewed binary as `resources/NewLaunch.jar` when the
launch feature is implemented and packaging is enabled.

Player skin assets belong in `resources/skins/`. The directory is ignored
except for its placeholder, so personal assets are never committed by default.

The backend resolves packaged resources through Tauri's resource directory.
Development code must not depend on the helper being present.
