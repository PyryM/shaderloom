use anyhow::Result;

use mlua::LuaSerdeExt;
use serde::Serialize;

use naga::Module;
use naga::front::wgsl;
use naga::valid::Capabilities as Caps;
use naga::valid::{ValidationFlags, Validator};

#[derive(Serialize, Clone)]
pub struct LuaWGSLModule {
    //pub source: String,
    pub module: Module,
}

impl mlua::IntoLua for LuaWGSLModule {
    fn into_lua(self, lua: &mlua::Lua) -> mlua::Result<mlua::Value> {
        lua.to_value(&self)
    }
}

pub fn parse_wgsl(src: &str) -> Result<LuaWGSLModule> {
    let module = wgsl::parse_str(src)?;
    Ok(LuaWGSLModule { module })
}

pub fn parse_and_validate_wgsl(src: &str, flags: Option<u8>) -> (Option<Module>, Option<String>) {
    let module = match wgsl::parse_str(src) {
        Ok(m) => m,
        Err(e) => return (None, Some(e.emit_to_string(src))),
    };
    // According to the Naga CLI, these capabilities are missing from wgsl
    let caps = Caps::all() & !(Caps::CLIP_DISTANCE | Caps::CULL_DISTANCE);
    let flags = match flags {
        Some(bitflags) => ValidationFlags::from_bits_truncate(bitflags),
        None => ValidationFlags::all(),
    };
    let err_info = match Validator::new(flags, caps).validate(&module) {
        Ok(_) => None,
        Err(e) => Some(e.emit_to_string(src)),
    };

    (Some(module), err_info)
}
