use anyhow::Result;
use lua_binding_macros::lua_serialized;
use mlua::LuaSerdeExt;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Serialize, Deserialize, Clone)]
pub struct GlobItem {
    path: String,
    abspath: Option<String>,
    is_file: bool,
    is_dir: bool,
    file_name: Option<String>,
}

lua_serialized!(GlobItem);

fn pathbuf_to_item(p: PathBuf) -> GlobItem {
    GlobItem {
        path: p.to_string_lossy().into_owned(),
        abspath: std::path::absolute(&p)
            .ok()
            .map(|p| p.to_string_lossy().into_owned()),
        is_file: p.is_file(),
        is_dir: p.is_dir(),
        file_name: p.file_name().map(|f| f.to_string_lossy().into_owned()),
    }
}

pub fn glob_items(pattern: &str) -> Result<Vec<GlobItem>> {
    Ok(glob::glob(pattern)?
        .filter_map(|e| e.ok())
        .map(pathbuf_to_item)
        .collect())
}
