use mlua::{Function, Lua, LuaSerdeExt};
use anyhow::Result;

static LUA_EMBEDS: &str = include_str!(concat!(env!("OUT_DIR"), "/embedded_lua_bundle.lua"));

pub struct LuaExecutor {
    lua: Lua,
}

impl LuaExecutor {
    pub fn new() -> Result<Self> {
        let lua = Lua::new();
        lua.load(LUA_EMBEDS).exec()?;
        Ok(Self { lua })
    }
}