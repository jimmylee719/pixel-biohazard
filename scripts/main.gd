## 遊戲主場景（世界管理）：載入區域、門的切換、檢查點、任務 HUD、除錯顯示。
## 區域本身由 Level 依 Areas 的資料建立；跨區域的狀態都存在 WorldState。
extends Node2D

const RESET_DELAY := 1.5
const FADE_TIME := 0.2
const MESSAGE_TIME := 6.0
## 室內一片漆黑；戶外有雪地反光，稍微亮一點
const INDOOR_DARKNESS := Color(0.05, 0.05, 0.08)
const OUTDOOR_DARKNESS := Color(0.2, 0.22, 0.3)
## 安全屋：溫暖、比較亮，讓玩家感到安心（出門那一刻的落差也是恐怖的一部分）
const SAFE_DARKNESS := Color(0.34, 0.28, 0.22)
const TITLE_SCENE := "res://scenes/title.tscn"
const KOVAC_INTRO := "KOVAC: \"...is anyone on this channel? This is Dr. Ina Kovac, I left Greycrow two weeks ago. If you're in the clean room, you're safe. Listen carefully.\""
const ENEMY_SCENES := {
	"patroller": preload("res://scenes/enemy.tscn"),
	"listener": preload("res://scenes/enemy_listener.tscn"),
	"sleeper": preload("res://scenes/enemy_sleeper.tscn"),
}
## 原型的終點：讀完站長的紀錄
const PROTOTYPE_END_TERMINAL := "director_terminal"

var level: Level
var enemies: Array[Enemy] = []

var _resetting := false
var _transitioning := false
var _message_timer := 0.0
var _message_queue: Array[String] = []
var _inventory_cursor := 0
var _storage_cursor := 0
var _radio_freq := 12150
var _radio_transcript: Array[String] = []
## 剛剛已經提示過「門鎖著」的門（避免每一幀都跳訊息）
var _locked_door_notice := ""

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
@onready var _condition: Label = $HUD/Condition
@onready var _infection_vignette: TextureRect = $HUD/InfectionVignette
@onready var _hurt_flash: ColorRect = $HUD/HurtFlash
@onready var _inventory_panel: PanelContainer = $HUD/InventoryPanel
@onready var _inventory_text: Label = $HUD/InventoryPanel/Text
@onready var _storage_panel: PanelContainer = $HUD/StoragePanel
@onready var _storage_text: Label = $HUD/StoragePanel/Text
@onready var _radio_panel: PanelContainer = $HUD/RadioPanel
@onready var _radio_text: Label = $HUD/RadioPanel/Text
@onready var _pause_panel: PanelContainer = $HUD/PausePanel
@onready var _resume_button: Button = $HUD/PausePanel/Box/Resume
@onready var _quit_button: Button = $HUD/PausePanel/Box/QuitToTitle


func _ready() -> void:
	_player.hiding_changed.connect(func(is_hidden: bool): _vignette.visible = is_hidden)
	_overlay.setup(_player)
	_vignette.texture = _make_vignette()
	_infection_vignette.texture = _make_vignette(Color(0.75, 0.95, 1.0, 0.85))
	_player.died.connect(func(): _end_attempt("YOU DIED", Color(0.9, 0.2, 0.2)))
	_player.hurt.connect(func(_d): _hurt_flash.color.a = 0.45)
	_banner.visible = false
	_hint.text = _build_hint()
	Missions.mission_completed.connect(func(id: String):
		show_message("MISSION COMPLETE: %s" % Missions.get_mission(id).title))
	_resume_button.pressed.connect(_toggle_pause)
	_quit_button.pressed.connect(_quit_to_title)
	await load_area(WorldState.data.area, WorldState.data.entry, false)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_overlay.debug_enabled = not _overlay.debug_enabled
	var busy := _resetting or _transitioning or _player.is_dead
	if _pause_panel.visible:
		if Input.is_action_just_pressed("pause"):
			_toggle_pause()
	elif _inventory_panel.visible:
		_process_inventory_input()
	elif _storage_panel.visible:
		_process_storage_input()
	elif _radio_panel.visible:
		_process_radio_input()
	elif _mission_panel.visible:
		if Input.is_action_just_pressed("map") or Input.is_action_just_pressed("pause"):
			_toggle_mission_panel()
	elif not busy:
		if Input.is_action_just_pressed("pause"):
			_toggle_pause()
		elif Input.is_action_just_pressed("map"):
			_toggle_mission_panel()
		elif Input.is_action_just_pressed("inventory"):
			_toggle_inventory_panel()

	_hurt_flash.color.a = move_toward(_hurt_flash.color.a, 0.0, delta * 1.5)
	# 感染值越高，畫面四周越白（症狀）
	var infection_k := clampf((_player.infection - 30.0) / 70.0, 0.0, 1.0)
	_infection_vignette.modulate.a = infection_k * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004))

	_message_timer -= delta
	if _message_timer <= 0.0:
		if _message_queue.is_empty():
			_message.visible = false
		else:
			_show_next_message()

	var focus := _player.focus
	_prompt.text = "[%s] %s" % [_key_name("interact"), focus.get_prompt(_player)] if focus and _player.input_enabled else ""
	_items.text = _build_items_text()
	_condition.text = "Condition: %s%s" % [_player.get_condition(),
		"  (infected)" if _player.infection >= WorldState.MAX_INFECTION else ""]
	_condition.add_theme_color_override("font_color", {
		"Fine": Color(0.6, 1, 0.6), "Caution": Color(1, 0.85, 0.3), "Danger": Color(1, 0.35, 0.3)
	}[_player.get_condition()])
	var tracked := Missions.tracked_mission()
	_objective.text = "> %s" % tracked.title if not tracked.is_empty() else ""
	_update_status()


func _physics_process(_delta: float) -> void:
	if level == null or _transitioning or _resetting or _player.is_hiding or not _player.input_enabled:
		return
	var door := level.door_at(_player.global_position)
	if door == "":
		_locked_door_notice = ""
		return
	var need := level.door_access(door)
	if need > WorldState.access_level:
		if _locked_door_notice != door:
			_locked_door_notice = door
			show_message("Locked. Keycard access level %d required." % need, true)
		return
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

	for i in level.enemy_defs.size():
		var def: Dictionary = level.enemy_defs[i]
		var enemy: Enemy = ENEMY_SCENES[def.type].instantiate()
		enemy.enemy_key = "%s:%d" % [area_id, i]
		_enemy_root.add_child(enemy)
		enemy.setup(def.points, _player, level)
		enemies.append(enemy)

	for item in level.get_interactables():
		if item is ExitPoint:
			item.reached.connect(func(target: String): load_area(target, "stairs"))
		elif item is Terminal:
			item.used.connect(_on_terminal_used)
		elif item is TapePickup:
			item.message_shown.connect(show_message)
		elif item is ReadableNote:
			item.message_shown.connect(show_message)
		elif item is RadioConsole:
			item.used.connect(_on_radio_used)
		elif item is StorageBox:
			item.opened.connect(_toggle_storage_panel)

	if level.safe:
		_darkness.color = SAFE_DARKNESS
	elif level.outdoor:
		_darkness.color = OUTDOOR_DARKNESS
	else:
		_darkness.color = INDOOR_DARKNESS
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

func _on_terminal_used(item_name: String) -> void:
	show_message(level.get_message(item_name))
	if item_name == PROTOTYPE_END_TERMINAL:
		_end_attempt("TO BE CONTINUED", Color(0.5, 1, 0.6), true, MESSAGE_TIME)


func _end_attempt(text: String, color: Color, new_game := false, delay := RESET_DELAY) -> void:
	if _resetting:
		return
	_resetting = true
	_player.input_enabled = false
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	await get_tree().create_timer(delay).timeout
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

## 畫面下方的訊息（錄音內容、無線電、任務完成）。同時有好幾則就依序顯示。
## urgent = 立刻顯示（例如「門鎖著」），原本顯示中的訊息排回佇列最前面。
func show_message(text: String, urgent := false) -> void:
	if text == "":
		return
	if urgent:
		if _message.visible:
			_message_queue.push_front(_message.text)
		_message_queue.push_front(text)
		_show_next_message()
		return
	_message_queue.append(text)
	if not _message.visible:
		_show_next_message()


func _show_next_message() -> void:
	_message.text = _message_queue.pop_front()
	_message.visible = true
	_message_timer = MESSAGE_TIME


# ── 安全屋：無線電、儲物箱 ──────────────────────────────

## 用無線電：接收新的委託、在無線電旁邊存檢查點、存到硬碟，然後打開調頻介面。
func _on_radio_used() -> void:
	_radio_transcript.clear()
	if not WorldState.has_flag("radio:intro"):
		WorldState.set_flag("radio:intro")
		_radio_transcript.append(KOVAC_INTRO)
	for text in Missions.receive_radio():
		_radio_transcript.append(text)
	WorldState.save_checkpoint(level.area_id, "radio")
	_radio_transcript.append("Progress saved." if WorldState.save_to_disk() else "Save failed.")
	_radio_panel.visible = true
	get_tree().paused = true
	_refresh_radio()


# ── 無線電調頻 ────────────────────────────────────────

func _close_radio() -> void:
	_radio_panel.visible = false
	get_tree().paused = false


func _process_radio_input() -> void:
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("inventory") \
			or Input.is_action_just_pressed("pause"):
		_close_radio()
		return
	var step := 0
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
		step = Frequencies.FINE_STEP
	elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
		step = -Frequencies.FINE_STEP
	elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
		step = Frequencies.COARSE_STEP
	elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
		step = -Frequencies.COARSE_STEP
	if step != 0:
		tune_radio(_radio_freq + step)
	elif Input.is_action_just_pressed("switch_target"):
		_next_memo()
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		listen_radio()
	_refresh_radio()


func tune_radio(freq: int) -> void:
	_radio_freq = clampi(freq, Frequencies.BAND_MIN, Frequencies.BAND_MAX)


## 跳到備忘錄裡的下一個頻率
func _next_memo() -> void:
	var memo := WorldState.known_freqs()
	if memo.is_empty():
		return
	for f in memo:
		if f > _radio_freq:
			_radio_freq = f
			return
	_radio_freq = memo[0]


## 收聽目前的頻率：對準某個電台就播放內容，並設定它揭露的旗標（例如隱藏的武器出現）。
func listen_radio() -> Dictionary:
	_radio_transcript.clear()
	var station := Frequencies.find_exact(_radio_freq)
	if station.is_empty():
		_radio_transcript.append("Only static." if Frequencies.signal_strength(_radio_freq) < 0.5 \
			else "Something is there, buried in the static... fine-tune it.")
		return {}
	_radio_freq = station.freq
	for line in station.lines:
		_radio_transcript.append(line)
	WorldState.learn_freq(station.freq)
	WorldState.set_flag("freq_heard:" + station.id)
	if station.has("reveal") and not WorldState.has_flag(station.reveal):
		WorldState.set_flag(station.reveal)
	WorldState.emit_event("radio", station.id)
	return station


func _refresh_radio() -> void:
	var strength := Frequencies.signal_strength(_radio_freq)
	var bars := roundi(strength * 10.0)
	var memo_parts: Array[String] = []
	for f in WorldState.known_freqs():
		var mark := "*" if f == _radio_freq else ""
		memo_parts.append("%s%s %s" % [mark, Frequencies.format(f), Frequencies.by_freq(f).label])
	var lines: Array[String] = [
		"RADIO",
		"FREQUENCY  %s MHz" % Frequencies.format(_radio_freq),
		"SIGNAL     [%s%s]" % ["#".repeat(bars), "-".repeat(10 - bars)],
		"MEMO       %s" % ("  /  ".join(memo_parts) if not memo_parts.is_empty() else "(none)"),
		"",
	]
	lines.append_array(_radio_transcript)
	lines.append("")
	lines.append("[%s/%s] fine  [%s/%s] coarse  [%s] memo  [%s] listen  [%s] close" % [
		_key_name("move_left"), _key_name("move_right"), _key_name("move_up"), _key_name("move_down"),
		_key_name("switch_target"), _key_name("interact"), _key_name("inventory")])
	_radio_text.text = "\n".join(lines)


func _toggle_storage_panel() -> void:
	_storage_panel.visible = not _storage_panel.visible
	get_tree().paused = _storage_panel.visible
	_storage_cursor = 0
	_refresh_storage()


## 上面 6 行是物品欄，下面是儲物箱；選一行按確認就搬到另一邊。
func _storage_rows() -> Array:
	var rows := []
	for i in WorldState.inventory().size():
		rows.append({"side": "bag", "index": i})
	var ids := WorldState.storage().keys()
	ids.sort()
	for id in ids:
		rows.append({"side": "box", "id": id})
	return rows


func _process_storage_input() -> void:
	var rows := _storage_rows()
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("inventory") \
			or Input.is_action_just_pressed("pause"):
		_toggle_storage_panel()
		return
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		_storage_cursor = (_storage_cursor + 1) % rows.size()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		_storage_cursor = (_storage_cursor - 1 + rows.size()) % rows.size()
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		var row: Dictionary = rows[_storage_cursor]
		if row.side == "bag":
			WorldState.store_slot(row.index)
		else:
			if WorldState.retrieve(row.id) == 0:
				show_message("No room.")
		_storage_cursor = mini(_storage_cursor, _storage_rows().size() - 1)
	_refresh_storage()


func _refresh_storage() -> void:
	var rows := _storage_rows()
	var lines: Array[String] = ["STORAGE BOX   (shared by all safe rooms)", "", "-- carried --"]
	for i in rows.size():
		var row: Dictionary = rows[i]
		var cursor := ">" if i == _storage_cursor else " "
		if row.side == "box" and (i == 0 or rows[i - 1].side == "bag"):
			lines.append("")
			lines.append("-- in box --")
		if row.side == "bag":
			var slot: Dictionary = WorldState.inventory()[row.index]
			lines.append("%s [%d] %s" % [cursor, row.index + 1,
				"---" if slot.is_empty() else "%s x%d" % [Items.display_name(slot.id), slot.count]])
		else:
			lines.append("%s %s x%d" % [cursor, Items.display_name(row.id), WorldState.storage()[row.id]])
	lines.append("")
	lines.append("[%s] move   [%s] close" % [_key_name("interact"), _key_name("inventory")])
	_storage_text.text = "\n".join(lines)


# ── 暫停選單 ──────────────────────────────────────────

func _toggle_pause() -> void:
	_pause_panel.visible = not _pause_panel.visible
	get_tree().paused = _pause_panel.visible
	if _pause_panel.visible:
		_resume_button.grab_focus()


func _quit_to_title() -> void:
	get_tree().paused = false
	# 回標題：沒在無線電存過的進度會遺失
	get_tree().change_scene_to_file(TITLE_SCENE)


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


func _build_items_text() -> String:
	var parts: Array[String] = []
	var combat := _player.combat
	var weapon := combat.current_weapon()
	if weapon != "":
		var mag := "%d/%d" % [WorldState.get_loaded(weapon), combat.magazine_size]
		if combat.reloading:
			mag = "reloading"
		parts.append("%s %s (+%d)" % [Items.display_name(weapon), mag,
			WorldState.inv_count(combat.stats().ammo)])
	parts.append("Bottles %d" % _player.bottles)
	if WorldState.access_level > 0:
		parts.append("Card Lv%d" % WorldState.access_level)
	return "  ".join(parts)


# ── 物品欄 ────────────────────────────────────────────

func _toggle_inventory_panel() -> void:
	_inventory_panel.visible = not _inventory_panel.visible
	get_tree().paused = _inventory_panel.visible
	_inventory_cursor = 0
	_refresh_inventory()


func _process_inventory_input() -> void:
	var slots := WorldState.inventory()
	if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("ui_cancel"):
		_toggle_inventory_panel()
		return
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		_inventory_cursor = (_inventory_cursor + 1) % slots.size()
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		_inventory_cursor = (_inventory_cursor - 1 + slots.size()) % slots.size()
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		var slot: Dictionary = slots[_inventory_cursor]
		if not slot.is_empty():
			if _player.use_item(slot.id):
				var verb := "Equipped" if Items.get_item(slot.id).kind == "weapon" else "Used"
				show_message("%s %s." % [verb, Items.display_name(slot.id)])
			else:
				show_message("Can't use that now.")
	_refresh_inventory()


func _refresh_inventory() -> void:
	var lines: Array[String] = ["ITEMS   Condition: %s" % _player.get_condition(), ""]
	var slots := WorldState.inventory()
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var cursor := ">" if i == _inventory_cursor else " "
		if slot.is_empty():
			lines.append("%s [%d] ---" % [cursor, i + 1])
		else:
			lines.append("%s [%d] %s x%d" % [cursor, i + 1, Items.display_name(slot.id), slot.count])
	var selected: Dictionary = slots[_inventory_cursor]
	lines.append("")
	lines.append(Items.get_item(selected.id).desc if not selected.is_empty() else "")
	lines.append("")
	lines.append("[%s] use   [%s] close" % [_key_name("interact"), _key_name("inventory")])
	_inventory_text.text = "\n".join(lines)


func _update_status() -> void:
	_status.visible = _overlay.debug_enabled
	if not _status.visible or level == null:
		return
	var lines := ["%s  %s  HP:%d INF:%d  light:%s  zone:%s%s" % [
		level.title,
		_player.get_gait_name(),
		roundi(_player.health), roundi(_player.infection),
		"ON" if _player.flashlight_on else "OFF",
		level.zone_at(_player.global_position),
		" (cold)" if level.is_cold(_player.global_position) else "",
	]]
	for enemy in enemies:
		lines.append("%s: %s %d%% hp:%d%s" % [
			enemy.display_name, "DEAD" if enemy.is_dead else enemy.get_state_name(),
			roundi(enemy.awareness * 100.0), roundi(enemy.health),
			" cold" if enemy.in_cold else ""])
	_status.text = "\n".join(lines)


## 畫面四周的暗角（躲藏時黑色；感染症狀時偏白）。
func _make_vignette(edge := Color(0, 0, 0, 0.92)) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(edge, 0))
	g.set_color(1, edge)
	g.add_point(0.35, Color(edge, 0))
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
		"%s aim %s fire/knife" % [_key_name("aim"), _key_name("fire")],
		"%s items" % _key_name("inventory"),
		"%s ops" % _key_name("map"),
		"%s debug" % _key_name("debug_toggle"),
	]
	return "  ".join(parts)


func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
