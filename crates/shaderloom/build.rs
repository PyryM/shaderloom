// build.rs

use std::env;
use std::fs;
use std::path::Path;

fn wrap_lua_file<P: AsRef<Path>>(name: &str, src: &P) -> String {
    let data = fs::read_to_string(src).expect("Failed to read file!");
    format!("_p['{}'] = function()\n{}\nend", name, data)
}

fn wrap_entry(entry: fs::DirEntry) -> String {
    let name = entry.file_name().into_string().expect("Filename is not a valid string.");
    wrap_lua_file(&name, &entry.path())
}

fn wrap_lua_source_files() -> String {
    let embeds: Vec<String> = fs::read_dir("src/lua")
        .expect("Failed to read src/lua")
        .map(|entry| wrap_entry(entry.expect("failed to read dir entry")))
        .collect();
    embeds.join("\n")
}

fn main() {
    let out_dir = env::var_os("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("embedded_lua_bundle.rs");

    let embeds = wrap_lua_source_files();
    let source = format!("local _p={{}}\n{}\n_p['_init.lua']()", embeds);

    fs::write(&dest_path, source).expect("Failed to write embedded bundle.");
    println!("cargo::rerun-if-changed=build.rs");
    println!("cargo::rerun-if-changed=src/lua");
}
