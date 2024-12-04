#[macro_export]
macro_rules! lua_serialized {
    ($t:ident) => {
        impl mlua::IntoLua for $t {
            fn into_lua(self, lua: &mlua::Lua) -> mlua::Result<mlua::Value> {
                lua.to_value(&self)
            }
        }

        impl mlua::FromLua for $t {
            fn from_lua(value: mlua::Value, luastate: &mlua::Lua) -> mlua::Result<Self> {
                luastate.from_value(value)
            }
        }
    };
}
