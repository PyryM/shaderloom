use crate::globutils::glob_items;
use crate::naga_parse::parse_wgsl;
use anyhow::Result;
use mlua::{Function, Lua, LuaSerdeExt};

static LUA_EMBEDS: &str = include_str!(concat!(env!("OUT_DIR"), "/embedded_lua_bundle.lua"));

pub struct LuaExecutor {
    lua: Lua,
}

impl LuaExecutor {
    pub fn new() -> Self {
        let lua = Lua::new();
        let globals = lua.globals();

        globals.set("null", lua.null()).unwrap();

        let globber = lua
            .create_function(|_, pattern: String| Ok(glob_items(&pattern)?))
            .unwrap();
        globals.set("_glob", globber).unwrap();

        let parser = lua
            .create_function(|_, src: String| Ok(parse_wgsl(&src)?))
            .unwrap();
        globals.set("_naga_parse", parser).unwrap();

        lua.load(LUA_EMBEDS).exec().unwrap();
        Self { lua }
    }

    pub fn run_module(&self, name: &str) -> Result<()> {
        let run_module: Function = self.lua.globals().get("_run_module")?;
        run_module.call::<()>(name)?;
        Ok(())
    }

    pub fn run_script(&self, infile: &str) -> Result<()> {
        let globals = self.lua.globals();

        if let Some(p) = std::path::Path::new(infile).parent() {
            globals.set("SCRIPTDIR", p.to_string_lossy())?;
        }
        globals.set("SCRIPTPATH", infile)?;

        if let Ok(p) = std::path::absolute(infile) {
            if let Some(p) = p.parent() {
                globals.set("ABSSCRIPTDIR", p.to_string_lossy())?;
            }
            globals.set("ABSSCRIPTPATH", p.to_string_lossy())?;
        };

        self.run_module("cli.exec_script")
    }
}
