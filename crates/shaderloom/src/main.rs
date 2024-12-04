mod globutils;
mod luaexec;

use anyhow::Result;
use luaexec::LuaExecutor;

fn main() -> Result<()> {
    let executor = LuaExecutor::new()?;
    Ok(())
}
