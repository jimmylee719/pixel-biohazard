## 遊戲主場景（世界管理）：載入區域、門的切換、檢查點、任務 HUD、除錯顯示。
## 區域本身由 Level 依 Areas 的資料建立；跨區域的狀態都存在 WorldState。
extends Node2D

const RESET_DELAY := 1.5
const FADE_TIME := 0.2
const MESSAGE_TIME := 6.0
## 室內一片漆黑；戶外有雪地反光，稍微亮一點
const INDOOR_DARKNESS := Color(0.05, 0.05, 0.08)
const OUTDOOR_DARKNESS := Color(0.2, 0.22, 0.3)
const ENEMY_SCENES := {
	"patroller": preload("res://scenes/enemy.tscn"),
	"listener": preload("res://scenes/enemy_listener.tscn"),
}

var level: Level
var enemies: Array[Enemy] = []

var _resetting := false
var _transitioning := false
var _message_timer := 0.0

@onready var _darkness: CanvasModulate = $Darkness
@onready var _player: Player = $Player
@onready var _enemy_root: Node2D = $Enemies
@onready var _camera: FollowCamera = $Camera
@onready var _overlay: DebugOverlay = $Overlay/DebugOverlay
@onready var _hint: Label = $HUD/Hint
@onready var _status: Label = $HUD/Status
@onready var _prompt: Label = $HUD/Prompt
@onready var _items: Label = $HUD/Items
@onready var _objective: Label = $HUD/Objective
@onready var _message: Label = $HUD/Message
@onready var _vignette: TextureRect = $HUD/HideVignette
@onready var _banner: Label = $HUD/Banner
@onready var _mission_panel: PanelContainer = $HUD/MissionPanel
@onready var _mission_text: Label = $HUD/MissionPanel/Text
@onready var _fade: ColorRect = $HUD/Fade


func _ready() -> void:
	_player.hiding_changed.connect(func(is_hidden: bool): _vignette.visible = is_hidden)
	_overlay.setup(_player)
	_vignette.texture = _make_vignette()
	_banner.visible = false
	_hint.text = _build_hint()
	Missions.mission_completed.connect(func(id: String):
		show_message("MISSION COMPLETE: %s" % Missions.get_mission(id).title))
	await load_area(WorldState.data.area, WorldState.data.entry, false)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_overlay.debug_enabled = not _overlay.debug_enabled
	if Input.is_action_just_pressed("map") and not _resetting and not _transitioning:
		_toggle_mission_panel()

	_message_timer -= delta
	if _message_timer <= 0.0:
		_message.visible = false

	var focus := _player.focus
	_prompt.text = "[%s] %s" % [_key_name("interact"), focus.get_prompt(_player)] if focus and _player.input_enabled else ""
	_items.text = "Bottles %d/%d  [%s] throw" % [_player.bottles, _player.max_bottles, _key_name("throw")]
	var tracked := Missions.tracked_mission()
	_objective.text = "> %s" % tracked.title if not tracked.is_empty() else ""
	_update_status()


func _physics_process(_delta: float) -> void:
	if level == null or _transitioning or _resetting or _player.is_hiding or not _player.input_enabled:
		return
	var door := level.door_at(_player.global_position)
	if door != "":
		load_area(level.door_target(door), door)


# ── 區域 ──────────────────────────────────────────────

## 載入一個區域，主角站在 entry（門的 id 或 "start"）的位置。
func load_area(area_id: String, entry: String, fade := true) -> void:
	_transitioning = true
	_player.input_enabled = false
	if fade:
		await _fade_to(1.0)

	if level:
		level.queue_free()
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()

	level = Level.new()
	level.area_id = area_id
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	move_child(level, _darkness.get_index() + 1)

	for def in level.enemy_defs:
		var enemy: Enemy = ENEMY_SCENES[def.type].instantiate()
		_enemy_root.add_child(enemy)
		enemy.setup(def.points, _player, level)
		enemy.caught_player.connect(_on_caught)
		enemies.append(enemy)

	for item in level.get_interactables():
		if item is ExitPoint:
			item.reached.connect(_on_stairs)
		elif item is TapePickup:
			item.message_shown.connect(show_message)

	_darkness.color = OUTDOOR_DARKNESS if level.outdoor else INDOOR_DARKNESS
	_player.level = level
	_player.reset_to(level.get_entry_position(entry))
	_camera.setup(_player, level.bounds)
	_overlay.bind_area(level, enemies)

	# 先觸發「進入區域」的任務事件，再存檔查點，任務進度才會包含在檢查點裡
	WorldState.emit_event("enter_area", area_id)
	WorldState.save_checkpoint(area_id, entry)

	if fade:
		await _fade_to(0.0)
	_player.input_enabled = true
	_transitioning = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished


# ── 被抓到、重來 ──────────────────────────────────────

func _on_caught() -> void:
	_end_attempt("CAUGHT", Color(1, 0.3, 0.25))


func _on_stairs() -> void:
	_end_attempt("TO BE CONTINUED", Color(0.5, 1, 0.6), true)


func _end_attempt(text: String, color: Color, new_game := false) -> void:
	if _resetting:
		return
	_resetting = true
	_player.input_enabled = false
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	await get_tree().create_timer(RESET_DELAY).timeout
	if new_game:
		WorldState.new_game()
		_banner.visible = false
		await load_area(WorldState.data.area, WorldState.data.entry)
		_resetting = false
	else:
		reset_attempt()


## 回到最近的檢查點（目前所在區域的入口）。
func reset_attempt() -> void:
	WorldState.restore_checkpoint()
	level.sync_from_state()
	_player.reset_to(level.get_entry_position(WorldState.checkpoint_entry()))
	for enemy in enemies:
		enemy.reset()
	_camera.snap_to_target()
	_banner.visible = false
	_player.input_enabled = true
	_resetting = false


# ── HUD ───────────────────────────────────────────────

func show_message(text: String) -> void:
	if text == "":
		return
	_message.text = text
	_message.visible = true
	_message_timer = MESSAGE_TIME


func _toggle_mission_panel() -> void:
	_mission_panel.visible = not _mission_panel.visible
	get_tree().paused = _mission_panel.visible
	if _mission_panel.visible:
		_mission_text.text = _build_mission_text()


func _build_mission_text() -> String:
	var lines: Array[String] = ["MAIN OPS"]
	for main in [true, false]:
		if not main:
			lines.append("")
			lines.append("SIDE OPS")
		for m in Missions.list_visible():
			if m.main != main:
				continue
			var done := Missions.is_done(m.id)
			lines.append("%s %s" % ["[x]" if done else "[ ]", m.title])
			if not done:
				lines.append("    " + m.desc)
	lines.append("")
	lines.append("[%s] close" % _key_name("map"))
	return "\n".join(lines)


func _update_status() -> void:
	_status.visible = _overlay.debug_enabled
	if not _status.visible or level == null:
		return
	var lines := ["%s  %s  light:%s  zone:%s%s" % [
		level.title,
		_player.get_gait_name(),
		"ON" if _player.flashlight_on else "OFF",
		level.zone_at(_player.global_position),
		" (cold)" if level.is_cold(_player.global_position) else "",
	]]
	for enemy in enemies:
		lines.append("%s: %s %d%%%s" % [
			enemy.display_name, enemy.get_state_name(), roundi(enemy.awareness * 100.0),
			" cold" if enemy.in_cold else ""])
	_status.text = "\n".join(lines)


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
		"%s ops" % _key_name("map"),
		"%s debug" % _key_name("debug_toggle"),
	]
	return "  ".join(parts)


func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
