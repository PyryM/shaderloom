mod globutils;
mod luaexec;
mod naga_parse;

use clap::{Parser, Subcommand};

use anyhow::{Result, anyhow};
use luaexec::LuaExecutor;

/// shaderloom: a WGSL preprocessor, validator, bundler, boilerplate-generator
#[derive(Debug, Parser)]
#[command(bin_name = "shaderloom", version)]
pub struct App {
    /// Logging level (can be specified multiple times)
    #[arg(short, long, action = clap::ArgAction::Count)]
    log_level: u8,

    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Build/bundle shaders
    Build {
        /// Path to build file (loom.lua)
        path: std::path::PathBuf,
    },
    /// Directly invoke a lua module's main function
    Run {
        /// Name of Lua module
        module: String,

        /// Raw argument to pass to module
        arg: Option<String>,
    },
}

fn main() -> Result<()> {
    let args = App::parse();
    match args.command {
        Command::Build { path } => {
            let path_string = path
                .to_str()
                .ok_or_else(|| anyhow!("Provided path is not UTF8!"))?;
            let executor = LuaExecutor::new();
            executor.run_script(path_string)?;
            Ok(())
        }
        Command::Run { arg, module } => {
            let executor = LuaExecutor::new();
            executor.run_module(&module, arg)?;
            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lua_string_utils() {
        LuaExecutor::new().run_tests("utils.stringmanip").unwrap();
    }

    #[test]
    fn lua_common_utils() {
        LuaExecutor::new().run_tests("utils.common").unwrap();
    }

    #[test]
    fn lua_preprocess() {
        LuaExecutor::new().run_tests("preprocess.chunker").unwrap();
        LuaExecutor::new()
            .run_tests("preprocess.preprocessor")
            .unwrap();
    }

    #[test]
    fn lua_naga() {
        LuaExecutor::new().run_tests("analysis.naga").unwrap();
    }

    #[test]
    fn lua_unify() {
        LuaExecutor::new().run_tests("analysis.unify").unwrap();
    }

    #[test]
    fn lua_python_target() {
        LuaExecutor::new().run_tests("targets.python.xgpu").unwrap();
    }

    #[test]
    fn lua_dev() {
        LuaExecutor::new().run_tests("tests.dev").unwrap();
    }
}
