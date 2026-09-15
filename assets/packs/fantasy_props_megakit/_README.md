# Notes
[Fantasy Props MegaKit](https://quaternius.com/packs/fantasypropsmegakit.html) - June 2025

## License
1. Copy `Fantasy Props MegaKit[Source].zip\License_Source.txt`
   to `assets\fantasy_props_megakit\License_Source.txt`

## Import Script
1. Copy `Fantasy Props MegaKit[Source].zip\Engine Projects\Godot.zip\Godot\addons\quaternius\quaternius_import_script.gd`
   to `assets\fantasy_props_megakit\quaternius_import_script.gd`
1. Open [assets\fantasy_props_megakit\quaternius_import_script.gd](/assets/fantasy_props_megakit/quaternius_import_script.gd#L11)
    - Replace `res://addons/quaternius/materials/` with `res://assets/fantasy_props_megakit/materials/`

## Materials
1. Copy `Fantasy Props MegaKit[Source].zip\Engine Projects\Godot.zip\Godot\addons\quaternius\materials`
   to `assets\fantasy_props_megakit\materials`
1. Delete all .import files in `assets\fantasy_props_megakit\materials`
1. Using VSCode;
   - Find `res://addons/quaternius/fantasypropsmegakit/Meshes/`
   Replace `res://assets/fantasy_props_megakit/`
   - Find: `res://addons/quaternius/materials/`
   Replace: `res://assets/fantasy_props_megakit/materials/`

## Models
1. Copy contents of `Fantasy Props MegaKit[Source].zip\Engine Projects\Godot.zip\Godot\addons\quaternius\fantasypropsmegakit\Meshes`
   to `assets\fantasy_props_megakit`
1. Delete all .import files in `assets\fantasy_props_megakit`
1. Open the project in Godot and let it import
1. Select all the `.gltf` files in `assets\fantasy_props_megakit`
1. Select the Import tab, scroll down to "Import Script", and select `res://assets/fantasy_props_megakit/quaternius_import_script.gd`
   - Godot 4.5+ will change it to a UID, which should be fine.

## Scenes
1. Copy contents of `Fantasy Props MegaKit[Source].zip\Engine Projects\Godot.zip\Godot\addons\quaternius\fantasypropsmegakit\Levels\`
  to `assets\fantasy_props_megakit`
   - Showcase.tscn
   - WizardsDen.tscn
1. Open the Scene(s) in Godot and click "Fix Depenedencies"
