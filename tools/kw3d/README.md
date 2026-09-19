# KW 3D / Outrage source workflow

Project root: `C:/Users/mario/Nextcloud/kw_godot`

## Source of truth
Save future Blockbench edits directly to:
`art_source/blockbench/outrage/Outrage_FullBody_v11_slimmer_body_foot.bbmodel`

This is the user's Desktop save imported byte-for-byte, not the earlier chat attachment.
Do not recreate/reinterpret the model from its version number. Preserve its UVs,
geometry, group pivots and embedded textures. The old Desktop file is only a fallback copy.

## Generated assets
- `assets/prototypes/outrage_fullbody/`: build data, textures and clean GLB.
- `scenes/prototypes/characters/outrage_fullbody.tscn`: colored model with four animation rigs and optional comic materials.
- `scenes/prototypes/kw_3d_prototype.tscn`: playable arena; use F6 (Run Current Scene).
- `scenes/prototypes/kw_3d_editor_preview.tscn`: editor-only snapshot of the same arena. Runtime removes it before building gameplay.

## Rebuild
Run `tools/kw3d/rebuild_fullbody.ps1`. The importer deliberately rejects unsupported
rotations or incomplete outliners instead of silently losing edits.
Use one uniform world scale (0.07), preserving the authored proportions.
The snapshot baker clears scene-instance metadata so it cannot spawn duplicate rigs.

## Controls
WASD move, mouse orbit, Space jump, Shift sprint, RMB aim, hold LMB automatic fire.
O toggles comic shading/3.5 px outline for head, torso and both feet together.
Esc releases the mouse. R spawns crates; F switches low gravity.

## Scope
The original 2D project main scene and existing project.godot changes stay untouched.
F5 still runs that main scene; F6 runs this 3D prototype.
Temporary logs, screenshots and safety copies live in `tmp/kw3d/`, ignored by Git/Godot.
All source and exported model files belong inside this project, never on Desktop.

## Pixel / low-poly surface pass
- `P` toggles low-resolution world rendering plus surface color variation together.
- `O` still toggles the character comic lighting/3.5 px ink, independently of P.
- The full-screen pass quantizes the 3D image to integer blocks (640x360 at 1280x720).
  HUD/crosshair render afterward and remain sharp. Editor 3D view shows surface
  materials at full editor resolution; the Game view includes the pixel pass.
- `scripts/prototypes/kw_pixel_surface.gdshaderinc`: object-space, five-tone noise;
  no TIME-based grain, no vertex displacement or extra geometry. Small details fade
  with distance to limit shimmer. Default strength 0.13, cells 0.07 on characters,
  0.16 on environment, 0.025 on AK. Emissive surfaces use a softer variation.
- `kw_pixel_screen.gdshader`: virtual height 360, nearest-neighbor sampling.
- Source BBModel/PNG palettes, clean exported GLB and project.godot are not modified.
- Weapon and hands use one forward hold pivot, preserving the source rifle shape.
  Camera-to-muzzle alignment is corrected after recoil. Collision/aim tests cover
  48 independent body/camera/pitch combinations.
- Regression: `tools/kw3d/test_pixel_pass.gd -- --kw-qa --qa-output=<local folder>`.

## Directional walk cycle / loose secondary motion
- `scripts/prototypes/kw_goofy_locomotion.gd` owns visual locomotion only.
- Ground motion comes from post-collision world displacement, not requested input.
- Alternating stance/swing: planted world-space contact, heel roll, toe-off,
  passing arc and heel contact. The step speed follows actual travel speed.
- Ground rays align shoes to slopes. Quick recovery steps handle sharp turns;
  stopping finishes a settling step instead of sliding both shoes back to idle.
- Feet face travel (including strafing/backwards). Head gaze remains camera-targeted.
- Per-step variation plus bounded torso/head springs create loose comic motion.
  Random values are chosen at step boundaries; no per-frame random jitter.
- `ragdoll_playfulness` on the arena script defaults to 1.2; 0..2 is supported.
  This is procedural secondary animation, not a physics ragdoll controlling movement.
- Source Blockbench geometry, shaders, rifle alignment and audio are unchanged.

Regression tests: `test_locomotion.gd`, `test_locomotion_terrain.gd`,
`test_fullbody.gd`, `test_pixel_pass.gd`. Run with `--kw-qa` and a
`--qa-output=<project/tmp/kw3d/...>` argument, using a real renderer for screenshots.

## Combat range and floating-body polish
- Source geometry remains the user's v11 `.bbmodel`, byte-for-byte unchanged.
- Player-only rest offsets: head +0.10 up / -0.20 forward; torso -0.12 down / +0.12 back.
  Locomotion owns these rest positions and adds separate translation/twist springs.
- Torso yaw follows body turns with bounded lag; gait, foot planting and targeted head gaze remain active.
- Rifle defaults to a left-side hold. Q switches sides along a clearance arc.
  Exact off-axis muzzle convergence plus short-range hold retraction replace iterative aim correction.
- Camera ray picks the crosshair target. A second muzzle ray applies damage;
  cover between the chest and the muzzle also blocks the shot. Cosmetic tracers have no colliders.
- `kw_combat_range.gd`: three stationary targets, 100 HP, AK damage 20, 0.10 s fire interval.
  B resets all targets. White hit marker means damage; red means a kill.
- `kw_training_dummy.gd`: per-target materials, 75 ms white hit overlay, healthbar,
  idempotent shot IDs, immediate collision removal at death, visual part collapse and cleanup.
- Tasko reference: assets/warriors/tasko/head.png + torso.png (purple #bf3fff, highlight #e1a5ff).
- Gan reference: assets/warriors/gan/head.png + torso.png (cyan #7ab1b7 / #ccf2f4, white hair).
- Celler reference: assets/warriors/celler/head.png + torso.png (white #eaeaea, dark face #232323, red #630000).
  These are simplified 3D practice-target interpretations, not changes to the existing 2D warriors.
- Editor preview bakes target visuals without their gameplay scripts, avoiding duplicate runtime spawns.
- Tests: test_combat_polish.gd (damage/flash/cover/death/reset/gaze), test_weapon_side.gd
  (both shoulders, intermediate swap poses with torso twist, centered reticle), plus existing walk/pixel tests.


## Aim readability / shooting polish
- `kw_aim_reticle.gd`: fixed 1-logical-pixel centre dot, thin separated arms,
  contrasting backing, unobtrusive hit/kill confirmation outside the centre.
- Green/cyan means the camera's target is also reachable by the muzzle ray.
  Amber/BLOCKED means cover intercepts the muzzle/holder path. A separate small
  square shows the true predicted impact, using logical viewport coordinates.
- `kw_combat_range.predict_shot` is shared by aim feedback and actual damage.
  Camera intent uses project_ray_origin/project_ray_normal at viewport centre;
  wall protection still checks the holder-to-muzzle segment first. No aim magnet,
  expanded hurtboxes, random bullet spread, camera shake, or extra damage.
- The local player's nameplate is hidden to clear the shooting lane.
- Hip/ADS both use shoulder X=1.20, Y=1.35. ADS moves only along local Z
  (6.4 -> 3.8) and narrows FOV (74 -> 58), without drifting off the centre ray.
  Captured screen-relative mouse sensitivity is FOV-compensated, not smoothed.
- A swept sphere retracts the camera before environment walls; it excludes the
  local player and does not collide with the practice targets.
- Dummies update their visual pose + matching hurtboxes before the player tick.
- Short cosmetic moving tracers replace full-length laser lines. Instant ray damage
  remains 20 at 0.10-second fire intervals. Confirmation ticks only play on damage;
  original AK audio is unchanged. Hit/kill ticks are quiet and muted in --kw-qa.
- Source BBModel, pixel/comic shaders, animation and original 2D settings are unchanged.
- Regression: `test_aim_polish.gd`: optical zoom stability, near/far both sides,
  reticle/ballistics agreement, cover feedback, camera collision, self-occlusion,
  resize/viewport projection, and pixel toggle consistency.

## Roaming range / combat feedback
- Arena is now 48 x 48 (4x the previous floor area), enclosed on all four sides, with extra cover and outer ramps.
- The three variants roam with random goals, pauses and obstacle avoidance via `kw_roaming_brain.gd`. They reuse the player `kw_goofy_locomotion.gd` walk/foot planting and torso springs. They do not attack.
- Exact animated hit shapes remain on layer 4. A separate top-level movement capsule uses layer 8; player is layer 2, terrain is layer 1. Shot mask 5 never hits a floating-gap capsule.
- `TAB` hides/shows only `HUD/HelpPanel`, including all instructions/status text. Reticle, cover warning, kill counter, health bars and hit feedback stay visible.
- `KILLS` is cumulative for the current run. `B` respawns the clones and resets alive/round counts without erasing session kills. New run starts at zero.
- Damage remains 20 per shot / 100 HP. Each confirmed hit now adds recoverable directional knockback, a short stagger, torso/head flinch and squash, a white flash, a damage number and capped cosmetic sparks. No random bullet spread or camera aim shake.
- Rifle `shooting_volume_db` defaults to -7.5 (was -13.5). The source WAV and OS/master volume are untouched. Automated QA runs mute the rifle.
- Aim regression tests freeze roaming explicitly; `test_roaming_range.gd` covers actual movement, walking, animated hitboxes, knockback, kills, TAB and reset.


## Survival waves / player health (current gameplay)
This supersedes the earlier stationary/three-clone-only range description.
- `kw_wave_director.gd` owns the wave state, player health, attack scheduling,
  hostile projectiles and wave transitions. `kw_arena_hud.gd` owns feedback UI.
- Wave counts: 3, 5, 7, 9 ... capped at 19 enemies per wave. Maximum eight live
  enemies at once; additional enemies enter as reinforcements. Four seconds
  between cleared waves. No simultaneous spawn-pad overlaps or near-player spawns.
- Player: 100 HP. Each unique credited kill restores up to 8 HP, capped at 100.
  Enemy bolts deal 8 HP; a 0.38-second damage grace prevents simultaneous hit piles.
  No regeneration outside kills and no healing after game over.
- Enemies occasionally announce a shot with an amber `!` and muzzle pulse, then
  fire an orange, non-homing bolt. The target position is locked at the start of
  the 0.65-second warning. A hit interrupts a warning. Global pacing and per-enemy
  cooldowns avoid synchronized volleys. Terrain blocks both the muzzle/holder
  path and the swept projectile path. Enemy fire is quieter than the player's AK.
- Six looks derived from existing warrior sprites: Tasko, Gan, Celler, Nova,
  M4 and Crashout. Added distinguishing helmets, hats and palettes, not just tints.
  Original assets and the user-edited Blockbench model remain unchanged.
- Enemy health bars are 128x18, segmented red with a delayed damage trail. Distance
  compensation increases readability while preserving world depth/occlusion.
- Damage numbers are red, screen-projected, 27/34 logical px with dark outline,
  pop/overshoot, alternating diagonal kick and fade. Up to 24 live labels.
  They are cosmetic, above the pixel pass, and never move the crosshair.
- Player health HUD stays visible when TAB hides HelpPanel. Wave/alive/kill score,
  hit indicators and healing feedback remain visible too.
- B retries the current wave, keeping session kills and current health. After
  death, ENTER or B restarts from wave 1 with full HP and zero kills.
- Releasing the mouse or losing focus suspends hostile/wave timers in local play.
  QA runs bypass native-focus gating and mute audio, but do not silently disable
  waves or enemy attacks. Older aim/locomotion fixtures explicitly call
  `combat.set_training_mode(true)`; the new wave tests exercise real behavior.
- Tests: `test_waves.gd` covers wave growth, reinforcement cap, all six variants,
  damage/kill healing/idempotence, visible HUD, red number animation, dodgeable
  projectiles, cover, interrupted shots and death/restart. `test_wave_live.gd`
  runs the actual autonomous third-wave loop without training mode.


## Arena audio, full-scene comic switch and grenade skill
- Soundtrack: original `assets/prototypes/audio/kw_neon_riot_loop.res`, 60 seconds,
  128 BPM / 32 bars, generated by `generate_arena_music.py` then `bake_arena_music.gd`.
  The existing fight MP3 is a 4-second sting, not used as a repetitive music bed.
  M fades music off/on; combat and footsteps remain audible. Normal target -18 dB,
  -23 dB between waves, ducked under gunfire/blasts. Original source MP3s unchanged.
- `kw_arena_audio.gd` reuses existing wood steps/jump/land, grenade launcher sounds,
  levelup/heal/death UI sounds. Footsteps follow actual swing-to-contact transitions;
  nearby clone steps are quieter. Bounded spatial pool (12), no global bus/OS edits.
  QA runs mute playback but still record audio events.
- Rifle hold height is now 0.80 above torso rest (previously 0.25), with bounded
  gait bob. `_weapon_anchor()` is shared by visual pose and obstruction checks.
  BLOCKED text and the obstruction square are removed. Collision-based obstruction
  still applies; no shooting through walls or expanded hitboxes.
- O now controls comic lighting AND ink across arena, props, player, enemy variants,
  both sides of the rifle, hands, grenades, projectiles and solid impact effects.
  P remains independent. New dynamically spawned objects inherit both settings.
- `kw_scene_ink.gd` builds cached smooth-normal silhouette shells, without modifying
  visible geometry. AK has one union hull, not outlines around its 271 pixels.
  Rebuild that hull with `prepare_ak_outline.py`, then `bake_ak_outline.gd`.
- Enemy attack telegraph 0.38 s (was 0.65), global recovery 0.30..0.58 s with wave
  scaling (was 1.1..1.8), per-enemy cooldown 1.8..3.0 s (was 4.0..6.5), bolt speed
  21 (was 18). Damage remains 8 and kill healing remains +8; hits interrupt charges.
- G throws an arcing, bouncing grenade: 6 s cooldown, 1.25 s fuse or direct-target
  detonation, maximum throw range 22. Blast radius 5.5, damage 110 close / 35 at edge.
  Solid terrain blocks radial damage; each actor receives one negative-ID event.
  Grenade kills use the same kill/heal pipeline. This prototype skill does not harm
  its owner. Pending grenades are cleared on death/retry; a new run resets cooldown.
- Grenade HUD stays visible with TAB-hidden instructions. Cube debris, smoke, a
  shock ring and flash accompany the explosion; no aim/camera shake is added.
- Main scene, authored BBModel and source sounds remain unchanged. All new code
  and generated AK hull live in this project. Backup/logs: `tmp/kw3d/grenade_audio_ink_*`.
- Regression: `test_grenade_audio_ink.gd`, existing aim/walk/wave suites. Aim test
  now asserts that blocked shots are still respected WITHOUT the removed text.
