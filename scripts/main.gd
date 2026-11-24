## Prototype 0 主場景：把關卡、主角、敵人、鏡頭、除錯顯示接在一起。
extends Node2D

const CAUGHT_RESET_DELAY := 1.5

@onready var _level: Level = $Level
@onready var _player: Player = $Player
@onready var _enemy: Enemy = $Enemy
@onready var _camera: FollowCamera = $Camera
@onready var _overlay: DebugOverlay = $Overlay/DebugOverlay
@onready var _hint: Label = $HUD/Hint
@onready var _status: Label = $HUD/Status
@onready var _banner: Label = $HUD/Banner

var _resetting := false


func _ready() -> void:
	_player.reset_to(_level.player_spawn)
	_enemy.setup(_level.patrol_points, _player, _level.get_navigation_map())
	_enemy.caught_player.connect(_on_caught)
	_camera.setup(_player, _level.bounds)
	_overlay.setup(_player, [_enemy] as Array[Enemy])
	_banner.visible = false
	_hint.text = _build_hint()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_overlay.debug_enabled = not _overlay.debug_enabled
	_status.visible = _overlay.debug_enabled
	if _status.visible:
		_status.text = "%s  light:%s\nenemy:%s  aware:%d%%" % [
			_player.get_gait_name(),
			"ON" if _player.flashlight_on else "OFF",
			_enemy.get_state_name(),
			roundi(_enemy.awareness * 100.0),
		]


func _on_caught() -> void:
	if _resetting:
		return
	_resetting = true
	_player.input_enabled = false
	_banner.text = "CAUGHT"
	_banner.visible = true
	await get_tree().create_timer(CAUGHT_RESET_DELAY).timeout
	_player.reset_to(_level.player_spawn)
	_enemy.reset()
	_camera.snap_to_target()
	_banner.visible = false
	_player.input_enabled = true
	_resetting = false


## 操作說明直接從 InputMap 讀，改按鍵時不用改這裡。
func _build_hint() -> String:
	var parts := [
		"%s move" % _keys_for(["move_up", "move_left", "move_down", "move_right"]),
		"%s run" % _keys_for(["run"]),
		"%s sneak" % _keys_for(["sneak"]),
		"%s light" % _keys_for(["flashlight"]),
		"%s debug" % _keys_for(["debug_toggle"]),
	]
	return "  ".join(parts)


func _keys_for(actions: Array) -> String:
	var names: Array[String] = []
	for action in actions:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				names.append(event.as_text_physical_keycode())
				break
	return "/".join(names) if actions.size() > 1 else (names[0] if names.size() > 0 else "?")
