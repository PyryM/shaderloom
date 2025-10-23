use anyhow::Result;
use shaderloom::Shaderloom;

fn main() -> Result<()> {
    println!("Building shaders with shaderloom...");
    
    let shaderloom = Shaderloom::new();
    
    // Example: build from a loom.lua file
    // This would typically be the path to your shader configuration
    if std::path::Path::new("shaders/loom.lua").exists() {
        shaderloom.build_from_file("shaders/loom.lua")?;
        
        // Tell Cargo to rerun if shader files change
        println!("cargo:rerun-if-changed=shaders/");
    } else {
        println!("No shaders/loom.lua found, skipping shader build");
    }
    
    Ok(())
}