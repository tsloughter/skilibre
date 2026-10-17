# Snow Pals

A gentle 3D downhill skiing game for little kids, made with **Godot 4** and original **Blender** models. Choose Pip the fox, Clover the bunny, Maple the bear, or Pebble the penguin, then follow a trail of stars to the cocoa cabin.

The fixed, elevated orthographic camera keeps downhill toward the bottom of the screen, inspired by [SkiFree](https://en.wikipedia.org/wiki/SkiFree). Movement is automatic: children can concentrate on steering. There are no lives, frightening pursuers, race timers, losing screens, purchases, or network services. Missing a star never prevents finishing. Hitting a rock or tree makes the animal tumble into a seated pose beside it, wobble its head, and see four stars circling overhead. After three seconds, the animal reappears in a clear spot past the obstacle and automatically continues skiing. Collected stars are kept, and a short recovery grace period prevents an immediate repeat tumble. Pausing also pauses the tumble animation and recovery timer.

## Play

On Linux, run **`./play.sh`** from this folder, or open `builds/linux/SnowPals.x86_64`. The exported executable includes the game data and does not require Godot or Blender to play.

To edit or run the source, import **`project.godot`** in Godot **4.5 or later** and press **F5**. The GL Compatibility renderer is used for broad hardware support.

The optional web export lives in `builds/web`. Serve it over HTTP rather than opening its HTML as a file:

```sh
python3 -m http.server 8000 --directory builds/web
```

Then visit `http://localhost:8000`. A browser with WebGL 2 is required. The first click/tap allows browser audio. The web export is single-threaded and does not require cross-origin isolation headers.

## Controls

| Action | Keyboard | Mouse / touch |
| --- | --- | --- |
| Steer | Left / right arrows, or A / D | Move the mouse over the snow, drag on the slope, or hold the large arrow buttons |
| Slow to a stop | Hold up arrow or W | Hold **Slow** |
| Glide a little faster | Hold down arrow or S | — |
| Hop | Space | **Hop ↑** button; ramps also hop automatically |
| Pause / resume | Esc or P | Pause button, then **Keep skiing** |
| Sound | M | **Sound on/off** |
| Fullscreen | F11 | — |
| Choose and start | Tab / Shift+Tab, then Enter | Click/tap a pal, a pace, then **Let’s ski!** |

Touch controls track fingers separately, allowing a hop while holding a steering button. Keyboard input takes over from mouse steering immediately. Leaving the game window pauses the run.

**Bunny slope** is the starting setting for younger children: slower skiing, a generous star collection radius, and gentle steering help around trees and rocks. **Little explorer** has a faster pace and manual obstacle avoidance. Runs are 360 game meters (roughly a minute, longer when braking). Both settings celebrate every finish, including a finish with zero stars. The selected animal, pace, and sound setting are saved locally.

## Project map

- `scripts/game.gd`: course generation, fixed camera, movement, collectibles, jumps, forgiving bumps, run states, audio, and local preferences.
- `scripts/interface.gd`: character portraits, menus, touch controls, progress, pause, and celebration.
- `scripts/skier_pose.gd`: seated poses, independent head wobble, and orbiting stars for all four Blender characters.
- `assets/models/*.glb`: game-ready exports of the four animals, pine, rock, jump, and star.
- `art/snow_pals.blend`: editable Blender asset library, arranged in a grid. This directory is excluded from Godot's asset importer, so opening the game does not require Blender.
- `tools/build_assets.py`: reproducible Blender geometry/material generator and glTF exporter.
- `tools/build_audio.py`: original toy-piano music and effects generated with Python's standard library.
- `tests/game_test.gd`: integration checks using the actual game scene, UI signals, keyboard events, touch events, and imported assets.
- `screenshots/`: real Godot captures used for visual review.

Rebuild art and sound from the repository root:

```sh
blender --background --factory-startup --python tools/build_assets.py
python3 tools/build_audio.py
godot --headless --path . --editor --import
```

On a Flatpak installation, substitute `flatpak run org.blender.Blender` and `flatpak run org.godotengine.Godot` for the executable names. Blender 5.2 was used to create the included assets; no Blender add-ons are needed.

Run the checks:

```sh
godot --headless --path . --script tests/game_test.gd -- --test
godot --headless --path . --script tests/ui_test.gd -- --test
godot --headless --path . --script tests/crash_test.gd -- --test
```

The `--test` flag prevents tests from reading or overwriting player preferences. For actual engine screenshots, run a graphical Godot instance with `-- --test --capture=menu` (or `game` / `finish` / `crash-fox` / `crash-bunny` / `crash-bear` / `crash-penguin`).

Export after installing export templates matching your Godot version:

```sh
mkdir -p builds/linux builds/web
godot --headless --path . --export-release Linux
godot --headless --path . --export-release Web
```

All character geometry, scenery, and audio are original to this project. Red Hat Display and the Adwaita Sans symbol fallback are bundled under the SIL Open Font License; see the license files in `assets/fonts/`. SkiFree is a gameplay reference, with no reused game assets.
