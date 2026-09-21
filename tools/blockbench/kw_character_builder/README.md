# KW Character Builder

Internal Blockbench plugin for turning six 64x64 orthographic pixel drawings into a colored cuboid/voxel character model.

Validated against Blockbench 5.2.0 and the current KW Outrage six-view 64x64 reference workflow.

## Install

1. Open Blockbench.
2. Open **File / Plugins**.
3. Choose **Load Plugin from File**.
4. Select `kw_character_builder.js` from this folder.
5. Open **Tools -> KW Character Builder**.

No npm/build step is required. The plugin is one JavaScript file.

## Workflow

- Choose a part: `HEAD`, `TORSO`, `LEFT LEG`, `RIGHT LEG`.
- Paint `FRONT`, `BACK`, `RIGHT`, `LEFT`, `TOP`, `BOTTOM` on transparent 64x64 canvases.
- The editor shows a visible 64x64 grid, but the grid is UI-only and is never baked into the PNG.
- Transparent pixel = empty 3D space.
- RGB color = surface color retained by the generated model.
- `GENERATE 3D` builds a visual hull from the six silhouettes, greedily merges matching voxels into larger cuboids, builds a PNG atlas, and creates the model directly in Blockbench.
- `FORGIVING` mode uses the union of opposite hand-drawn silhouettes per axis and is recommended for hand-drawn views.
- `STRICT` mode intersects every painted silhouette.

The default part positions are based on the current Outrage proportions. They can be changed in the plugin before generation.

## PNG behavior

The editor itself is transparent by default. PNG exports therefore do **not** include a white background.

For old reference images that already contain a white background, keep **Treat near-white as transparent on PNG import** enabled.

The plugin does not parse `.xcf` files directly. Existing GIMP/XCF work can be exported as one transparent PNG per view and imported into the matching face tab; new work can be painted entirely inside the plugin.

## Files

- `kw_character_builder.js` - Blockbench plugin.
- `.kwskin.json` - optional editable save file exported from inside the plugin.
- `KW_character_atlas.png` - optional atlas export and the texture generated inside Blockbench.

## Current MVP limits

- The template currently contains four major body parts. Extra generated parts (arms, horns as their own independent editable part, accessories, etc.) can be added to the `PARTS` table next.
- Highly detailed 64x64 artwork with many unique per-view colors can create many cuboids. The generator currently guards against extreme output (>3000 cuboids per part).
- The tool generates the Blockbench model; automatic `.glb` export / Godot import is a separate next step.
