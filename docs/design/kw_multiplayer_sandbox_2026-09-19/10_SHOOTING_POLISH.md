# Shooting Polish Status

Checkpoint baseline: alpha-0.1.40. AK recoil v1 below is local development work and has not been published as a new build yet.

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
- Confirmed bullet damage now throws 3D voxel blood/chunk particles using the victim warrior primary palette (e.g. Tasko purple, Gan cyan, CrashOut red). Kill bursts are larger; gameplay damage remains unchanged.
- The local player now has a billboarded world-space health bar above the head, driven by the same authoritative/local health state as the existing HUD.
- Locomotion was pushed further toward the supplied floating/disconnected Rayman-like reference: a wider stride, fast lift into a broad high hang, and late landing. Current QA reaches roughly `0.65 m` peak swing lift and `0.255 s` swing airtime at the tested run speed while preserving one support foot, slope contact and sharp-reversal safety.
- The 3D AK now has a `25`-round magazine and `1.0 s` reload, matching the existing KW AK weapon identity. `R` reloads on keyboard; Xbox `X` / PlayStation `Square` reloads on controller; empty magazines auto-reload.
- Reload blocks firing, plays the existing `ak_reload.wav`, lowers/rolls the held rifle, drops a short-lived cosmetic magazine prop and updates a bottom-right ammo/reload HUD. Offline, Waves and native online clients share the same presentation.
- Online ammo and reload timing are server-authoritative and included in snapshots; clients only predict local presentation and reconcile back to authority. Input protocol was bumped to `2` / build `kw3d-proof-20260920-mag-v2` so older public-alpha clients/servers cannot silently mix with the new weapon-state semantics.
- Dedicated magazine QA verifies exactly 25 authoritative shots before empty, blocks a 26th shot, auto/manual reload refill, and the protocol-2 two-client integration completed with reload events and no state failures.
