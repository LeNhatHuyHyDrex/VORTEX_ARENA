# ForgeaX verified asset manifest

Updated: 2026-09-15

## Installed and verified

### KayKit Character Pack: Adventurers
- Source: https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0
- License: CC0 (see `kaykit_adventurers/LICENSE.txt`)
- Installed under: `assets/packs/kaykit_adventurers/`
- Contents copied: GLB/GLTF/FBX characters, weapons/accessories, textures, source README/license.
- Godot status: imported as a source pack, not yet used by the current 2D `ChampionVisual` renderer. It must not be represented as active in-game hero art until a 3D scene/retarget pipeline is added.

### Brackeys VFX Bundle source
- Source: https://github.com/Brackeys/vfx-in-godot
- License: CC0 (source README/license statement)
- Installed under: `assets/vfx/brackeys_bundle/` and `assets/packs/brackeys_vfx/`
- Contents copied: alpha particle textures including fire, flame, magic, slash, smoke, spark, trace, dirt, scorch and impact-oriented shapes.
- Godot status: available for the VFX library as an additional texture source; current hero skills still retain their distinct per-skill composite layers and vector fallback.

## Already present before this checkpoint

- `assets/vfx/kenney_particles/`: Kenney particle textures
- `assets/vfx/spell_fx/`: 2D Spell Effects spritesheets
- `assets/audio/rpg_sfx/`: 80 RPG SFX set
- `assets/art/ui/`: project UI art fallback set

## Not yet verified/installed

- LOWPO/Fantasy Heroes base pack
- KayKit Character Animations standalone pack
- Quaternius Modular Weapons standalone pack
- KayKit Dungeon Pack
- Quaternius Modular Dungeon
- Quaternius Fantasy Props MegaKit
- Kenney Fantasy UI Borders full archive
- Kenney UI Pack - Adventure full archive

The three small `kenney_*.zip` files in `.packs_tmp` are invalid HTML downloads, not asset archives, and are intentionally not treated as installed packs.
