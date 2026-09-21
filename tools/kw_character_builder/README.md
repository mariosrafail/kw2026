# KW Character Builder (standalone)

This is the primary character-authoring tool for the six-view workflow.

It is a standalone Windows UI, not a Blockbench dialog.

On the development machine, the packaged app is built as:

`dist/KW Character Builder.exe`

Run `build_windows.cmd` to rebuild it after changing `app.py`.

## Workflow

1. Open **KW Character Builder**.
2. Select a body part (`HEAD`, `TORSO`, arms, legs).
3. Paint the six transparent 64x64 views: `FRONT / BACK / RIGHT / LEFT / TOP / BOTTOM`.
4. Press **EXPORT TO BLOCKBENCH**.
5. The app generates:
   - a `.bbmodel`
   - a transparent PNG atlas
   - cuboid geometry reconstructed from the six silhouettes
6. Blockbench opens the generated `.bbmodel` automatically.

Transparent pixels become empty 3D space. RGB colors from the painted pixels are retained in the generated atlas/UVs.

The standalone app supports PNG import/export per face, white-to-alpha conversion for old references, brush/eraser/picker, a visible 64x64 grid, flip H/V, part positioning, forgiving/strict reconstruction, and save/load `.kwchar.json` projects.

The older `tools/blockbench/kw_character_builder` Blockbench plugin can remain as an experimental bridge, but the standalone builder is the intended UI.
