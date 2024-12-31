mod globutils;
mod luaexec;
mod naga_parse;

use anyhow::{anyhow, Result};
use luaexec::LuaExecutor;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        return Err(anyhow!("Config file is required."));
    }
    let executor = LuaExecutor::new();
    executor.run_script(&args[1])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lua_utils() {
        LuaExecutor::new().run_tests("utils.stringmanip").unwrap();
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
    fn lua_dev() {
        LuaExecutor::new().run_tests("tests.dev").unwrap();
    }
}
