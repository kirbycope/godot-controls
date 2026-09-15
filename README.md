![Preview](addons/controls/assets/godot-controls.png)

# Controls for Godot 4.8+

On-screen input hints that follow the player's device, and a world-space `ActionPrompt` for
interactable objects.

**[Read the full documentation](addons/controls/README.md)**, which ships with the addon so it is
there however you installed it.

## This repository

It uses the layout the [Godot Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html) expects, so it is both the addon and a
project you can open and edit it in:

```
project.godot     the demo project, which is this repository
addons/controls/  the addon itself
addons/gut/       the test runner
```

Clone it, open `project.godot` in Godot, and run the demo scene. The addon is mounted at
`res://addons/controls/` exactly as it is in a game, so it is edited in place with nothing copied
anywhere first. Installing through the Asset Library takes `addons/` and skips the root
`project.godot` as a conflict, which is why that file can live here harmlessly.

## Showing only what matters

`contextual_only` draws just the buttons whose label says something the scene did not: a prompt's
"Pick Up" on the Action button beside a pickup, a state's "Climb" on Jump at a wall, "Aim" on the
trigger while a gun is held. Everything else, the sticks and the d-pad included, stays off the screen
until a label of theirs changes, the way Breath of the Wild shows a hint as it becomes relevant. Off,
the whole set is drawn for the device in hand, as before.

A game that keeps the HUD off the desktop screen turns this on rather than hiding the node, so the
hints still pop in when they mean something. The visibility follows every label write:
`set_labels`, `reset_labels`, and a prompt's `claim_action_label` / `release_action_label` (which now
puts the scene's own word back on the button as it lets go). `is_label_contextual(label)` is the test
it uses.

## Prompts follow the action, not the button

A prompt's "Pick Up" used to land on the bottom face button whatever that button did. `prompt_action` names
the action a prompt stands for, and its word and its world-space art go on whichever button carries that
action, so a scheme that moves Action from A to Y moves the prompts with it. `action_label(action)` and
`action_button(action)` are the lookups; a state uses them to write "Climb" on the Jump button wherever it is.
The `ActionPrompt` also faces the camera while shown (`face_camera`), so it never reads mirrored from behind.

## Textures import Lossless

Every texture here imports with `compress/mode=0` (Lossless) and `detect_3d/compress_to=1`, so the
editor promotes one to VRAM Compressed the first time it sees it used in 3D. That is Godot's own
default.

This repository used to force `compress/mode=1` (Lossy) with promotion disabled, project wide. That
re-encoded every image through WebP at quality 0.7 before Godot saw it, and still uploaded
uncompressed to VRAM, so it lost real data -- every input prompt icon here is an SVG, blurred by a lossy re-encode for no gain and bought nothing at run time. It existed only to
squeeze a built `.pck` under GitHub's 100 MB limit, and nothing built is committed any more.

`python ../godot-3d-player-controller-v3/tools/texture_import_policy.py --root .` puts the
repository back on that policy, and `--check` reports without writing.

## Installing it in a game

Copy `addons/controls/` into your project's `addons/`. See the
[addon's README](addons/controls/README.md) for what it needs and how to use it.
