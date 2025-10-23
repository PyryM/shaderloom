# shaderloom

A WGSL shader preprocessor, validator, bundler, and boilerplate generator.

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

Add shaderloom as a build dependency to your `Cargo.toml`:

```toml
[build-dependencies] 
shaderloom = { path = "path/to/shaderloom/crates/shaderloom" }
```

### Basic Usage

```rust
use shaderloom::Shaderloom;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let shaderloom = Shaderloom::new();
    
    // Build shaders from a loom.lua configuration file
    shaderloom.build_from_file("shaders/loom.lua")?;
    
    // Or run a specific Lua module
    shaderloom.run_module("some.module", Some("argument".to_string()))?;
    
    Ok(())
}
```

### Usage in build.rs

This is particularly useful for integrating shader processing into your build pipeline:

```rust
// build.rs
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
