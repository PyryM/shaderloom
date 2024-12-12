mod globutils;
mod luaexec;

use anyhow::{anyhow, Result};
use luaexec::run_script;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        return Err(anyhow!("Config file is required."))
    }
    run_script(&args[1])?;
    Ok(())
}
