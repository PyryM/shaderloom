use anyhow::{anyhow, Result};

use mlua::LuaSerdeExt;
use serde::Serialize;

use naga::front::wgsl;
use naga::valid::{Capabilities as Caps, ModuleInfo};
use naga::valid::{ValidationFlags, Validator};
use naga::Module;

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

pub fn parse_wgsl_to_json(src: &str) -> Result<String> {
    let module = wgsl::parse_str(src)?;
    let json = serde_json::to_string(&module)?;
    Ok(json)
}

pub fn validate_wgsl(src: &str, validation_flags: u8) -> Result<(Module, ModuleInfo)> {
    let module = wgsl::parse_str(src)?;
    // According to the Naga CLI, these capabilities are missing from wgsl
    let caps = Caps::all() & !(Caps::CLIP_DISTANCE | Caps::CULL_DISTANCE);
    let flags = ValidationFlags::from_bits(ValidationFlags::all().bits() & validation_flags)
        .unwrap_or(ValidationFlags::all());

    let info = Validator::new(flags, caps).validate(&module)?;

    Ok((module, info))
}
