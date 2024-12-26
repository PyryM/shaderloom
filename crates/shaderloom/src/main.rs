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
    fn lua_dev() {
        let executor = LuaExecutor::new();
        executor.run_module("tests.dev").unwrap();
    }
}
