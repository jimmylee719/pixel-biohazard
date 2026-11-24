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
const KOVAC_INTRO := ("KOVAC: \"...is anyone on this channel? This is Dr. Ina Kovac, I left Greycrow two weeks ago. If you're in the clean room, you're safe. Listen carefully.\"")
const ENEMY_SCENES := {
	"patroller": preload("res://scenes/enemy.tscn"),
	"listener": preload("res://scenes/enemy_listener.tscn"),
	"sleeper": preload("res://scenes/enemy_sleeper.tscn"),
	"bear": preload("res://scenes/boss_bear.tscn"),
	"well": preload("res://scenes/boss_well.tscn"),
}
## 主線的最後一個任務：完成後播放結局（Endings）
const FINAL_MISSION := "the_shaft"
const ENDING_DELAY := 1.5
## 恢復電力後，研究站室內有燈（比較亮）
const POWERED_DARKNESS := Color(0.32, 0.32, 0.36)

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
var _signal_cursor := 0
## 選了一次的訊息（再選一次才真的發出）；-1 = 還沒選
var _signal_armed := -1
var _signal_transcript: Array[String] = []
var touch_controls: TouchControls
## 最後看到的結局（測試用）
var last_ending := {}
var _ending_panel: PanelContainer
## 畫面左下角的主角頭像（依狀態換表情）
var _portrait: TextureRect
var _ending_text: Label
## 打開介面的那一幀不處理按鍵（同一下 interact 不要直接選到第一個）
var _signal_opened_frame := -1
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
@onready var _signal_panel: PanelContainer = $HUD/SignalPanel
@onready var _signal_text: Label = $HUD/SignalPanel/Box/Text
@onready var _signal_buttons: Array[Button] = [
	$HUD/SignalPanel/Box/Option0, $HUD/SignalPanel/Box/Option1,
	$HUD/SignalPanel/Box/Option2, $HUD/SignalPanel/Box/Option3]
@onready var _boss_bar: Control = $HUD/BossBar
@onready var _boss_name: Label = $HUD/BossBar/Name
@onready var _boss_fill: ColorRect = $HUD/BossBar/Fill
@onready var _resume_button: Button = $HUD/PausePanel/Box/Resume
@onready var _quit_button: Button = $HUD/PausePanel/Box/QuitToTitle


func _ready() -> void:
	_player.hiding_changed.connect(func(is_hidden: bool): _vignette.visible = is_hidden)
	_overlay.setup(_player)
	_vignette.texture = _make_vignette()
	_infection_vignette.texture = _make_vignette(Color(0.75, 0.95, 1.0, 0.85))
	_player.died.connect(func(): _end_attempt(tr("YOU DIED"), Color(0.9, 0.2, 0.2)))
	_player.hurt.connect(func(_d): _hurt_flash.color.a = 0.45)
	_banner.visible = false
	_hint.text = _build_hint()
	Missions.mission_completed.connect(func(id: String):
		show_message(tr("MISSION COMPLETE: %s") % tr(Missions.get_mission(id).title))
		if level:
			level.sync_from_state()  # 獎勵可能讓隱藏的東西出現
		if id == FINAL_MISSION:
			_show_ending())
	_resume_button.pressed.connect(_toggle_pause)
	_quit_button.pressed.connect(_quit_to_title)
	for i in _signal_buttons.size():
		_signal_buttons[i].pressed.connect(_on_signal_button.bind(i))
	# 發訊介面是全螢幕的重要選擇：不透明背景，避免後面的訊息透出來
	var signal_style := StyleBoxFlat.new()
	signal_style.bg_color = Color(0.02, 0.05, 0.05, 0.97)
	signal_style.border_color = Color(0.3, 0.7, 0.45)
	signal_style.set_border_width_all(1)
	signal_style.set_content_margin_all(6)
	_signal_panel.add_theme_stylebox_override("panel", signal_style)
	_build_ending_panel()
	touch_controls = TouchControls.new()
	add_child(touch_controls)
	_hint.visible = not touch_controls.visible  # 觸控時不顯示鍵盤說明
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_portrait.offset_left = 4
	_portrait.offset_right = 36
	_portrait.offset_top = -62
	_portrait.offset_bottom = -30
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_portrait)
	$HUD.move_child(_portrait, _condition.get_index())
	await load_area(WorldState.data.area, WorldState.data.entry, false)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_overlay.debug_enabled = not _overlay.debug_enabled
	var busy := _resetting or _transitioning or _player.is_dead
	if _ending_panel.visible:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			_quit_to_title()
	elif _pause_panel.visible:
		if Input.is_action_just_pressed("pause"):
			_toggle_pause()
	elif _inventory_panel.visible:
		_process_inventory_input()
	elif _storage_panel.visible:
		_process_storage_input()
	elif _radio_panel.visible:
		_process_radio_input()
	elif _signal_panel.visible:
		_process_signal_input()
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
	if focus and _player.input_enabled:
		_prompt.text = "[%s] %s" % [_key_name("interact"), tr(focus.get_prompt(_player))]
	elif _player.input_enabled and _player.knock_point() != null and _player.velocity.length() < 5.0:
		_prompt.text = tr("[%s] Knock on the wall") % _key_name("interact")
	else:
		_prompt.text = ""
	_items.text = _build_items_text()
	var body := ""
	if level and Climates.has_exposure(level.climate_id()):
		body = tr("  Body: %s") % tr(_player.get_body_temp_state())
	_condition.text = tr("Condition: %s%s%s") % [tr(_player.get_condition()),
		tr("  (infected)") if _player.infection >= WorldState.MAX_INFECTION else "", body]
	_portrait.texture = Art.tex("portraits/shen_" + _player.get_condition().to_lower())
	_portrait.modulate = Color(1, 1, 1, 0.9)
	_condition.add_theme_color_override("font_color", {
		"Fine": Color(0.6, 1, 0.6), "Caution": Color(1, 0.85, 0.3), "Danger": Color(1, 0.35, 0.3)
	}[_player.get_condition()])
	var tracked := Missions.tracked_mission()
	_objective.text = "> %s" % tr(tracked.title) if not tracked.is_empty() else ""
	_update_status()
	_update_boss_bar()


func _update_boss_bar() -> void:
	var boss: Enemy = null
	for e in enemies:
		if e.is_boss() and not e.is_dead:
			boss = e
	_boss_bar.visible = boss != null and level.boss_name() != ""
	if _boss_bar.visible:
		_boss_name.text = tr(level.boss_name()) + tr(boss.boss_suffix())
		_boss_fill.size.x = 200.0 * clampf(boss.health / boss.max_health, 0.0, 1.0)


func _physics_process(_delta: float) -> void:
	if level == null or _transitioning or _resetting or _player.is_hiding or not _player.input_enabled:
		return
	var door := level.door_at(_player.global_position)
	if door == "":
		_locked_door_notice = ""
		return
	if level.door_needs_power(door) and not WorldState.power_on:
		if _locked_door_notice != door:
			_locked_door_notice = door
			show_message(tr("The door is electric. There's no power."), true)
		return
	var need := level.door_access(door)
	if need > WorldState.access_level:
		if _locked_door_notice != door:
			_locked_door_notice = door
			show_message(tr("Locked. Keycard access level %d required.") % need, true)
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
		elif item is Generator:
			item.powered.connect(_on_power_restored)
		elif item is TapePickup:
			item.message_shown.connect(show_message)
		elif item is ReadableNote:
			item.message_shown.connect(show_message)
		elif item is RadioConsole:
			item.used.connect(_on_radio_used)
		elif item is StorageBox:
			item.opened.connect(_toggle_storage_panel)
		elif item is Snowcat:
			item.drive.connect(func(target: String): load_area(target, "snowcat"))
		elif item is ShaftLift:
			item.message_shown.connect(func(text: String): show_message(text, true))
		elif item is Uplink:
			item.opened.connect(_open_signal_panel)
			item.message_shown.connect(func(text: String): show_message(text, true))

	_apply_darkness()
	_player.level = level
	_player.reset_to(level.get_entry_position(entry))
	_camera.setup(_player, level.bounds, level.camera_mode())
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

func _apply_darkness() -> void:
	if level.safe:
		_darkness.color = SAFE_DARKNESS
	elif level.outdoor:
		_darkness.color = OUTDOOR_DARKNESS
	elif level.is_lit():
		_darkness.color = POWERED_DARKNESS
	else:
		_darkness.color = INDOOR_DARKNESS


func _on_terminal_used(item_name: String) -> void:
	show_message(level.get_message(item_name))


## 發電機啟動：燈亮、暖氣恢復（同一區的凍眠體會醒）
func _on_power_restored() -> void:
	level.sync_from_state()
	_apply_darkness()
	show_message(tr("The generator roars to life. Lights flicker on across the station - and the heating with them."), true)


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
	# 回到檢查點時至少有一半的體溫，避免一進戶外就凍死的死循環
	WorldState.body_temp = maxf(WorldState.body_temp, 60.0)
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
	text = tr(text)  # 資料裡的整句文字（文件、無線電、任務）在這裡翻譯
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
		_radio_transcript.append(tr(KOVAC_INTRO))
	for text in Missions.receive_radio():
		_radio_transcript.append(tr(text))
	WorldState.save_checkpoint(level.area_id, "radio")
	_radio_transcript.append(tr("Progress saved.") if WorldState.save_to_disk() else tr("Save failed."))
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
		_radio_transcript.append(tr("Only static.") if Frequencies.signal_strength(_radio_freq) < 0.5 \
			else tr("Something is there, buried in the static... fine-tune it."))
		return {}
	_radio_freq = station.freq
	for line in station.lines:
		_radio_transcript.append(tr(line))
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
		memo_parts.append("%s%s %s" % [mark, Frequencies.format(f), tr(Frequencies.by_freq(f).label)])
	var lines: Array[String] = [
		"RADIO",
		tr("FREQUENCY  %s MHz") % Frequencies.format(_radio_freq),
		tr("SIGNAL     [%s%s]") % ["#".repeat(bars), "-".repeat(10 - bars)],
		tr("MEMO       %s") % ("  /  ".join(memo_parts) if not memo_parts.is_empty() else tr("(none)")),
		"",
	]
	lines.append_array(_radio_transcript)
	lines.append("")
	lines.append(tr("[%s/%s] fine  [%s/%s] coarse  [%s] memo  [%s] listen  [%s] close") % [
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
				show_message(tr("No room."))
		_storage_cursor = mini(_storage_cursor, _storage_rows().size() - 1)
	_refresh_storage()


func _refresh_storage() -> void:
	var rows := _storage_rows()
	var lines: Array[String] = [tr("STORAGE BOX   (shared by all safe rooms)"), "", tr("-- carried --")]
	for i in rows.size():
		var row: Dictionary = rows[i]
		var cursor := ">" if i == _storage_cursor else " "
		if row.side == "box" and (i == 0 or rows[i - 1].side == "bag"):
			lines.append("")
			lines.append(tr("-- in box --"))
		if row.side == "bag":
			var slot: Dictionary = WorldState.inventory()[row.index]
			lines.append("%s [%d] %s" % [cursor, row.index + 1,
				"---" if slot.is_empty() else "%s x%d" % [Items.display_name(slot.id), slot.count]])
		else:
			lines.append("%s %s x%d" % [cursor, Items.display_name(row.id), WorldState.storage()[row.id]])
	lines.append("")
	lines.append(tr("[%s] move   [%s] close") % [_key_name("interact"), _key_name("inventory")])
	_storage_text.text = "\n".join(lines)


# ── 天線塔：發出訊號（結局方向）──────────────────────

func _open_signal_panel() -> void:
	_signal_panel.visible = true
	get_tree().paused = true
	_signal_cursor = 0
	_signal_armed = -1
	_signal_transcript.clear()
	_signal_opened_frame = Engine.get_process_frames()
	_refresh_signal()


## 關掉介面。已經發出訊號的話，這時才算完成任務步驟（回覆都看完了）。
func _close_signal_panel() -> void:
	_signal_panel.visible = false
	get_tree().paused = false
	if WorldState.signal_choice() != "":
		WorldState.emit_event("interact", "uplink")


func _process_signal_input() -> void:
	if Engine.get_process_frames() == _signal_opened_frame:
		return
	var sent := WorldState.signal_choice() != ""
	if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("inventory") \
			or Input.is_action_just_pressed("pause"):
		_close_signal_panel()
		return
	var count := UplinkMessages.DATA.size()
	if sent:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			_close_signal_panel()
		return
	if Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down"):
		_signal_cursor = (_signal_cursor + 1) % count
		_signal_armed = -1
	elif Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up"):
		_signal_cursor = (_signal_cursor - 1 + count) % count
		_signal_armed = -1
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		select_signal(_signal_cursor)
		return
	_refresh_signal()


## 觸控／滑鼠：按鈕。發出之前最後一顆是「離開」；發出之後第一顆是「關閉」。
func _on_signal_button(index: int) -> void:
	if WorldState.signal_choice() != "" or index >= UplinkMessages.DATA.size():
		_close_signal_panel()
	else:
		select_signal(index)


## 選一個訊息：第一次只是選取（提示不能反悔），同一個再選一次才發出。
func select_signal(index: int) -> void:
	if WorldState.signal_choice() != "":
		return
	if _signal_armed == index:
		send_signal(UplinkMessages.DATA[index].id)
		return
	_signal_cursor = index
	_signal_armed = index
	_refresh_signal()


func send_signal(choice_id: String) -> void:
	var option := UplinkMessages.get_option(choice_id)
	if option.is_empty() or WorldState.signal_choice() != "":
		return
	WorldState.set_flag("signal", choice_id)
	_signal_transcript.clear()
	_signal_transcript.append(tr(option.sent))
	_signal_transcript.append(tr(option.reply))
	for line in UplinkMessages.HOLD_REPLY:
		_signal_transcript.append(tr(line))
	# 不明訊號的頻率記進無線電備忘錄
	WorldState.learn_freq(12605)
	_refresh_signal()


func _refresh_signal() -> void:
	var sent := WorldState.signal_choice() != ""
	var lines: Array[String] = []
	for line in UplinkMessages.INTRO:
		lines.append(tr(line))
	lines.append("")
	if sent:
		lines.append_array(_signal_transcript)
		lines.append("")
		lines.append(tr("[%s] close") % _key_name("interact"))
	elif _signal_armed >= 0:
		lines.append(tr("Send this? There is no second transmission. Select it again to transmit."))
	else:
		lines.append(tr("[%s/%s] choose   [%s] select   [%s] step away") % [
			_key_name("move_up"), _key_name("move_down"), _key_name("interact"), _key_name("inventory")])
	_signal_text.text = "\n".join(lines)
	var count := UplinkMessages.DATA.size()
	for i in _signal_buttons.size():
		var button := _signal_buttons[i]
		if sent:
			button.visible = i == 0
			button.text = "Close"
		elif i < count:
			button.visible = true
			var mark := "> " if i == _signal_cursor else "  "
			var armed := tr("  [SELECT AGAIN TO SEND]") if i == _signal_armed else ""
			button.text = mark + tr(UplinkMessages.DATA[i].label) + armed
		else:
			button.visible = true
			button.text = tr("  Step away (decide later)")


# ── 結局 ──────────────────────────────────────────────

func _build_ending_panel() -> void:
	_ending_panel = PanelContainer.new()
	_ending_panel.name = "EndingPanel"
	_ending_panel.visible = false
	_ending_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 1)
	style.set_content_margin_all(28)
	_ending_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_ending_panel.add_child(box)
	_ending_text = Label.new()
	_ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ending_text.add_theme_font_size_override("font_size", 12)
	_ending_text.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	box.add_child(_ending_text)
	var button := Button.new()
	button.text = tr("Return to title")
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_quit_to_title)
	box.add_child(button)
	$HUD.add_child(_ending_panel)


## 主線完成：依天線塔的訊號和現在的感染值決定結局。
func _show_ending() -> void:
	_player.input_enabled = false
	_resetting = true  # 結局畫面期間不會被抓、不會切換區域
	last_ending = Endings.resolve(WorldState.signal_choice(), _player.infection)
	await get_tree().create_timer(ENDING_DELAY).timeout
	var lines: Array[String] = [tr(last_ending.title), ""]
	for line in last_ending.lines:
		lines.append(tr(line))
		lines.append("")
	lines.append(tr("THE END"))
	lines.append("")
	lines.append(tr("[%s] return to title") % _key_name("interact"))
	_ending_text.text = "\n".join(lines)
	_ending_panel.visible = true
	get_tree().paused = true


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
	var lines: Array[String] = [tr("MAIN OPS")]
	for main in [true, false]:
		if not main:
			lines.append("")
			lines.append(tr("SIDE OPS"))
		for m in Missions.list_visible():
			if m.main != main:
				continue
			var done := Missions.is_done(m.id)
			lines.append("%s %s" % ["[x]" if done else "[ ]", tr(m.title)])
			if not done:
				lines.append("    " + tr(m.desc))
	lines.append("")
	lines.append(tr("[%s] close") % _key_name("map"))
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
	var throwable := _player.current_throwable()
	if throwable != "":
		parts.append(tr("Throw: %s x%d") % [Items.display_name(throwable), WorldState.inv_count(throwable)])
	parts.append(tr("Light: %s") % tr(_player.light_name()))
	if WorldState.access_level > 0:
		parts.append(tr("Card Lv%d") % WorldState.access_level)
	if WorldState.carrying == "fuel":
		parts.append(tr("CARRYING FUEL"))
	elif WorldState.carrying == "extinguisher":
		parts.append(tr("EXTINGUISHER %d  [%s] spray  [%s] throw") % [
			WorldState.extinguisher_charge, _key_name("fire"), _key_name("throw")])
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
			var kind: String = Items.get_item(slot.id).kind
			var made: String = Items.get_item(slot.id).get("recipe", {}).get("makes", "")
			if _player.use_item(slot.id):
				match kind:
					"weapon":
						show_message(tr("Equipped %s.") % Items.display_name(slot.id))
					"throwable":
						show_message(tr("%s ready to throw.") % Items.display_name(slot.id))
					"warm":
						show_message(tr("The heat pack spreads warmth through your chest."))
					"craft":
						show_message(tr("Made a %s. (Your lighter is always on you.)") % Items.display_name(made))
					_:
						show_message(tr("Used %s.") % Items.display_name(slot.id))
			else:
				show_message(tr("Can't use that now."))
	_refresh_inventory()


func _refresh_inventory() -> void:
	var lines: Array[String] = [tr("ITEMS   Condition: %s") % tr(_player.get_condition()), ""]
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
	lines.append(tr(Items.get_item(selected.id).desc) if not selected.is_empty() else "")
	lines.append("")
	lines.append(tr("[%s] use   [%s] close") % [_key_name("interact"), _key_name("inventory")])
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
	var move := "".join(["move_up", "move_left", "move_down", "move_right"].map(_key_name))
	var parts := [
		"%s %s" % [move, tr("Move")],
		"%s %s" % [_key_name("run"), tr("Run")],
		"%s %s" % [_key_name("sneak"), tr("Sneak")],
		"%s %s" % [_key_name("flashlight"), tr("Light")],
		"%s %s" % [_key_name("throw"), tr("Throw")],
		"%s %s" % [_key_name("interact"), tr("Use")],
		"%s %s" % [_key_name("aim"), tr("Aim")],
		"%s %s" % [_key_name("fire"), tr("Fire")],
		"%s %s" % [_key_name("inventory"), tr("Items")],
		"%s %s" % [_key_name("map"), tr("Ops")],
	]
	return " ".join(parts)


func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
