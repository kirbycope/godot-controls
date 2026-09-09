extends GutTest
## Covers the part of the HUD a consuming project actually configures: which action each button drives, what
## gets registered in the InputMap, which buttons are shown, and how the labels behave.

const CONTROLS_SCENE: PackedScene = preload("res://addons/controls/controls.tscn")

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

	_controls.current_input_type = Controls.InputType.SONY
	assert_false(_controls.key_w.visible, "On a pad the letter keys go away")
	assert_true(_controls.left_joystick.visible, "and the sticks come back")


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
