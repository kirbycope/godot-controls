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

`addons/gut/` is not committed, and neither is any other addon the manifest in `tools/addons.json` names:
`python tools/pull_addons.py` fetches them after cloning, pinned to the commits in `tools/addons.lock.json`,
and CI runs the same pull before the tests. GUT is a third-party entry, taken from its release tag and never
pushed to.

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

## Installing it in a game

Copy `addons/controls/` into your project's `addons/`. See the
[addon's README](addons/controls/README.md) for what it needs and how to use it.
