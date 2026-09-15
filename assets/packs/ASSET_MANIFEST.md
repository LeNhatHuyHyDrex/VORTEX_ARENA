# ForgeaX verified asset manifest

Updated: 2026-09-15 (full-pack checkpoint)

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

## Installed in this checkpoint

### Kenney Fantasy UI Borders
- Official page: https://kenney.nl/assets/fantasy-ui-borders
- License: CC0
- Installed under: `assets/packs/kenney_fantasy_ui_borders/`
- Archive validated successfully; 286 files unpacked.
- Exposed for runtime art exploration under `assets/art/ui/kenney_full/fantasy_borders/`.

### Kenney UI Pack - Adventure
- Official page: https://kenney.nl/assets/ui-pack-adventure
- License: CC0
- Installed under: `assets/packs/kenney_ui_adventure/`
- Archive validated successfully; 393 files unpacked.
- Exposed for runtime art exploration under `assets/art/ui/kenney_full/adventure/`.
- Combined full UI source now contains 542 PNG files.

## Source links recorded, download still pending

- LOWPO/Fantasy Heroes base pack: Unity Asset Store page requires store download flow.
- KayKit Character Animations: official itch.io download page returned HTTP 403 to the non-browser downloader.
- KayKit Dungeon / Dungeon Remastered: official itch.io page requires the download flow.
- Quaternius Modular Weapons: official page exposes Google Drive folder; direct folder download needs browser/session handling.
- Quaternius Modular Dungeon: official page exposes Google Drive folder; direct folder download needs browser/session handling.
- Quaternius Fantasy Props MegaKit: official page exposes Itch.io download flow; direct archive is not exposed in page HTML.

Verified source URLs are recorded in `assets/packs/source/official_pack_links.txt`.

The three old small `kenney_*.zip` files in `.packs_tmp` are invalid HTML downloads, not asset archives. They remain unused; the two valid Kenney archives installed above are separate verified downloads.

## Full-pack checkpoint results (2026-09-15)

### Newly installed in this checkpoint
- KayKit Dungeon Remastered official repository: 827 files / approximately 25 MB, including 203 GLB assets plus FBX/OBJ/textures, CC0.
- Kenney Fantasy UI Borders direct official archive: valid ZIP, 286 files, CC0.
- Kenney UI Pack - Adventure direct official archive: valid ZIP, 393 files, CC0.
- Kenney full UI sources exposed under `assets/art/ui/kenney_full/` with 542 PNG files.
- Quaternius public Godot reference repository metadata installed under `assets/packs/`; it documents Fantasy Props MegaKit, Modular Character Outfits, Universal Animation Library, and Universal Base Characters. The repository contains metadata/reference, not the full source archives.

### Runtime integration
- `ArtLibrary.kenney_ui_texture()` now resolves selected full-pack Kenney UI textures.
- `MainMenu.gd` now prefers a Kenney full-pack panel texture when available, with existing parchment fallback preserved.
- Godot import succeeded with no script/parse errors.
- Smoke test passed: 17/17 champions, `SMOKE_OK frames=240`.
- Windows and Android builds passed after the asset import.

### Remaining source-flow limitations
- LOWPO download requires the Unity Asset Store flow and was not directly downloadable by the current non-browser environment.
- KayKit Character Animations official page is verified CC0/133 FBX+GLTF animations, but the itch download endpoint returned 403.
- Quaternius Modular Weapons and Modular Dungeon official pages expose Drive folders; the full archives require Drive/browser download flow. Verified official URLs are in `assets/packs/source/official_pack_links.txt`.
- Quaternius Fantasy Props MegaKit official page exposes an Itch download flow; only its public Godot reference metadata is installed, not the full archive.

## Automated audit

`tools/asset_audit.gd` reports:
- KayKit Adventurers GLB: 5
- KayKit Dungeon GLB: 203
- Kenney full UI PNG: 542
- Brackeys alpha PNG: 93
- Spell FX PNG: 10
- RPG SFX OGG: 80

The audit and final builds complete without script or parse errors.
