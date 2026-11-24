## 一次性工具：把 InputMap 動作和像素對齊設定寫進 project.godot。
## 執行：Godot --headless --path . --script res://tools/setup_project_settings.gd
## 之後要改按鍵，可以直接在編輯器的「專案設定 > 輸入對應」修改，或改這支腳本再執行一次。
extends SceneTree


func _init() -> void:
	# 動作名稱 → [鍵盤實體按鍵..., 滑鼠按鍵..., 手把按鈕..., 手把軸向...]
	var actions := {
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"run": [_key(KEY_SHIFT), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		"sneak": [_key(KEY_C), _joy(JOY_BUTTON_LEFT_STICK)],
		"aim": [_mouse(MOUSE_BUTTON_RIGHT), _key(KEY_K), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"fire": [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"switch_target": [_key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"reload": [_key(KEY_R), _joy(JOY_BUTTON_X)],
		"interact": [_key(KEY_E), _joy(JOY_BUTTON_A)],
		"flashlight": [_key(KEY_F), _joy(JOY_BUTTON_Y)],
		"throw": [_key(KEY_G), _joy(JOY_BUTTON_B)],
		"inventory": [_key(KEY_TAB), _joy(JOY_BUTTON_BACK)],
		"map": [_key(KEY_M), _joy(JOY_BUTTON_DPAD_UP)],
		"pause": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		"debug_toggle": [_key(KEY_F3)],
	}
	for action_name in actions:
		ProjectSettings.set_setting("input/" + action_name, {
			"deadzone": 0.2,
			"events": actions[action_name],
		})

	# 像素對齊，避免 480x270 下移動時抖動
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", true)
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", true)

	# 自動載入
	ProjectSettings.set_setting("autoload/NoiseBus", "*res://scripts/autoload/noise_bus.gd")
	ProjectSettings.set_setting("autoload/WorldState", "*res://scripts/autoload/world_state.gd")
	ProjectSettings.set_setting("autoload/Missions", "*res://scripts/autoload/missions.gd")

	var err := ProjectSettings.save()
	print("project.godot saved: ", error_string(err))
	quit(0 if err == OK else 1)


func _key(keycode: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1  # 所有裝置
	e.physical_keycode = keycode
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1  # 所有裝置
	e.button_index = button
	return e


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1  # 所有裝置
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1  # 所有裝置
	e.axis = axis
	e.axis_value = value
	return e
