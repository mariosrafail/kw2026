# KW Character Builder (standalone)

This is the primary character-authoring tool for the six-view workflow.

It is a standalone Windows UI, not a Blockbench dialog.

On the development machine, the packaged app is built as:

`dist/KW Character Builder.exe`

Run `build_windows.cmd` to rebuild it after changing `app.py`.

## Workflow

1. Open **KW Character Builder**.
2. Select a body part (`HEAD`, `TORSO`, arms, legs).
3. Paint the six transparent 64x64 views, import a PNG into the current face, or use **IMPORT 6 NAMED PNGs** to load a complete part at once.
   - Batch filenames must contain `front`, `back`, `right`, `left`, `top`, and `bottom`.
   - Imported images are converted to RGBA and resized to 64x64 with nearest-neighbor scaling when needed.
   - PNG alpha and RGB colors are preserved by default. The optional near-white-to-transparent toggle is intended for old references with white backgrounds.
   - Faces are reconstructed exactly in the orientation shown in the editor. The builder does not silently mirror `BACK` / `LEFT` or flip `BOTTOM`; use the visible **FLIP H/V** controls only when a source image actually needs it.
4. Press **EXPORT TO BLOCKBENCH**.
5. The app generates:
   - a `.bbmodel`
   - a transparent PNG atlas
   - cuboid geometry reconstructed from the six silhouettes
6. Blockbench opens the generated `.bbmodel` automatically.

Transparent pixels become empty 3D space. RGB colors from the painted pixels are retained in the generated atlas/UVs.

The standalone app supports PNG import/export per face, six-face batch PNG import, optional white-to-alpha conversion for old references, brush/eraser/picker, a live 0–100% grid-opacity control, flip H/V, part positioning, forgiving/strict reconstruction, and save/load `.kwchar.json` projects.

## 3D Cuboid Editor

The six-view reconstruction is intended as a starting point, not as the final source of truth. The real current Outrage head is authored as 17 explicit Blockbench cuboids, so the app now includes a **3D BLOCK EDITOR** for finishing the shape manually.

- **CURRENT OUTRAGE HEAD** loads the `Outrage_Head` subtree from the active player source: `art_source/blockbench/outrage/Outrage_FullBody_v11_slimmer_body_foot.bbmodel`.
- The built Windows EXE also bundles that source template, so the current-head button remains available outside the repo.
- **FROM 6 VIEWS** reconstructs only the currently selected body part and loads the resulting cuboids into the editor.
- **LOAD .BBMODEL** can load another cuboid-based Blockbench model.
- Left click selects a cuboid. Right-drag orbits the camera. The mouse wheel zooms.
- Selected blocks can be renamed, resized by editing `FROM X/Y/Z` and `TO X/Y/Z`, moved along each axis, duplicated, added, or deleted.
- Imported face UVs and embedded textures are preserved. The active Outrage head therefore retains the exact authored body / eye / horn colors.
- When the current Outrage head is edited, **EXPORT + OPEN BLOCKBENCH** patches only its `Outrage_Head` subtree into a copy of the full active model. Torso/feet, rig group names, pivots, textures, and the rest of the full-body source remain intact for the existing game bake pipeline.

The older `tools/blockbench/kw_character_builder` Blockbench plugin can remain as an experimental bridge, but the standalone builder is the intended UI.
