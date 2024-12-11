use mlua::{Function, Lua, LuaSerdeExt, UserData};
use anyhow::Result;

static LUA_EMBEDS: &str = include_str!(concat!(env!("OUT_DIR"), "/embedded_lua_bundle.lua"));

pub struct LuaExecutor {
    lua: Lua,
}

pub struct LibLoom {}

impl UserData for LibLoom {
    fn add_methods<M: mlua::UserDataMethods<Self>>(methods: &mut M) {
        methods.add_method("get_content", |_, this: &SharedContentBlob, _: ()| {
            Ok(BString::from(this.0.content.clone()))
        });

        methods.add_method(
            "slice",
            |_, this: &SharedContentBlob, (start, stop): (usize, usize)| {
                let cropped = this.0.slice(start, stop)?;
                Ok(SharedContentBlob(cropped.into()))
            },
        );

        methods.add_method(
            "read_f32",
            |_, this: &SharedContentBlob, (start, stop): (usize, usize)| {
                let fdata: &[f32] = match try_cast_slice(&this.0.content[start..stop]) {
                    Ok(slice) => slice,
                    Err(e) => return Err(anyhow!(e).into()),
                };

                Ok(fdata.to_vec())
            },
        );

        methods.add_method(
            "read_u32",
            |_, this: &SharedContentBlob, (start, stop): (usize, usize)| {
                let fdata: &[u32] = match try_cast_slice(&this.0.content[start..stop]) {
                    Ok(slice) => slice,
                    Err(e) => return Err(anyhow!(e).into()),
                };

                Ok(fdata.to_vec())
            },
        );
    }
}

pub trait VirtualFS {
    pub fn 
}

impl LuaExecutor {
    pub fn new() -> Result<Self> {
        let lua = Lua::new();
        lua.load(LUA_EMBEDS).exec()?;
        Ok(Self { lua })
    }

    pub fn exec_config_script(script: )
}