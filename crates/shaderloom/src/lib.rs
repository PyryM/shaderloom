//! # Shaderloom
//!
//! A WGSL shader preprocessor, validator, bundler, and boilerplate generator.
//!
//! This crate provides both a command-line interface and a library interface
//! for processing WGSL shaders using Lua scripts.
//!
//! ## Usage as a library
//!
//! ```rust,no_run
//! use shaderloom::Shaderloom;
//! use std::path::Path;
//!
//! // Build shaders from a loom.lua configuration file
//! let shaderloom = Shaderloom::new();
//! shaderloom.build_from_file("path/to/loom.lua")?;
//!
//! // Or run a specific Lua module
//! shaderloom.run_module("some.module", Some("argument".to_string()))?;
//! # Ok::<(), Box<dyn std::error::Error>>(())
//! ```
//!
//! ## Usage in build.rs
//!
//! ```rust,no_run
//! // In your build.rs file:
//! use shaderloom::Shaderloom;
//!
//! fn main() {
//!     let shaderloom = Shaderloom::new();
//!     shaderloom.build_from_file("shaders/loom.lua")
//!         .expect("Failed to build shaders");
//!     
//!     // Tell Cargo to rerun if shader files change
//!     println!("cargo:rerun-if-changed=shaders/");
//! }
//! ```

pub mod globutils;
pub mod luaexec;
pub mod naga_parse;

use anyhow::Result;
use luaexec::LuaExecutor;
use mlua::Table;
use std::path::Path;

/// Main interface for the Shaderloom shader preprocessor.
///
/// This struct provides access to the shader preprocessing functionality
/// that can be used from Rust code, including in build scripts.
pub struct Shaderloom {
    executor: LuaExecutor,
}

impl Shaderloom {
    /// Create a new Shaderloom instance.
    ///
    /// This initializes the Lua runtime with all the embedded shader processing scripts.
    pub fn new() -> Self {
        Self {
            executor: LuaExecutor::new(),
        }
    }

    /// Build/bundle shaders from a loom.lua configuration file.
    ///
    /// This is equivalent to running `shaderloom build <path>` from the command line.
    ///
    /// # Arguments
    ///
    /// * `path` - Path to the loom.lua configuration file
    ///
    /// # Example
    ///
    /// ```rust,no_run
    /// use shaderloom::Shaderloom;
    ///
    /// let shaderloom = Shaderloom::new();
    /// shaderloom.build_from_file("shaders/loom.lua")?;
    /// # Ok::<(), Box<dyn std::error::Error>>(())
    /// ```
    pub fn build_from_file<P: AsRef<Path>>(&self, path: P) -> Result<()> {
        let path = path.as_ref();
        let path_str = path
            .to_str()
            .ok_or_else(|| anyhow::anyhow!("Path is not valid UTF-8: {:?}", path))?;

        self.executor.run_script(path_str)
    }

    /// Run a specific Lua module with an optional argument.
    ///
    /// This is equivalent to running `shaderloom run <module> [arg]` from the command line.
    ///
    /// # Arguments
    ///
    /// * `module` - Name of the Lua module to run
    /// * `arg` - Optional string argument to pass to the module
    ///
    /// # Example
    ///
    /// ```rust,no_run
    /// use shaderloom::Shaderloom;
    ///
    /// let shaderloom = Shaderloom::new();
    /// shaderloom.run_module("some.module", Some("argument".to_string()))?;
    /// # Ok::<(), Box<dyn std::error::Error>>(())
    /// ```
    pub fn run_module(&self, module: &str, arg: Option<String>) -> Result<()> {
        self.executor.run_module(module, arg)
    }

    /// Update the configuration with a Lua table.
    ///
    /// This allows you to programmatically set configuration values that would
    /// normally be set in the Lua script environment.
    ///
    /// # Arguments
    ///
    /// * `config` - A Lua table containing configuration values
    pub fn update_config(&self, config: Table) -> Result<()> {
        self.executor.update_config(config)
    }

    /// Get access to the underlying Lua executor for advanced usage.
    ///
    /// This provides direct access to the Lua runtime if you need to perform
    /// more complex operations not covered by the high-level API.
    pub fn executor(&self) -> &LuaExecutor {
        &self.executor
    }
}

impl Default for Shaderloom {
    fn default() -> Self {
        Self::new()
    }
}

// Re-export related types for advanced users
pub use globutils::{glob_items, GlobItem};
pub use naga_parse::{parse_and_validate_wgsl, parse_wgsl, LuaWGSLModule};

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shaderloom_creation() {
        let _shaderloom = Shaderloom::new();
    }

    #[test]
    fn test_lua_modules() {
        let shaderloom = Shaderloom::new();

        // Test various Lua modules
        shaderloom
            .executor()
            .run_tests("utils.stringmanip")
            .unwrap();
        shaderloom.executor().run_tests("utils.common").unwrap();
        shaderloom
            .executor()
            .run_tests("preprocess.chunker")
            .unwrap();
        shaderloom
            .executor()
            .run_tests("preprocess.preprocessor")
            .unwrap();
        shaderloom.executor().run_tests("analysis.naga").unwrap();
        shaderloom.executor().run_tests("analysis.unify").unwrap();
        shaderloom
            .executor()
            .run_tests("targets.python.xgpu")
            .unwrap();
        shaderloom.executor().run_tests("tests.dev").unwrap();
    }
}
