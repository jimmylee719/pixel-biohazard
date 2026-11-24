## 原型主場景：把關卡、主角、敵人、鏡頭、HUD、除錯顯示接在一起。
extends Node2D

const RESET_DELAY := 1.5
const ENEMY_SCENES := {
	"patroller": preload("res://scenes/enemy.tscn"),
	"listener": preload("res://scenes/enemy_listener.tscn"),
}

@onready var _level: Level = $Level
@onready var _player: Player = $Player
@onready var _enemy_root: Node2D = $Enemies
@onready var _camera: FollowCamera = $Camera
@onready var _overlay: DebugOverlay = $Overlay/DebugOverlay
@onready var _hint: Label = $HUD/Hint
@onready var _status: Label = $HUD/Status
@onready var _prompt: Label = $HUD/Prompt
@onready var _items: Label = $HUD/Items
@onready var _vignette: TextureRect = $HUD/HideVignette
@onready var _banner: Label = $HUD/Banner

var enemies: Array[Enemy] = []
var _resetting := false


func _ready() -> void:
	_player.level = _level
	_player.reset_to(_level.player_spawn)
	_player.hiding_changed.connect(func(is_hidden: bool): _vignette.visible = is_hidden)

	for def in _level.enemy_defs:
		var enemy: Enemy = ENEMY_SCENES[def.type].instantiate()
		_enemy_root.add_child(enemy)
		enemy.setup(def.points, _player, _level)
		enemy.caught_player.connect(_on_caught)
		enemies.append(enemy)

	for item in _level.get_interactables():
		if item is ExitPoint:
			item.reached.connect(_on_escaped)

	_camera.setup(_player, _level.bounds)
	_overlay.setup(_player, enemies, _level)
	_vignette.texture = _make_vignette()
	_banner.visible = false
	_hint.text = _build_hint()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_overlay.debug_enabled = not _overlay.debug_enabled

	var focus := _player.focus
	_prompt.text = "[%s] %s" % [_key_name("interact"), focus.get_prompt(_player)] if focus and _player.input_enabled else ""
	_items.text = "Bottles %d/%d  [%s] throw" % [_player.bottles, _player.max_bottles, _key_name("throw")]

	_status.visible = _overlay.debug_enabled
	if _status.visible:
		var lines := ["%s  light:%s  zone:%s%s" % [
			_player.get_gait_name(),
			"ON" if _player.flashlight_on else "OFF",
			_level.zone_at(_player.global_position),
			" (cold)" if _level.is_cold(_player.global_position) else "",
		]]
		for enemy in enemies:
			lines.append("%s: %s %d%%%s" % [
				enemy.display_name, enemy.get_state_name(), roundi(enemy.awareness * 100.0),
				" cold" if enemy.in_cold else ""])
		_status.text = "\n".join(lines)


func _on_caught() -> void:
	_end_attempt("CAUGHT", Color(1, 0.3, 0.25))


func _on_escaped() -> void:
	_end_attempt("ESCAPED", Color(0.5, 1, 0.6))


func _end_attempt(text: String, color: Color) -> void:
	if _resetting:
		return
	_resetting = true
	_player.input_enabled = false
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	await get_tree().create_timer(RESET_DELAY).timeout
	reset_attempt()


## 關卡、主角、敵人全部回到初始狀態。
func reset_attempt() -> void:
	_level.reset_state()
	_player.reset_to(_level.player_spawn)
	for enemy in enemies:
		enemy.reset()
	_camera.snap_to_target()
	_banner.visible = false
	_player.input_enabled = true
	_resetting = false


## 躲在櫃子裡時，畫面四周變暗，只留中間一小圈。
func _make_vignette() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.92))
	g.add_point(0.35, Color(0, 0, 0, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 240
	t.height = 135
	return t


## 操作說明直接從 InputMap 讀，改按鍵時不用改這裡。
func _build_hint() -> String:
	var parts := [
		"%s move" % "/".join(["move_up", "move_left", "move_down", "move_right"].map(_key_name)),
		"%s run" % _key_name("run"),
		"%s sneak" % _key_name("sneak"),
		"%s light" % _key_name("flashlight"),
		"%s use" % _key_name("interact"),
		"%s debug" % _key_name("debug_toggle"),
	]
	return "  ".join(parts)


func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
