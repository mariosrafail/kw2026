# Shooting Polish Status

Checkpoint baseline: alpha-0.1.40. The shooting/weapon work below is local development work and has not been published as a new build yet.

- Ballistic aim/damage remains deterministic. No random spread or random damage was added.
- AK now has real learnable aim recoil in addition to cosmetic weapon kick. The first shots are mild, sustained fire climbs more, and a fixed left/right pattern replaces RNG for gameplay aim.
- Hip-fire 12-shot climb is about 8.16 degrees; ADS applies a 0.72 multiplier (about 5.88 degrees over the same 12-shot sequence).
- Releasing fire recovers remaining recoil smoothly. Mouse/stick counter-input reduces the stored recoil debt so recovery does not fight deliberate compensation.
- The same recoil model is used by offline Aim Lab/Waves and the native online client. Server hit resolution still uses the real transmitted aim ray; no client-reported damage was introduced.
- AK visual recoil retains bounded side/lift/twist variation, with rare exaggerated comic kicks; this remains cosmetic and does not add bullet spread.
- Muzzle flash is a short multi-piece burst with light, ember, and rare alternate accent colors.
- Bullets use a layered visible tracer: core, halo and pixel bullet head.
- Cosmetic tracer width, streak length and rare hot/chunky rounds vary without changing the real ray.
- World impacts create a bright flash plus short pixel debris.
- Hits create larger red/white pixel debris and stronger lethal bursts.
- Public multiplayer receives authoritative impact metadata and renders the same hit FX.
- Remote weapons show muzzle bursts and varied shot pitch.
- Remote characters receive cosmetic torso/head hit wobble.
- Room browser outer legacy dark modal was removed and now uses the shared main-menu skin.
- Aim/ADS/cover/weapon-side regressions passed after the polish.
- Public retail 2-client WSS test passed in MATCH on alpha-0.1.38 (historical published baseline).
- Local two-client native network integration passed with AK recoil v1, including authoritative combat/state consistency.
- Added an optional Godot 4.7 screen/depth edge-detection pass inspired by the supplied NekotoArts Borderlands-style shader. `Y` toggles it independently of `O` comic ink and `P` pixel rendering; default is OFF.
- Borderlands edge QA verifies the fullscreen depth pass on the Compatibility renderer and a visible frame difference with the effect enabled.
- Tightened the 3D AK hold slightly toward the body and lower (`side 1.10 -> 0.90`, `height 0.80 -> 0.72`, `distance 0.98 -> 0.92`). Side-swap clearance, ADS stability, near/far aim and cover-camera tests remain passing.
- Rifle fire now gives the shooter a small real backward body impulse (`1.25` velocity units) plus a visual torso spring kick. The same impulse runs in local prediction and the authoritative server; two-client integration remains consistent.
- Confirmed bullet damage throws cosmetic 3D voxel blood/chunk particles using the victim warrior primary palette (e.g. Tasko purple, Gan cyan, CrashOut red). Kill bursts are larger; the particles themselves never alter damage.
- The local player now has a billboarded world-space health bar above the head, driven by the same authoritative/local health state as the existing HUD.
- Locomotion now follows the supplied floating/disconnected Rayman-like reference more aggressively: feet rise quickly, hang high for most of each stride, and the next foot can lift before the previous one lands. QA measures roughly `0.72 m` peak lift, `0.295 s` swing duration and 49/100 sampled running frames with both feet visually airborne, while the gameplay collision body remains grounded and terrain/slope/sharp-reversal tests pass.
- Gameplay jump impulse increased from `7.4` to `8.8` in both offline movement and authoritative/local-predicted online movement.
- The 3D AK now has a `25`-round magazine and `1.0 s` reload, matching the existing KW AK weapon identity. `R` reloads on keyboard; Xbox `X` / PlayStation `Square` reloads on controller; empty magazines auto-reload.
- Reload blocks firing, plays weapon reload audio, lowers/rolls the held weapon and drops a short-lived cosmetic reload prop. Ammo/reload UI is now world-space above the local player health bar instead of the bottom-right HUD.
- Online ammo, reload timing, active weapon and damage are server-authoritative and included in snapshots; clients only predict local presentation and reconcile back to authority. Input protocol is now `3` / build `kw3d-proof-20260920-weapons-v3`, preventing older builds from silently mixing with the two-weapon/headshot semantics.
- Permanent ballistic rule: headshots use the exact hit CollisionShape3D region and multiply weapon damage by `1.5`. AK body damage is `5.0`; AK headshot damage is `7.5`. The shared multiplier is used by the weapon rules layer so shotgun pellets follow the same rule.
- Added a 3D shotgun as weapon slot 2: `10` pellets × `5` body damage, `11°` spread, `2` shells, `1.2 s` reload, stronger body/aim recoil and its own boxy floating 3D model. Mouse wheel switches AK ↔ Shotgun for now; each weapon preserves its own magazine/reload state.
- Remote online players also render the authoritative AK/Shotgun selection. The protocol-v3 two-client integration recorded `4` authoritative shotgun events and `4` reload events with `failures: []` and no large prediction corrections.
- Dedicated headshot QA verifies a real HeadRig ray resolves as headshot and applies `7.5`, a real TorsoRig ray applies `5.0`, and the authority server resolves the same real head CollisionShape3D region. Shotgun QA verifies 10 real pellet rays and the two-shell slot.
