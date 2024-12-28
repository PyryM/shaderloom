use crate::globutils::glob_items;
use crate::naga_parse::parse_wgsl;
use anyhow::Result;
use mlua::{Function, Lua, LuaSerdeExt, UserData};

static LUA_EMBEDS: &str = include_str!(concat!(env!("OUT_DIR"), "/embedded_lua_bundle.lua"));

pub struct LuaLoomInterface {}

impl LuaLoomInterface {
    pub fn new() -> Self {
        Self {}
    }
}

impl UserData for LuaLoomInterface {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("glob", |_, _this: &Self, pattern: String| {
            Ok(glob_items(&pattern)?)
        });

        methods.add_method("parse_wgsl", |_, _this: &Self, src: String| {
            Ok(parse_wgsl(&src)?)
        });

        methods.add_method("print", |_, _this: &Self, msg: String| {
            println!("LUA: {}", msg);
            Ok(())
        });
    }
}

pub struct LuaExecutor {
    lua: Lua,
}

impl LuaExecutor {
    pub fn new() -> Self {
        // need to create "unsafe" Lua state to have 'debug' Lua library
        let lua = unsafe { Lua::unsafe_new() };
        let globals = lua.globals();

        globals.set("null", lua.null()).unwrap();
        globals.set("loom", LuaLoomInterface::new()).unwrap();

        lua.load(LUA_EMBEDS).set_name("=<BUNDLE>").exec().unwrap();
        Self { lua }
    }

    pub fn run_module(&self, module_name: &str) -> Result<()> {
        let run_module: Function = self.lua.globals().get("_run_module")?;
        run_module.call::<()>(module_name)?;
        Ok(())
    }

    pub fn run_tests(&self, module_name: &str) -> Result<()> {
        let run_tests: Function = self.lua.globals().get("_run_tests")?;
        run_tests.call::<()>(module_name)?;
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
