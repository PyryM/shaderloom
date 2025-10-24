//! Integration tests for the shaderloom library

use shaderloom::Shaderloom;
use std::path::Path;

#[test]
fn test_build_wgpu_example() {
    let shaderloom = Shaderloom::new();

    // Test building one of the example configurations
    let example_path = "examples/wgpu_bundle/loom.lua";

    if Path::new(example_path).exists() {
        shaderloom
            .build_from_file(example_path)
            .expect("Failed to build example shader bundle");
    }
}

#[test]
fn test_run_module() {
    let shaderloom = Shaderloom::new();

    // Test running a specific module (this should work with the embedded Lua modules)
    shaderloom
        .run_module("utils.common", None)
        .expect("Failed to run utils.common module");
}
