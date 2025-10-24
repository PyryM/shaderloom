# shaderloom

Shaderloom is a WGSL shader preprocessor, validator, bundler, and boilerplate generator. It can manage includes and build-time logic as pure Lua.

## Usage as a Command Line Tool

Installation:
```bash
cargo install --path crates/shaderloom/
```

Running an example (through Cargo):
```bash
cargo run --bin shaderloom -- build examples/wgpu_bundle/loom.lua
```

Building (assuming shaderloom is on path):
```bash
shaderloom build some/path/loom.lua
```

## Usage as a Rust Library

You can add shaderloom to your `build.rs`. First add shaderloom as a build dependency to your `Cargo.toml`:


```toml
[build-dependencies] 
shaderloom = { git = "https://github.com/PyryM/shaderloom",
               rev = "4a04046d1c031e827ef894df8b5fc7bab0bb4a6a" }
```

Then in `build.rs`:
```rust
use shaderloom::Shaderloom;

fn main() {
    let shaderloom = Shaderloom::new();
    
    // Build shaders as part of the build process
    shaderloom.build_from_file("shaders/loom.lua")
        .expect("Failed to build shaders");
    
    // Tell Cargo to rerun build script if shader files change
    println!("cargo:rerun-if-changed=shaders/");
}
```
