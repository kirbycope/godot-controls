extends GutTest
## Covers the part of the HUD a consuming project actually configures: which action each button drives, what
## gets registered in the InputMap, which buttons are shown, and how the labels behave.

const CONTROLS_SCENE: PackedScene = preload("res://addons/controls/controls.tscn")

## Where the key faces live, for the tests that hand the HUD a different one.
const KEY_ART: String = "res://addons/controls/assets/kenney_nl/Icons/Input Prompts/Keyboard & Mouse/Vector"

## Action names invented for these tests, removed again in [method after_each] so one test cannot bind another.
const TEST_ACTIONS: PackedStringArray = [
	"test_interact", "test_attack", "test_aim", "test_menu", "test_look_up", "test_look_down",
]

var _controls: Controls


func before_each() -> void:
	_clear_test_actions()


func after_each() -> void:
	_clear_test_actions()


func _clear_test_actions() -> void:
	for action_name: String in TEST_ACTIONS:
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)


## Empties the screenshot folder so a count is a count of what this test took.
func _clear_screenshots() -> void:
	if not DirAccess.dir_exists_absolute(Controls.SCREENSHOT_DIR):
		return
	for file_name: String in DirAccess.get_files_at(Controls.SCREENSHOT_DIR):
		DirAccess.remove_absolute(Controls.SCREENSHOT_DIR.path_join(file_name))


func _screenshot_count() -> int:
	if not DirAccess.dir_exists_absolute(Controls.SCREENSHOT_DIR):
		return 0
	return DirAccess.get_files_at(Controls.SCREENSHOT_DIR).size()


## Builds the HUD with [param overrides] applied to its exports before it enters the tree, which is where it
## reads them.
func _make_controls(overrides: Dictionary = {}, extra: Dictionary = {}) -> Controls:
	var controls: Controls = CONTROLS_SCENE.instantiate()
	for property: String in overrides:
		controls.set(property, overrides[property])
	controls.extra_actions = extra
	add_child_autofree(controls)
	return controls


func test_defaults_are_godots_own_actions() -> void:
	_controls = _make_controls()
	assert_eq(_controls.joypad_button_0.action, &"ui_accept", "The bottom face button is Godot's accept")
	assert_eq(_controls.joypad_button_1.action, &"ui_cancel", "The right face button is Godot's cancel")
	assert_eq(_controls.joypad_button_3.action, &"ui_select", "The top face button is Godot's select")
	assert_eq(_controls.joypad_button_11.action, &"ui_up", "The d-pad drives the ui_* directions")
	assert_eq(_controls.joypad_button_14.action, &"ui_right")
	assert_eq(_controls.key_w.action, &"ui_up", "WASD drives the same directions as the left stick")
	assert_eq(_controls.left_joystick.action_left, &"ui_left")


func test_exported_action_reaches_the_button() -> void:
	_controls = _make_controls({"action_button_0": &"test_interact", "action_axis_4_plus": &"test_aim"})
	assert_eq(_controls.joypad_button_0.action, &"test_interact")
	assert_eq(_controls.joypad_axis_4_plus.action, &"test_aim")


## The d-pad and the I, J, K, L keys are two ways of pressing the same four things, so one export drives both.
func test_one_slot_drives_the_joypad_button_and_its_key() -> void:
	_controls = _make_controls({"action_button_11": &"test_menu"})
	assert_eq(_controls.joypad_button_11.action, &"test_menu")
	assert_eq(_controls.key_i.action, &"test_menu", "The [I] key is the keyboard face of d-pad up")


func test_stick_actions_reach_the_joysticks() -> void:
	_controls = _make_controls({"action_look_up": &"test_look_up", "action_look_down": &"test_look_down"})
	assert_eq(_controls.right_joystick.action_up, &"test_look_up")
	assert_eq(_controls.right_joystick.action_down, &"test_look_down")
	assert_eq(_controls.key_up.action, &"test_look_up", "The arrow keys are the keyboard face of the right stick")


func test_a_blank_slot_is_hidden() -> void:
	_controls = _make_controls()
	assert_false(_controls.joypad_button_2.visible, "The left face button has no Godot default, so it is unused")
	assert_false(_controls.right_joystick.visible, "Nothing looks around by default, so the right stick is unused")
	assert_true(_controls.joypad_button_0.visible, "The bottom face button is mapped, so it shows")


func test_a_mapped_slot_is_shown() -> void:
	_controls = _make_controls({"action_button_2": &"test_attack"})
	assert_true(_controls.joypad_button_2.visible, "Mapping the left face button brings it back")


## The whole point of the drop-in: a project names an action it never declared and the addon binds it to the
## button that slot stands for.
func test_an_unknown_action_is_registered_on_its_own_button() -> void:
	assert_false(InputMap.has_action("test_interact"), "The action does not exist before the HUD is built")
	_controls = _make_controls({"action_button_0": &"test_interact"})
	assert_true(InputMap.has_action("test_interact"), "The HUD registered it")
	var pressed: InputEventJoypadButton = InputEventJoypadButton.new()
	pressed.button_index = JOY_BUTTON_A
	assert_true(InputMap.action_has_event("test_interact", pressed), "Bound to the button it is drawn on")


func test_extra_actions_add_what_the_pad_cannot_describe() -> void:
	_controls = _make_controls(
		{"action_button_0": &"test_interact"},
		{"test_interact": {"keys": [KEY_E]}},
	)
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_E
	assert_true(InputMap.action_has_event("test_interact", key_event), "The keyboard binding came from extra_actions")
	var pressed: InputEventJoypadButton = InputEventJoypadButton.new()
	pressed.button_index = JOY_BUTTON_A
	assert_true(InputMap.action_has_event("test_interact", pressed), "and the slot still added its own button")


func test_a_project_action_is_left_alone() -> void:
	InputMap.add_action("test_attack")
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = KEY_Z
	InputMap.action_add_event("test_attack", key_event)

	_controls = _make_controls({"action_button_2": &"test_attack"})

	var pressed: InputEventJoypadButton = InputEventJoypadButton.new()
	pressed.button_index = JOY_BUTTON_X
	assert_false(InputMap.action_has_event("test_attack", pressed), "A binding the project already made is its own")
	assert_true(InputMap.action_has_event("test_attack", key_event), "and it is untouched")


## The View, pause and Screenshot slots draw an F5, an Escape and a Print Screen key, so those are the keys
## the addon has to register for them. A key face that names a key the slot does not answer to is a lie.
func test_the_system_slots_bind_the_keys_their_faces_show() -> void:
	_controls = _make_controls({
		"action_button_4": &"test_view",
		"action_button_6": &"test_pause",
		"action_button_15": &"test_shot",
	})

	for pair: Array in [["test_view", KEY_F5], ["test_pause", KEY_ESCAPE], ["test_shot", KEY_PRINT]]:
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = pair[1]
		assert_true(InputMap.action_has_event(pair[0], key_event),
			"%s answers to %s" % [pair[0], OS.get_keycode_string(pair[1])])


## The editor gets its own pass, because _ready bails out there rather than registering actions or swapping
## textures. Without it a scene shows every button on the HUD, mapped or not, which is not what ships: an
## AlleyCat-style consumer instances controls.tscn with no overrides at all and would show a Zoom button for
## a game that never asked for one.
func test_the_editor_preview_hides_what_the_game_did_not_map() -> void:
	_controls = _make_controls()
	for item: CanvasItem in _controls._previewable_items():
		item.visible = true

	_controls.preview_in_editor()

	assert_false(_controls.joypad_button_8.visible, "The right stick click is blank by default, so no Zoom")
	assert_false(_controls.joypad_button_9.visible, "nor a shoulder")
	assert_false(_controls.joypad_axis_4_plus.visible, "nor a trigger")
	assert_false(_controls.right_joystick.visible, "nor the stick nothing looks around with")
	assert_true(_controls.joypad_button_0.visible, "The bottom face button is ui_accept, so it stays")
	assert_true(_controls.joypad_button_11.visible, "and the d-pad is ui_up and friends")


## Mapping a slot brings its button back, so the inspector shows the change as it is typed.
func test_the_editor_preview_follows_a_slot_being_mapped() -> void:
	_controls = _make_controls()
	_controls.preview_in_editor()
	assert_false(_controls.joypad_button_8.visible, "Blank to begin with")

	_controls.action_button_8 = &"test_zoom"
	_controls.preview_in_editor()
	assert_true(_controls.joypad_button_8.visible, "and back the moment it is mapped")


## The preview obeys the device the same way the running HUD does, so the editor is not showing a keyboard
## set over a pad set or the other way round.
func test_the_editor_preview_obeys_the_device() -> void:
	_controls = _make_controls()
	_controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	_controls.preview_in_editor()
	assert_true(_controls.key_w.visible, "On keyboard the mapped letter keys show")
	assert_false(_controls.left_joystick.visible, "and the stick does not")
	assert_false(_controls.dpad_base.visible, "nor the d-pad cross")

	_controls.current_input_type = Controls.InputType.SONY
	_controls.preview_in_editor()
	assert_false(_controls.key_w.visible, "On a pad the letter keys go away")
	assert_true(_controls.left_joystick.visible, "and the stick comes back")


## Writing a visibility that already matches would mark an untouched scene as modified in the editor.
func test_the_editor_preview_writes_nothing_when_it_already_matches() -> void:
	_controls = _make_controls()
	_controls.preview_in_editor()
	var before: Array[bool] = []
	for item: CanvasItem in _controls._previewable_items():
		before.append(item.visible)

	_controls.preview_in_editor()

	var after: Array[bool] = []
	for item: CanvasItem in _controls._previewable_items():
		after.append(item.visible)
	assert_eq(before, after, "A second pass changes nothing")


## Godot's own ui_* actions are the exception: they are extended rather than skipped, so the on-screen
## d-pad works even though the engine declared the action first.
func test_builtin_ui_actions_are_extended() -> void:
	_controls = _make_controls()
	var dpad_up: InputEventJoypadButton = InputEventJoypadButton.new()
	dpad_up.button_index = JOY_BUTTON_DPAD_UP
	assert_true(InputMap.action_has_event("ui_up", dpad_up), "ui_up answers to the d-pad")


func test_keyboard_and_joypad_sets_swap() -> void:
	_controls = _make_controls({"action_look_up": &"test_look_up"})

	_controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	assert_true(_controls.key_w.visible, "On keyboard the letter keys show")
	assert_false(_controls.left_joystick.visible, "and the sticks do not")
	assert_false(_controls.dpad_base.visible, "nor the cross the d-pad buttons sit on")

	_controls.current_input_type = Controls.InputType.SONY
	assert_false(_controls.key_w.visible, "On a pad the letter keys go away")
	assert_true(_controls.left_joystick.visible, "and the sticks come back")
	assert_true(_controls.dpad_base.visible, "and so does the d-pad cross")


## A click is the only signal a mouse player gives on a HUD that starts out showing touch controls, so it has
## to count on its own rather than only while the mouse is captured.
func test_a_mouse_click_swaps_to_the_keyboard_set() -> void:
	_controls = _make_controls()
	_controls.current_input_type = Controls.InputType.TOUCH

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_controls._input(click)

	assert_eq(_controls.current_input_type, Controls.InputType.KEYBOARD_MOUSE, "A click is someone at a mouse")
	assert_true(_controls.key_w.visible, "so the letter keys show")
	assert_false(_controls.left_joystick.visible, "and the touch sticks go away")


## A touchscreen sends mouse events of its own where the project emulates them, marked with
## DEVICE_ID_EMULATION. Taking those for a mouse would drop the touch controls the moment they were used.
func test_a_touch_emulated_click_stays_on_touch() -> void:
	_controls = _make_controls()
	_controls.current_input_type = Controls.InputType.TOUCH

	var emulated: InputEventMouseButton = InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	_controls._input(emulated)

	assert_eq(_controls.current_input_type, Controls.InputType.TOUCH, "An emulated click is a finger, not a mouse")


## Mouse motion still needs the mouse captured, so a knock of the desk does not take a pad player's HUD away.
func test_free_mouse_motion_leaves_a_pad_player_alone() -> void:
	_controls = _make_controls()
	_controls.current_input_type = Controls.InputType.MICROSOFT

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(4, 4)
	_controls._input(motion)

	assert_eq(_controls.current_input_type, Controls.InputType.MICROSOFT, "The pad HUD stays put")


func test_input_type_change_swaps_the_button_art() -> void:
	_controls = _make_controls()
	_controls.current_input_type = Controls.InputType.SONY
	var sony: Texture2D = _controls.joypad_button_0.texture_normal
	_controls.current_input_type = Controls.InputType.NINTENDO
	assert_ne(_controls.joypad_button_0.texture_normal, sony, "The face button is drawn for the pad in hand")


func test_input_type_changed_is_emitted() -> void:
	_controls = _make_controls()
	watch_signals(_controls)
	_controls.current_input_type = Controls.InputType.MICROSOFT
	assert_signal_emitted_with_parameters(_controls, "input_type_changed", [Controls.InputType.MICROSOFT])


func test_set_labels_writes_the_ones_given_and_clears_the_rest() -> void:
	_controls = _make_controls()
	_controls.set_labels({_controls.joypad_button_0_label: "Select"})
	assert_eq(_controls.joypad_button_0_label.text, "Select")
	assert_eq(_controls.joypad_button_3_label.text, "", "A label not named is cleared")


## A state names the joypad label and gets the key that does the same job for free.
func test_set_labels_mirrors_onto_the_keyboard_set() -> void:
	_controls = _make_controls()
	_controls.set_labels({
		_controls.joypad_button_11_label: "Inventory",
		_controls.left_joystick_label: "Walk",
	})
	assert_eq(_controls.key_i_label.text, "Inventory", "The [I] key reads what d-pad up reads")
	assert_eq(_controls.key_s_label.text, "Walk", "The [S] key reads what the left stick reads")


## The HUD names no button for you. A label is what the game calls that button in that moment, and the addon
## cannot know it, so every one of them starts empty and a project writes them with set_labels or in its own
## scene - which is what the demo does.
func test_every_label_starts_blank() -> void:
	_controls = _make_controls()
	for label: Label in _controls.all_labels:
		assert_eq(label.text, "", "%s is the game's to name" % label.get_parent().name)


func test_reset_labels_restores_the_scene_text() -> void:
	_controls = _make_controls()
	var original: String = _controls.joypad_button_0_label.text
	_controls.set_labels({_controls.joypad_button_0_label: "Select"})
	_controls.reset_labels()
	assert_eq(_controls.joypad_button_0_label.text, original)


func test_a_claimed_prompt_label_survives_a_reset() -> void:
	_controls = _make_controls()
	var owner: RefCounted = RefCounted.new()
	_controls.claim_action_label("Pick Up", owner)
	assert_eq(_controls.joypad_button_0_label.text, "Pick Up")
	_controls.reset_labels()
	assert_eq(_controls.joypad_button_0_label.text, "Pick Up", "The prompt keeps the button through a refresh")
	_controls.set_labels({_controls.joypad_button_1_label: "Back"})
	assert_eq(_controls.joypad_button_0_label.text, "Pick Up", "and through a state's own labels")


## Walking out of one prompt while standing in another must leave the second one's label alone.
func test_only_the_claimant_can_give_the_label_back() -> void:
	_controls = _make_controls()
	var first: RefCounted = RefCounted.new()
	var second: RefCounted = RefCounted.new()
	_controls.claim_action_label("Pick Up", first)
	_controls.claim_action_label("Get In", second)

	_controls.release_action_label(first)
	assert_eq(_controls.prompt_action_label, "Get In", "The first prompt cannot release the second's label")

	_controls.release_action_label(second)
	assert_eq(_controls.prompt_action_label, "", "Its own claimant can")


func test_releasing_asks_for_the_contextual_labels_back() -> void:
	_controls = _make_controls()
	var owner: RefCounted = RefCounted.new()
	_controls.claim_action_label("Pick Up", owner)
	watch_signals(_controls)
	_controls.release_action_label(owner)
	assert_signal_emitted(_controls, "contextual_labels_requested")


func test_rumble_is_for_pads_only() -> void:
	_controls = _make_controls()
	_controls.current_input_type = Controls.InputType.KEYBOARD_MOUSE
	assert_false(_controls.rumble(0.5, 0.5, 0.1), "Keyboards do not rumble")
	_controls.current_input_type = Controls.InputType.TOUCH
	assert_false(_controls.rumble(0.5, 0.5, 0.1), "Nor does a touchscreen")
	_controls.current_input_type = Controls.InputType.MICROSOFT
	assert_true(_controls.rumble(0.5, 0.5, 0.1), "A pad does")


## The share button is the one slot the HUD fills in for itself, because it has something to put on it.
func test_the_share_button_is_the_screenshot_button() -> void:
	_controls = _make_controls()
	assert_eq(_controls.action_button_15, &"take_screenshot")
	assert_eq(_controls.joypad_button_15.action, &"take_screenshot", "and it is on the button")
	assert_true(InputMap.has_action("take_screenshot"), "registered like any other slot")
	assert_true(_controls.joypad_button_15.visible, "and shown, where every other unset slot is hidden")
	assert_eq(_controls.joypad_button_15_label.text, "", "The label is the game's to write, like every other")


func test_a_project_can_still_have_the_slot_or_drop_it() -> void:
	_controls = _make_controls({"action_button_15": &"test_menu"})
	assert_eq(_controls.joypad_button_15.action, &"test_menu", "A project's own action goes on it")
	_controls = _make_controls({"action_button_15": &""})
	assert_false(_controls.joypad_button_15.visible, "and blanking it drops the button, as anywhere else")


func test_pressing_share_saves_a_png_of_the_screen() -> void:
	if DisplayServer.get_name() == "headless":
		pass_test("Headless draws nothing, so there is no screen to capture")
		return
	_controls = _make_controls()
	_clear_screenshots()
	var path: String = await _controls.take_screenshot()
	assert_eq(_screenshot_count(), 1, "One file for one press")
	assert_true(path.ends_with(".png"))
	assert_true(FileAccess.file_exists(path), "at %s" % ProjectSettings.globalize_path(path))
	var saved: Image = Image.load_from_file(path)
	assert_eq(saved.get_size(), get_viewport().size, "the whole screen, at its own size")
	assert_true(_controls.visible, "and the HUD is back afterwards")


func test_the_hud_is_not_in_the_picture() -> void:
	if DisplayServer.get_name() == "headless":
		pass_test("Headless draws nothing, so there is no screen to capture")
		return
	_controls = _make_controls()
	# Watching the frames themselves. The HUD is only down for the one that gets captured, which is over well
	# inside a single idle frame, so nothing slower than this can see it.
	# An array because a lambda captures a local by value, and this has to come back out of it.
	var seen_hidden: Array[bool] = [false]
	var watcher: Callable = func() -> void:
		seen_hidden[0] = seen_hidden[0] or not _controls.visible
	RenderingServer.frame_pre_draw.connect(watcher)
	await _controls.take_screenshot()
	RenderingServer.frame_pre_draw.disconnect(watcher)
	assert_true(seen_hidden[0], "The buttons are out of the frame")
	assert_true(_controls.visible, "and back the moment it is taken")


## A game that had already hidden the HUD - a cutscene, a menu - does not get it handed back lit up.
func test_a_hidden_hud_stays_hidden() -> void:
	if DisplayServer.get_name() == "headless":
		pass_test("Headless draws nothing, so there is no screen to capture")
		return
	_controls = _make_controls()
	_controls.hide()
	await _controls.take_screenshot()
	assert_false(_controls.visible)


func test_a_project_that_captures_its_own_way_can_turn_it_off() -> void:
	if DisplayServer.get_name() == "headless":
		pass_test("Headless draws nothing, so there is no screen to capture")
		return
	_controls = _make_controls({"takes_screenshots": false})
	_clear_screenshots()
	var press: InputEventAction = InputEventAction.new()
	press.action = _controls.action_button_15
	press.pressed = true
	_controls._input(press)
	await wait_frames(3)
	assert_eq(_screenshot_count(), 0, "The button is still there; the HUD just does not act on it")


## The keyboard set's stick and d-pad keys were baked into the scene, so a project binding anything other
## than WASD and IJKL showed its players the wrong keys with no way to say otherwise. They are exported now,
## the way the face buttons always were.
func test_the_stick_and_dpad_keys_take_a_projects_own_key_faces() -> void:
	var arrow_up: Texture2D = load(KEY_ART.path_join("keyboard_arrow_up_outline.svg"))
	var arrow_up_pressed: Texture2D = load(KEY_ART.path_join("keyboard_arrow_up.svg"))
	var controls: Controls = _make_controls({
		"keyboard_mouse_move_up_normal": arrow_up,
		"keyboard_mouse_move_up_pressed": arrow_up_pressed,
		"keyboard_mouse_button_11_normal": arrow_up,
		"keyboard_mouse_look_left_normal": arrow_up,
	})
	assert_eq(controls.key_w.texture_normal, arrow_up, "the left stick's forward key")
	assert_eq(controls.key_w.texture_pressed, arrow_up_pressed, "and its pressed state")
	assert_eq(controls.key_i.texture_normal, arrow_up, "the d-pad's up key")
	assert_eq(controls.key_left.texture_normal, arrow_up, "the right stick's left key")


## A project that binds WASD and the arrows like everyone else sets none of them, so a blank export has to
## leave the scene's own art alone rather than blanking the button.
func test_a_key_face_left_blank_keeps_the_scenes_own() -> void:
	var controls: Controls = _make_controls()
	for button: TouchScreenButton in [controls.key_w, controls.key_a, controls.key_s, controls.key_d,
			controls.key_i, controls.key_j, controls.key_k, controls.key_l,
			controls.key_up, controls.key_down, controls.key_left, controls.key_right]:
		assert_not_null(button.texture_normal, "%s keeps a face" % button.name)


## The override has to be in place before the held-state swap caches what "not pressed" looks like, or
## letting go of a key would put the addon's default art back.
func test_a_key_face_survives_being_pressed_and_released() -> void:
	var arrow_up: Texture2D = load(KEY_ART.path_join("keyboard_arrow_up_outline.svg"))
	var controls: Controls = _make_controls({"keyboard_mouse_move_up_normal": arrow_up})
	controls.update_input_ui()
	assert_eq(controls.key_w.texture_normal, arrow_up, "still the project's own after a redraw")


## The catalog turns every slot into a picker, so a project whose game only answers to a known list of
## actions cannot put anything else on a button.
func test_a_catalog_turns_the_slots_into_a_picker() -> void:
	var catalog: ControlsInputCatalog = ControlsInputCatalog.new()
	catalog.actions = [&"game_up", &"game_down", &"game_fire"]
	var controls: Controls = _make_controls({"input_catalog": catalog})
	for property: Dictionary in controls.get_property_list():
		if not String(property["name"]).begins_with("action_"):
			continue
		assert_eq(property["hint"], PROPERTY_HINT_ENUM, "%s is a picker" % property["name"])
		assert_eq(property["hint_string"], ",game_up,game_down,game_fire", property["name"])


## Without one the slots stay free text, which is every project that was using this before.
func test_no_catalog_leaves_the_slots_as_they_were() -> void:
	var controls: Controls = _make_controls()
	for property: Dictionary in controls.get_property_list():
		if String(property["name"]).begins_with("action_"):
			assert_ne(property["hint"], PROPERTY_HINT_ENUM, "%s is still free text" % property["name"])


## A slot left blank is a button the game does not use and the HUD hides it, so the picker has to offer
## that as a choice even though it is not in the catalog.
func test_the_picker_always_offers_a_blank_choice() -> void:
	var catalog: ControlsInputCatalog = ControlsInputCatalog.new()
	catalog.actions = [&"game_up"]
	assert_true(catalog.hint_string().begins_with(","), "the first choice is blank")
	assert_true(catalog.has_action(&""), "and blank is a valid slot")
	assert_true(catalog.has_action(&"game_up"))
	assert_false(catalog.has_action(&"game_sideways"))


## A catalog is written by hand or generated, and either way can end up with a blank or a repeat in it.
func test_the_picker_drops_blanks_and_repeats() -> void:
	var catalog: ControlsInputCatalog = ControlsInputCatalog.new()
	catalog.actions = [&"game_up", &"", &"game_up", &"game_down"]
	assert_eq(catalog.hint_string(), ",game_up,game_down")
