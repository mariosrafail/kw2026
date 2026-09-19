# Offline Test Rooms

Current build: alpha-0.1.37

The main menu now has two top-level play paths:

- FIGHT! -> public online flow
- TEST OFFLINE -> local development test rooms

## Current offline rooms

### WAVES / COMBAT RANGE
Scene: res://scenes/prototypes/kw_3d_prototype.tscn
Mode: waves

- Endless wave progression
- Roaming enemies
- Enemy fire enabled
- Grenade, AK, movement, ragdoll animation, pixel/comic pass
- Existing combat and wave HUD

### SANDBOX / AIM LAB
Scene: res://scenes/prototypes/kw_3d_prototype.tscn
Mode: sandbox

- Same 3D arena/gameplay foundation
- Three stationary targets
- No enemy fire
- No wave advancement
- Useful for movement, aim, weapons, VFX, shader and animation experiments

## Navigation
- Main menu: TEST OFFLINE
- In any offline test room: F10 returns to the Offline Test Rooms browser.
- Returning with F10 automatically reopens the offline room browser.

## UI
The Offline Test Rooms browser and the public 3D room menu use the shared exact main-menu button skin in:
scripts/ui/main_menu/kw_menu_skin.gd

This mirrors the StyleBox values from scenes/ui/main_menu.tscn so normal, hover, pressed and focus states stay visually consistent.
