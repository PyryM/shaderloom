use crate::globutils::glob_items;
use crate::naga_parse::parse_wgsl;
use anyhow::Result;
use mlua::Lua;
use mlua::LuaSerdeExt;

static LUA_EMBEDS: &str = include_str!(concat!(env!("OUT_DIR"), "/embedded_lua_bundle.lua"));

pub fn run_script(infile: &str) -> Result<()> {
    let lua = Lua::new();
    let globals = lua.globals();

    globals.set("null", lua.null())?;

    let globber = lua.create_function(|_, pattern: String| Ok(glob_items(&pattern)?))?;
    globals.set("_glob", globber)?;

    let parser = lua.create_function(|_, src: String| Ok(parse_wgsl(&src)?))?;
    globals.set("_naga_parse", parser)?;

    if let Some(p) = std::path::Path::new(infile).parent() {
        globals.set("SCRIPTDIR", p.to_string_lossy())?;
    }
    globals.set("SCRIPTPATH", infile)?;

    if let Ok(p) = std::path::absolute(infile) {
        if let Some(p) = p.parent() {
            globals.set("ABSSCRIPTDIR", p.to_string_lossy())?;
        }
        globals.set("ABSSCRIPTPATH", p.to_string_lossy())?;
    }

    lua.load(LUA_EMBEDS).exec()?;

    Ok(())
}
