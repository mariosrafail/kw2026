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
