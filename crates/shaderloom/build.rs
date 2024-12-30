// build.rs

use std::env;
use std::fs;
use std::path::Path;

// This recursively takes the Lua source files in `src/lua/` and bundles them
// into a single source file `$OUT_DIR/embedded_lua_bundle.lua.
// (This can then be embedded with `include_str!`).
//
// The Lua bundle file itself looks like:
// ```lua
// local _EMBED = {}
// _EMBED['file_one.lua'] = function()
// -- src/lua/file_one.lua contents
// end
// _EMBED['subdir/file_two.lua'] = function()
// -- src/lua/subdir/file_two.lua contents
// end
// -- ...
// _EMBED['_init.lua']()
// ```
//
// `src/lua/_init.lua` is always run at the end, and sets up `require`
// to first check the _EMBED table for a file.

fn wrap_lua_file<P: AsRef<Path>>(name: &str, src: &P) -> String {
    let data = fs::read_to_string(src).expect(name);
    format!(
        "_SOURCE_START('{}') _EMBED['{}'] = function()\n{}\nend",
        name, name, data
    )
}

fn wrap_entry<P: AsRef<Path>>(root_dir: &P, entry: walkdir::DirEntry) -> String {
    let name = entry
        .path()
        .strip_prefix(root_dir)
        .expect("Path is somehow not relative to root!")
        .to_str()
        .expect("Path is not a valid utf8 string!")
        .replace("\\", "/"); // handle windows paty separators
    wrap_lua_file(&name, &entry.path())
}

fn has_extension(e: &walkdir::DirEntry, ext: &str) -> bool {
    if let Some(pext) = e.path().extension() {
        pext == ext
    } else {
        false
    }
}

fn wrap_lua_source_files<P: AsRef<Path>>(root: &P) -> String {
    let embeds: Vec<String> = walkdir::WalkDir::new(root)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|e| !e.file_type().is_dir() && has_extension(e, "lua"))
        .map(|entry| wrap_entry(root, entry))
        .collect();
    embeds.join("\n")
}

fn main() {
    let out_dir = env::var_os("OUT_DIR").unwrap();
    let dest_path = Path::new(&out_dir).join("embedded_lua_bundle.lua");

    let preamble = "
    local _LINES = {}
    local function _SOURCE_START(name)
        table.insert(_LINES, {debug.getinfo(2, 'l').currentline, name})
    end
    local _EMBED = {}
    ";
    let embeds = wrap_lua_source_files(&"src/lua".to_string());
    let source = format!("{}\n{}\n_EMBED['_init.lua']()", preamble, embeds);

    fs::write(&dest_path, source).expect("Failed to write embedded bundle.");
    println!("cargo::rerun-if-changed=build.rs");
    println!("cargo::rerun-if-changed=src/lua");
}
