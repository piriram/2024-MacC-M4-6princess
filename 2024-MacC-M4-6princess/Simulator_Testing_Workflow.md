# Simulator Testing Workflow

## Runtime Debug Toggles
Open the camera screen and tap the `ladybug` button in the top bar.

You can switch:
- `Camera Source`: `Device` or `Sample`
- `Cutout Engine`: `Real` or `Mock`

## Default Safety Behavior
- Physical device default: `Device` camera + `Real` cutout engine
- Simulator default: `Sample` camera + `Mock` cutout engine
- If `Device` camera is selected but unavailable, the app safely falls back to `Sample`

## Recommended Simulator Loop
1. Launch in simulator
2. Keep `Camera Source = Sample`
3. Keep `Cutout Engine = Mock`
4. Verify navigation, frame composition, and editing flow end-to-end

## What Still Must Be Tested on Real Device
- Real-time camera preview and capture quality
- Lens switching and zoom hardware behavior
- Vision-based real cutout quality/performance
- Permission prompts and camera authorization flows
