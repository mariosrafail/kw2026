# Warrior Asset Layout

This folder contains both:

- the current prototype shared sheets
- the new scalable per-warrior layout

## Existing prototype files

These files are still used by the current code and should remain in place until the loader is migrated:

- `allHeads.png`
- `allTorso.png`
- `allLegs.png`
- `allWarriors.png`
- `guns.png`

## New scalable structure

Use one flat folder per warrior:

```text
assets/warriors/
  _shared/
  outrage/
    head.png
    torso.png
    legs.png
    skins_preview.png
    portrait.png
    card.png
    skin_manifest.json
  erebus/
    head.png
    torso.png
    legs.png
    skins_preview.png
    portrait.png
    card.png
    skin_manifest.json
  tasko/
    head.png
    torso.png
    legs.png
    skins_preview.png
    portrait.png
    card.png
    skin_manifest.json
```

## Rules

- Keep `head`, `torso`, and `legs` separate.
- Use one warrior per folder.
- Keep all skin frames for a warrior inside the same sheet for that part.
- Keep UI preview art in the same warrior folder.
- Keep reusable art in `_shared/`.
- Keep a consistent frame size across warriors, ideally `64x64`.

## Recommended usage

- Put new warrior art in the per-warrior folders.
- Do not add new warriors into the old shared mega-sheets.
- Migrate code later from shared sheets to per-warrior loading.
