## 遊戲主場景（世界管理）：載入區域、門的切換、檢查點、任務 HUD、除錯顯示。
## 區域本身由 Level 依 Areas 的資料建立；跨區域的狀態都存在 WorldState。
extends Node2D

const RESET_DELAY := 1.5
const FADE_TIME := 0.2
const MESSAGE_TIME := 6.0
## 室內很暗但看得出房間的樣子（v0.10：整張地圖都看得到）；戶外有雪地反光，稍微亮一點
const INDOOR_DARKNESS := Color(0.25, 0.26, 0.31)
const OUTDOOR_DARKNESS := Color(0.2, 0.22, 0.3)
## 安全屋：溫暖、比較亮，讓玩家感到安心（出門那一刻的落差也是恐怖的一部分）
const SAFE_DARKNESS := Color(0.34, 0.28, 0.22)
const TITLE_SCENE := "res://scenes/title.tscn"
const KOVAC_INTRO := ("KOVAC: \"Shen. I left Greycrow on the last flight out, two weeks ago - day three. I'm the one who named this thing. Find the director's records upstairs. I need to know what he did after I left.\"")
const SURVIVAL_MENU_SCENE := "res://scenes/survival_menu.tscn"
const ENEMY_SCENES := {
	"patroller": preload("res://scenes/enemy.tscn"),
	"listener": preload("res://scenes/enemy_listener.tscn"),
	"sleeper": preload("res://scenes/enemy_sleeper.tscn"),
	"guard": preload("res://scenes/enemy_guard.tscn"),
	"hound": preload("res://scenes/enemy_hound.tscn"),
	"crawler": preload("res://scenes/enemy_crawler.tscn"),
	"husk": preload("res://scenes/enemy_husk.tscn"),
	"chorister": preload("res://scenes/enemy_chorister.tscn"),
	"runner": preload("res://scenes/enemy_runner.tscn"),
	"spitter": preload("res://scenes/enemy_spitter.tscn"),
	"brute": preload("res://scenes/enemy_brute.tscn"),
	"bear": preload("res://scenes/boss_bear.tscn"),
	"well": preload("res://scenes/boss_well.tscn"),
	"warden": preload("res://scenes/boss_warden.tscn"),
}
## 主線的最後一個任務：完成後播放結局（Endings）
const FINAL_MISSION := "the_shaft"
const ENDING_DELAY := 1.5
## 恢復電力後，研究站室內有燈（比較亮）
const POWERED_DARKNESS := Color(0.45, 0.44, 0.46)

var level: Level
var enemies: Array[Enemy] = []

var _resetting := false
var _transitioning := false
var _message_timer := 0.0
## 收過的訊息（新的在前），手機「訊息」App 看得到全文
## 圖鑑 App 選到哪一筆
var codex_cursor := 0
## 裝備 App 的游標、地圖 App 正在看哪一張地圖（主地圖 id）
var gear_cursor := 0
var map_view := ""
var _explore_timer := 0.0
var _spore_warned := false
## 畫面後製的材質（era：0 現在、1 = 1962、2 = 2099）
var _film_mat: ShaderMaterial
var options_panel: OptionsPanel
## 畫面邊緣的聲音提示（畫面外的腳步聲）
var sound_cues: SoundCues
var tactical_hud: TacticalHud
var radio_dial: RadioDial
## 過場（用遊戲畫面演出）
var cutscene: CutscenePlayer
## 快捷選單（道具鍵、武器鍵：按一下用／換，按住＋方向選）
var quick_menu: QuickMenu
var backpack: BackpackPanel
var map_panel: MapPanel
var mission_list: MissionList
var objective_arrows: ObjectiveArrows
var sonar_radar: SonarRadar
var snow_fall: SnowFall
## 野戰無線電：等著接的來電 [{key, steps}]（FieldRadio）
var radio_queue: Array[Dictionary] = []
var _radio_check := 0.0
var _weather_dark_timer := 0.0
var _arrow_timer := 0.0
var _qm_key := ""
var _qm_pressed_ms := 0
## 生存模式（WorldState.mode == "survival" 時才有）
var survival: SurvivalMode
var survival_results: SurvivalResults
var message_log: Array[String] = []
var _message_more: Label
var _hurt_timer := 0.0
var _last_objective := ""
var phone: Phone
var _message_cursor := 0
## 超過這個長度的訊息，通知只顯示開頭（提示到手機看全文）
const MESSAGE_SHORT := 34
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
	_player.hiding_changed.connect(_on_hiding_changed)
	_overlay.setup(_player)
	_vignette.texture = _make_vignette()
	_infection_vignette.texture = _make_vignette(Color(0.75, 0.95, 1.0, 0.85))
	_player.died.connect(func():
		if survival:
			_on_survival_died()
		else:
			_end_attempt(tr("YOU DIED"), Color(0.9, 0.2, 0.2)))
	_player.hurt.connect(func(_d):
		_hurt_flash.color.a = 0.45
		_hurt_timer = 4.0)
	_banner.visible = false
	_hint.text = _build_hint()
	WorldState.codex_unlocked.connect(func(id: String):
		if Codex.ENTRIES.has(id) and WorldState.mode == "story":
			show_message(tr("New field file: %s") % tr(Codex.ENTRIES[id].name)))
	Missions.mission_completed.connect(func(id: String):
		if WorldState.mode != "story":
			return
		Sfx.play("mission_complete")
		show_message(tr("MISSION COMPLETE: %s") % tr(Missions.get_mission(id).title))
		for call in RadioCalls.DATA:
			if call.after == id and not WorldState.has_flag("call:" + id):
				queue_radio("call:" + id, _radio_call_steps(call.lines))
		if level:
			level.sync_from_state()  # 獎勵可能讓隱藏的東西出現
		if id == FINAL_MISSION:
			_show_ending())
	_resume_button.pressed.connect(_toggle_pause)
	_quit_button.pressed.connect(_quit_to_title)
	# 選項（音量、觸控、聲音提示、輔助模式、省電）：暫停選單裡的按鈕
	var opt_button := Button.new()
	opt_button.name = "Options"
	opt_button.text = tr("Options")
	opt_button.add_theme_font_size_override("font_size", 12)
	_quit_button.get_parent().add_child(opt_button)
	_quit_button.get_parent().move_child(opt_button, _quit_button.get_index())
	options_panel = OptionsPanel.new()
	options_panel.name = "OptionsPanel"
	$HUD.add_child(options_panel)
	opt_button.pressed.connect(func():
		_pause_panel.visible = false
		options_panel.open())
	options_panel.closed.connect(func():
		_pause_panel.visible = true
		opt_button.grab_focus())
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
	# 無線電面板：上面是刻度盤＋強度表＋示波器（RadioDial），下面是原本的文字
	var radio_box := VBoxContainer.new()
	_radio_panel.add_child(radio_box)
	radio_dial = RadioDial.new()
	radio_box.add_child(radio_dial)
	_radio_text.reparent(radio_box)
	# 畫面後製（顆粒、暗角、色調）：蓋在遊戲畫面上、HUD 底下
	var film_layer := CanvasLayer.new()
	film_layer.layer = 9
	film_layer.name = "Film"
	add_child(film_layer)
	var film := ColorRect.new()
	film.set_anchors_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/film.gdshader")
	film.material = mat
	_film_mat = mat
	film_layer.add_child(film)
	# 警戒狀態（ALERT／EVASION／CAUTION）在畫面上方正中間
	_alert_label = Label.new()
	_alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert_label.offset_left = -80
	_alert_label.offset_right = 80
	_alert_label.offset_top = 40
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 12)
	_alert_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_alert_label.add_theme_constant_override("outline_size", 3)
	$HUD.add_child(_alert_label)
	sound_cues = SoundCues.new()
	sound_cues.name = "SoundCues"
	sound_cues.main = self
	$HUD.add_child(sound_cues)
	$HUD.move_child(sound_cues, 0)
	touch_controls = TouchControls.new()
	add_child(touch_controls)
	# 戰術 HUD：LIFE、道具框、武器框（觸控版移到上面）
	tactical_hud = TacticalHud.new()
	tactical_hud.name = "TacticalHud"
	tactical_hud.main = self
	tactical_hud.touch = TouchControls.should_show()
	$HUD.add_child(tactical_hud)
	$HUD.move_child(tactical_hud, 1)
	# 聲納雷達（右上）、下雪的畫面（v0.11）
	sonar_radar = SonarRadar.new()
	sonar_radar.name = "SonarRadar"
	sonar_radar.main = self
	sonar_radar.touch = tactical_hud.touch
	$HUD.add_child(sonar_radar)
	$HUD.move_child(sonar_radar, 2)
	snow_fall = SnowFall.new()
	snow_fall.name = "SnowFall"
	snow_fall.main = self
	$HUD.add_child(snow_fall)
	$HUD.move_child(snow_fall, 0)
	_hint.visible = false  # 操作說明在手機「操作」App
	_build_phone()
	quick_menu = QuickMenu.new()
	quick_menu.name = "QuickMenu"
	$HUD.add_child(quick_menu)
	# 任務指引的小箭頭（畫在主角腳邊）
	objective_arrows = ObjectiveArrows.new()
	objective_arrows.name = "ObjectiveArrows"
	objective_arrows.main = self
	$HUD.add_child(objective_arrows)
	$HUD.move_child(objective_arrows, 1)
	# 格子背包（物品鍵、儲物箱）和全螢幕地圖（地圖鍵）
	backpack = BackpackPanel.new()
	backpack.name = "Backpack"
	backpack.main = self
	$HUD.add_child(backpack)
	backpack.use_slot.connect(use_inventory_slot)
	backpack.use_kit.connect(_use_kit)
	backpack.closed.connect(func():
		get_tree().paused = false
		Sfx.play("ui_cancel"))
	map_panel = MapPanel.new()
	map_panel.name = "MapPanel"
	map_panel.main = self
	$HUD.add_child(map_panel)
	map_panel.closed.connect(func():
		get_tree().paused = false
		Sfx.play("ui_cancel"))
	map_panel.change_area.connect(_flip_map)
	cutscene = CutscenePlayer.new()
	cutscene.name = "Cutscene"
	$HUD.add_child(cutscene)
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
	if WorldState.mode == "survival":
		_start_survival()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("debug_toggle"):
		_overlay.debug_enabled = not _overlay.debug_enabled
	if cutscene and cutscene.active:
		return
	var busy := _resetting or _transitioning or _player.is_dead
	if _ending_panel.visible:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			_quit_to_title()
	elif options_panel and options_panel.visible:
		pass  # 選項畫面自己處理按鍵（返回 = 回到暫停選單）
	elif _pause_panel.visible:
		if Input.is_action_just_pressed("pause"):
			_toggle_pause()
	elif backpack.visible or map_panel.visible:
		pass  # 背包、地圖自己處理按鍵
	elif phone.visible:
		_process_phone_input()
	elif _radio_panel.visible:
		_process_radio_input()
	elif _signal_panel.visible:
		_process_signal_input()
	elif _mission_panel.visible:
		if Input.is_action_just_pressed("map") or Input.is_action_just_pressed("pause"):
			_toggle_mission_panel()
	elif not busy:
		_process_quick_menu()
		if quick_menu.visible:
			pass
		elif Input.is_action_just_pressed("pause"):
			_toggle_pause()
		elif Input.is_action_just_pressed("map"):
			open_map()
		elif Input.is_action_just_pressed("inventory"):
			_toggle_inventory_panel()
		elif Input.is_action_just_pressed("phone"):
			_toggle_mission_panel()
		elif Input.is_action_just_pressed("call"):
			answer_radio()
	if not busy and WorldState.mode == "story" and level and not get_tree().paused:
		_update_field_radio(delta)
		_update_weather(delta)
		_update_world_events(delta)
		if level.tracks:
			level.tracks.step(_player)

	_hurt_flash.color.a = move_toward(_hurt_flash.color.a, 0.0, delta * 1.5)
	# 感染值越高，畫面四周越白（症狀）
	var infection_k := clampf((_player.infection - 30.0) / 70.0, 0.0, 1.0)
	_infection_vignette.modulate.a = infection_k * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.004))

	_message_timer -= delta
	if _message_timer <= 0.0:
		if _message_queue.is_empty():
			_message.visible = false
			_message_more.visible = false
		else:
			_show_next_message()

	var focus := _player.focus
	var prey := _player.combat.takedown_target() if _player.input_enabled else null
	if prey:
		# 潛行到敵人背後：一擊解決（刀）或抓住（互動）
		_prompt.text = tr("[%s] Silent takedown   [%s] Grab") % [_key_name("fire"), _key_name("interact")]
	elif focus and _player.input_enabled:
		_prompt.text = "[%s] %s" % [_key_name("interact"), tr(focus.get_prompt(_player))]
	elif _player.input_enabled and _player.peeking != null:
		_prompt.text = tr("[%s] Let the door close") % _key_name("interact")
	elif _player.input_enabled and _player.peek_candidate() != null:
		_prompt.text = tr("[%s] Ease the door open and look") % _key_name("interact")
	else:
		_prompt.text = ""
	_items.text = _build_items_text()
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
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
	# 狀態（頭像＋文字）平常不顯示：受傷、狀況不好、快凍僵時才出現。完整資訊在手機「狀態」
	var body_state := _player.get_body_temp_state()
	var show_condition := _hurt_timer > 0.0 or _player.get_condition() != "Fine" \
		or _player.infection >= WorldState.MAX_INFECTION \
		or (body != "" and (body_state == "Freezing" or body_state == "Hypothermic"))
	_condition.visible = show_condition and not phone.visible
	_portrait.visible = _condition.visible
	# 目標：畫面上不顯示，換新目標時跳一則通知
	var tracked := Missions.tracked_mission()
	_objective.text = "> %s" % tr(tracked.title) if not tracked.is_empty() else ""
	_objective.visible = false
	var tracked_id: String = tracked.get("id", "")
	if tracked_id != _last_objective:
		if _last_objective != "" and tracked_id != "" and WorldState.mode == "story":
			show_message(tr("New objective: %s") % tr(tracked.title))
		_last_objective = tracked_id
	_update_status()
	_update_arrows(delta)
	_update_boss_bar()
	_update_music(delta)
	_update_alert_hud()
	_update_region()
	if not _resetting and not _transitioning:
		_mark_explored(delta)
		if _player.in_spores and not _spore_warned and Gear.stat("hazard") > 0.0:
			_spore_warned = true
			show_message(tr("Spores hang in the air here. Without a sealed suit, you're breathing them in."), true)
		elif not _player.in_spores:
			_spore_warned = false
	# 第一人稱時不顯示鍵盤說明和互動提示（畫面要乾淨）
	_hint.visible = false  # 操作說明在手機「操作」App
	if phone.visible:
		_refresh_phone()


# ── 音樂 ──────────────────────────────────────────────

## 有敵人追著你（ALERT）就換成追逐音樂；甩掉之後過一陣子才換回探索音樂（避免一直切換）
const CHASE_HOLD := 6.0
var _chase_timer := 0.0
var _region := ""
var _reinforced := false
var _alert_label: Label
var _any_alert := false
var _any_suspicious := false


# ── 躲櫃子（維持俯視：四周變暗，只看得到櫃子縫外面一小塊）──

func _on_hiding_changed(is_hidden: bool) -> void:
	_vignette.visible = is_hidden


func _on_radio_called(_caller: Node, target: Vector2) -> void:
	show_message(tr("Enemy radio: \"Contact! All units, converge!\""), true)
	var r := level.reinforcements()
	if r.is_empty() or _reinforced:
		return
	_reinforced = true
	var doors: Array = r.get("doors", [])
	for i in r.get("count", 0):
		var door: String = doors[i % doors.size()]
		var enemy := spawn_enemy(r.get("type", "guard"), level.get_entry_position(door))
		enemy.answer_call(target)


## 臨時加入的敵人（增援）：不記錄生死與位置
func spawn_enemy(type: String, pos: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY_SCENES[type].instantiate()
	_enemy_root.add_child(enemy)
	var pts: Array[Vector2] = [pos]
	enemy.setup(pts, _player, level)
	enemies.append(enemy)
	_overlay.bind_area(level, enemies)
	return enemy


func _update_alert_hud() -> void:
	var net := level.alert if level else null
	if net == null or net.phase == AlertNetwork.Phase.NONE or (sonar_radar and sonar_radar.visible):
		_alert_label.text = ""
		return
	var text := tr(net.phase_name())
	if net.phase != AlertNetwork.Phase.ALERT:
		text += "  %02d" % ceili(net.timer)
	_alert_label.text = text
	_alert_label.add_theme_color_override("font_color", {
		AlertNetwork.Phase.ALERT: Color(1, 0.25, 0.2),
		AlertNetwork.Phase.EVASION: Color(1, 0.7, 0.2),
		AlertNetwork.Phase.CAUTION: Color(1, 0.95, 0.4),
	}[net.phase])


func _update_music(delta: float) -> void:
	if level == null or _ending_panel.visible:
		return
	var alert := false
	var suspicious := false
	for enemy in enemies:
		if enemy.is_dead or enemy.is_boss():
			continue
		if enemy.state == Enemy.State.ALERT:
			alert = true
		elif enemy.state == Enemy.State.SUSPICIOUS:
			suspicious = true
	if alert and not _any_alert:
		Sfx.play("alert_sting")
		Sfx.rumble(80, 0.5)
	elif suspicious and not _any_suspicious and not alert:
		Sfx.play("suspicious_sting")
	_any_alert = alert
	_any_suspicious = suspicious
	var phase := level.alert.phase
	if alert or phase == AlertNetwork.Phase.ALERT or phase == AlertNetwork.Phase.EVASION:
		_chase_timer = CHASE_HOLD
	else:
		_chase_timer = maxf(_chase_timer - delta, 0.0)
	var base := level.music_id(_player.global_position)
	if _chase_timer > 0.0 and not level.is_safe_at(_player.global_position) and level.boss_name() == "":
		Sfx.play_music("chase", 0.4)
	else:
		Sfx.play_music(base, 2.0)
	Sfx.play_ambience(level.ambience_id(WorldState.power_on, _player.global_position))


func _update_boss_bar() -> void:
	var boss: Enemy = null
	for e in enemies:
		if e.is_boss() and not e.is_dead:
			boss = e
	_boss_bar.visible = boss != null and level.boss_name() != ""
	if _boss_bar.visible:
		_boss_name.text = tr(level.boss_name()) + tr(boss.boss_suffix())
		_boss_fill.size.x = 200.0 * clampf(boss.health / boss.max_health, 0.0, 1.0)


## ── 鏡頭：一律是一開始那種斜上方俯視（不傾斜、不切固定機位）。只有遠近會變：
##    走進小房間自動推近一點（房間越小推越近），回到走廊、大廳、戶外就拉回來；貼牆時往前方多看一點。
## 幾格以下的房間算小房間 → 推近多少
const ROOM_ZOOM := [[40, 1.3], [80, 1.2], [140, 1.1]]


func _update_camera_view(_delta: float) -> void:
	if level == null or _camera.fixed:
		return
	var zone: Dictionary = level.camera_zone_at(_player.global_position)
	var zoom := float(zone.get("zoom", room_zoom()))
	if _player.wall_press != Vector2.ZERO and not _player.is_hiding:
		# 貼牆：鏡頭往主角前面推出去一點（看得到走廊前面）
		_camera.wall_offset = _player.wall_press * 56.0
	else:
		_camera.wall_offset = Vector2.ZERO
	_camera.zoom_target = zoom


## 主角所在的房間有多大 → 鏡頭要推多近（戶外、大房間 = 1）
func room_zoom() -> float:
	if level == null or level.fog == null:
		return 1.0
	var cell := level.cell_of(_player.global_position)
	if not level._is_indoor_cell(cell) or not level.room_of.has(cell):
		return 1.0
	var n: int = level.fog.room_size(level.room_of[cell])
	for step in ROOM_ZOOM:
		if n <= step[0]:
			return step[1]
	return 1.0


## 舊的斜角視角已經取消：後製的 tilt 固定是 0
var _tilt := 0.0


func _set_tilt(v: float) -> void:
	_tilt = v
	if _film_mat:
		_film_mat.set_shader_parameter("tilt", v)


func _physics_process(delta: float) -> void:
	if level != null and not (cutscene and cutscene.active):
		_update_camera_view(delta)
	if level == null or _transitioning or _resetting or _player.is_hiding or not _player.input_enabled:
		return
	if survival:
		return  # 生存模式：門出不去
	var door := level.door_at(_player.global_position)
	if door == "":
		_locked_door_notice = ""
		return
	if level.door_needs_power(door) and not WorldState.power_on:
		if _locked_door_notice != door:
			_locked_door_notice = door
			show_message(tr("The door is electric. There's no power."), true)
			Sfx.play("door_locked")
		return
	var need := level.door_access(door)
	if need > WorldState.access_level:
		if _locked_door_notice != door:
			_locked_door_notice = door
			show_message(tr("Locked. Keycard access level %d required.") % need, true)
			Sfx.play("door_locked")
		return
	Sfx.play("door_open")
	load_area(level.door_target(door), door)


# ── 區域 ──────────────────────────────────────────────

## 載入一個區域，主角站在 entry（門的 id 或 "start"）的位置。
func load_area(area_id: String, entry: String, fade := true) -> void:
	supply_drops.clear()  # 空投是這張地圖臨時的東西
	_transitioning = true
	_player.input_enabled = false
	if fade:
		await _fade_to(1.0)

	if level:
		# 馬上從場景移除（不然舊地圖的牆在這一幀還在，會把主角推開）
		remove_child(level)
		level.queue_free()
	for enemy in enemies:
		if not enemy.is_dead and not enemy.is_boss() and not _resetting:
			WorldState.store_enemy(enemy.enemy_key, enemy.snapshot())
		enemy.queue_free()
	enemies.clear()

	# 合併進主地圖的房間（Areas.rooms()）：載入主地圖，站在房間裡的入口
	var root := Areas.root_of(area_id)
	level = Level.new()
	level.area_id = root
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	move_child(level, _darkness.get_index() + 1)

	for i in (level.enemy_defs.size() if WorldState.mode == "story" else 0):
		var def: Dictionary = level.enemy_defs[i]
		var enemy: Enemy = ENEMY_SCENES[def.type].instantiate()
		enemy.enemy_key = def.get("key", "%s:%d" % [root, i])
		_enemy_root.add_child(enemy)
		enemy.setup(def.points, _player, level)
		enemies.append(enemy)
		enemy.held_up_changed.connect(func(on: bool):
			if on:
				show_message(tr("\"Don't shoot!\" He freezes with his hands up. Keep aiming and he'll empty his pockets.")))
		if enemy.is_boss():
			enemy.boss_event.connect(_on_boss_event)

	for item in level.get_interactables():
		if item is ExitPoint:
			item.reached.connect(func(target: String): load_area(target, "stairs"))
		elif item is Terminal:
			item.used.connect(_on_terminal_used)
		elif item is Generator:
			item.powered.connect(_on_power_restored)
		elif item is TapePickup:
			item.message_shown.connect(show_message)
		elif item is GearPickup or item is AreaMapPickup or item is SafeBox or item is ExtraPickup:
			item.message_shown.connect(func(text: String): show_message(text, true))
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
		elif item is MemoryReel:
			item.play_reel.connect(_on_play_reel)
			item.message_shown.connect(func(text: String): show_message(text, true))
		elif item is Uplink:
			item.opened.connect(_open_signal_panel)
			item.message_shown.connect(func(text: String): show_message(text, true))

	level.alert.radio_called.connect(_on_radio_called)
	for door in level.get_inner_doors():
		door.denied.connect(func():
			show_message(tr("Locked. Keycard access level %d required.") % door.access, true)
			Sfx.play("door_locked"))
	_chase_timer = 0.0
	_boss_dark = false
	if _boss_banner:
		_boss_banner.modulate.a = 0.0
	_reinforced = false
	_any_alert = false
	_any_suspicious = false
	_player.level = level
	set_era(Areas.get_area(root).get("era", ""))
	_player.reset_to(level.get_entry_position(entry_key(area_id, entry)))
	_region = current_area_id()
	if level.fog:
		level.fog.peek_cells = _player.peek_cells()
		level.fog.update(_player.global_position)
	_apply_darkness()
	_camera.setup(_player, level.bounds, level.camera_mode())
	_overlay.bind_area(level, enemies)

	# 先觸發「進入區域」的任務事件，再存檔查點，任務進度才會包含在檢查點裡
	WorldState.emit_event("enter_area", area_id)
	WorldState.save_checkpoint(area_id, entry)

	if fade:
		await _fade_to(0.0)
	_player.input_enabled = true
	_transitioning = false
	await _check_cutscene(area_id)
	if _region != area_id:
		await _check_cutscene(_region)


# ── 地圖（惡靈古堡式）、探索紀錄、主線方向 ───────────────────

## 主角周圍的格子記成「去過」（看不到的房間不算）。地圖 App 用來分「去過／還沒去過」。
func _mark_explored(delta: float) -> void:
	_explore_timer -= delta
	if _explore_timer > 0.0 or level == null:
		return
	_explore_timer = 0.25
	var root := level.area_id
	var w := int(level.bounds.size.x / Level.TILE)
	var h := int(level.bounds.size.y / Level.TILE)
	var arr: PackedByteArray = WorldState.data.explored.get(root, PackedByteArray())
	if arr.size() != w * h:
		arr = PackedByteArray()
		arr.resize(w * h)
	var c := level.cell_of(_player.global_position)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var cc := c + Vector2i(dx, dy)
			if cc.x < 0 or cc.y < 0 or cc.x >= w or cc.y >= h or dx * dx + dy * dy > 30:
				continue
			if level.fog and level.fog.is_hidden_cell(cc):
				continue
			arr[cc.y * w + cc.x] = 1
	WorldState.data.explored[root] = arr


## 地圖 App 可以翻的地圖：去過的、或撿到地圖的主區域
func known_map_areas() -> Array[String]:
	var out: Array[String] = []
	for id in Areas.all():
		if Areas.root_of(id) != id:
			continue
		if WorldState.has_flag("map:" + id) or WorldState.data.explored.has(id):
			out.append(id)
	return out


## 主線的下一個目的地：{area: 主地圖 id, cell: 格子或 null}
const BOSS_TYPES := {"tundra_mother": "bear", "deep_well": "well"}


func objective_target() -> Dictionary:
	return mission_target(Missions.tracked_mission())


## 這個任務現在這一步要去哪：{area: 主地圖 id, cell: 格子或 null}；不知道 = {}
func mission_target(m: Dictionary) -> Dictionary:
	if m.is_empty():
		return {}
	var i := Missions.step_index(m.id)
	if i >= m.steps.size():
		return {}
	var step: Dictionary = m.steps[i]
	match step.type:
		"enter_area":
			var root := Areas.root_of(step.target)
			if Areas.rooms().has(step.target):
				var rows: Array = Areas.all()[step.target].map
				return {"area": root, "cell": Areas.room_offset(step.target) + Vector2i(String(rows[0]).length() / 2, rows.size() / 2)}
			return {"area": root, "cell": null}
		"interact", "collect":
			for id in Areas.all():
				if Areas.root_of(id) != id:
					continue
				var names: Dictionary = Areas.get_area(id).names
				for key in names:
					if names[key] == step.target:
						var xy := String(key).split(",")
						return {"area": id, "cell": Vector2i(int(xy[0]), int(xy[1]))}
		"defeat":
			for id in Areas.all():
				for e in Areas.all()[id].get("enemies", []):
					if e.type == BOSS_TYPES.get(step.target, step.target):
						return {"area": Areas.root_of(id), "cell": null}
	return {}


## 這張地圖通往其他地圖的出入口：門、樓梯、雪地車 → [{to: 主地圖 id, cell}]
func area_links(area_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var d := Areas.get_area(area_id)
	for door in d.doors.values():
		out.append({"to": Areas.root_of(door.to), "cell": door.cell})
	for key in d.get("stairs", {}):
		var xy := String(key).split(",")
		out.append({"to": Areas.root_of(d.stairs[key]), "cell": Vector2i(int(xy[0]), int(xy[1]))})
	if d.get("snowcat_to", "") != "":
		var rows: Array = d.map
		for y in rows.size():
			var x := String(rows[y]).find("Z")
			if x >= 0:
				out.append({"to": Areas.root_of(d.snowcat_to), "cell": Vector2i(x, y)})
	return out


## 從 from 往 target 走的第一個出入口（門、樓梯、雪地車；地圖上標出來、箭頭指過去）
func objective_doors(from: String, target: String) -> Array[Vector2i]:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var a: String = queue.pop_front()
		if a == target:
			break
		for link in area_links(a):
			if not prev.has(link.to):
				prev[link.to] = a
				queue.append(link.to)
	var cells: Array[Vector2i] = []
	if not prev.has(target) or from == target:
		return cells
	var hop := target
	while prev[hop] != from and prev[hop] != "":
		hop = prev[hop]
	for link in area_links(from):
		if link.to == hop:
			cells.append(link.cell)
	return cells


## 勾了指引的任務在 view 這張地圖上要標在哪：[{color, title, cell, doors}]
func map_pins(view: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in Missions.pinned():
		var t := mission_target(p.mission)
		if t.is_empty():
			continue
		var pin := {"color": p.color, "title": tr(p.mission.title), "cell": null, "doors": [] as Array[Vector2i]}
		if t.area == view:
			pin.cell = t.get("cell")
		else:
			pin.doors = objective_doors(view, t.area)
		out.append(pin)
	return out


## 每 0.25 秒更新任務箭頭：目標（或往那邊的門）在哪、沿著走得到的路該往哪個方向
func _update_arrows(delta: float) -> void:
	# v0.11：任務只標在地圖上（M），畫面上不畫箭頭（使用者覺得一直顯示影響體驗）
	objective_arrows.visible = false
	return
	_arrow_timer -= delta
	if _arrow_timer > 0.0 or level == null:
		return
	_arrow_timer = 0.25
	var list: Array[Dictionary] = []
	var from := _player.global_position
	for pin in map_pins(level.area_id):
		var goals: Array[Vector2] = []
		if pin.cell != null:
			goals.append((Vector2(pin.cell) + Vector2(0.5, 0.5)) * Level.TILE)
		for c: Vector2i in pin.doors:
			goals.append((Vector2(c) + Vector2(0.5, 0.5)) * Level.TILE)
		if goals.is_empty():
			# 目標就在這張地圖、沒有確切位置：Boss 的話指向牠
			for e in enemies:
				if is_instance_valid(e) and e.is_boss() and not e.is_dead:
					goals.append(e.global_position)
		var best := INF
		var best_goal := Vector2.ZERO
		var best_dir := Vector2.ZERO
		for g in goals:
			var path := NavigationServer2D.map_get_path(level.get_navigation_map(), from, g, true)
			var length := 0.0
			var dir := (g - from).normalized()
			if path.size() >= 2:
				var found := false
				for i in range(1, path.size()):
					length += path[i - 1].distance_to(path[i])
					if not found and path[i].distance_to(from) > 20.0:
						dir = (path[i] - from).normalized()
						found = true
			else:
				length = from.distance_to(g) * 2.0
			if length < best:
				best = length
				best_goal = g
				best_dir = dir
		if best < INF:
			list.append({"color": pin.color, "pos": best_goal, "dir": best_dir})
	objective_arrows.targets = list


func open_map() -> void:
	Sfx.play("ui_confirm")
	map_view = level.area_id
	get_tree().paused = true
	map_panel.map = map_data(map_view)
	map_panel.open()


func _flip_map(step: int) -> void:
	var areas := known_map_areas()
	if WorldState.mode == "story":
		areas.push_front("island")
	if areas.size() < 2:
		return
	map_view = areas[(areas.find(map_view) + step + areas.size()) % areas.size()]
	Sfx.play("ui_move")
	map_panel.map = map_data(map_view)
	map_panel.fit()
	map_panel.focus_player()


func _refresh_map() -> void:
	var areas := known_map_areas()
	if map_view == "" or not areas.has(map_view):
		map_view = level.area_id
	phone.map = map_data(map_view)
	phone.queue_redraw()


## 地圖畫面要的資料（手機的小地圖和全螢幕地圖共用）
func map_data(view: String) -> Dictionary:
	if view == "island":
		return island_data()
	var areas := known_map_areas()
	var d := Areas.get_area(view)
	var here := view == level.area_id
	var stars: Array[Vector2i] = []
	for key in d.get("hidden", {}):
		var flag: String = d.hidden[key]
		var item_id: String = d.get("item_keys", {}).get(key, "%s:%s" % [view, key])
		if WorldState.has_flag(flag) and not WorldState.is_taken(item_id):
			var xy := String(key).split(",")
			stars.append(Vector2i(int(xy[0]), int(xy[1])))
	var safe_cells := {}
	if here:
		for y in level._map.size():
			for x in String(level._map[y]).length():
				if level.is_safe_cell(Vector2i(x, y)):
					safe_cells[Vector2i(x, y)] = true
	var t := objective_target()
	var known := WorldState.has_flag("map:" + view)
	var idx := areas.find(view)
	var main_pin := WorldState.pin_main()
	return {
		"rows": d.map, "explored": WorldState.data.explored.get(view, PackedByteArray()), "known": known,
		"player": _player.global_position if here else null, "facing": _player.facing,
		"objective": t.get("cell") if main_pin and t.get("area", "") == view else null,
		"objective_doors": objective_doors(view, t.area) if main_pin and not t.is_empty() and t.area != view else ([] as Array[Vector2i]),
		"stars": stars + (_drop_cells() if here else ([] as Array[Vector2i])), "safe_cells": safe_cells, "pins": map_pins(view),
		"title": tr(d.title) + (tr("  (you are here)") if here else ""),
		"info": "%d/%d  %s" % [idx + 1, areas.size(), tr("Floor map") if known else tr("No map - explored only")],
	}


# ── 裝備 App（紙娃娃）───────────────────────────────────

func _gear_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in Gear.SLOTS:
		if slot != "body":
			out.append({"slot": slot, "id": ""})
		for id in WorldState.data.gear_owned:
			if Gear.DATA.has(id) and Gear.DATA[id].slot == slot:
				out.append({"slot": slot, "id": id})
	return out


func _refresh_gear() -> void:
	var opts := _gear_options()
	gear_cursor = clampi(gear_cursor, 0, opts.size() - 1)
	var e := Gear.equipped()
	var doll: Array[Texture2D] = []
	for set_id in Gear.sprite_sets():
		doll.append(Art.tex("%s/walk_down_0" % set_id))
	phone.gear_doll = doll
	var slot_names := {"head": tr("HEAD"), "body": tr("BODY"), "feet": tr("FEET")}
	var header: Array[String] = []
	for slot in Gear.SLOTS:
		var id: String = e.get(slot, "")
		header.append("%s %s" % [slot_names[slot], tr(Gear.DATA[id].name) if id != "" else "-"])
	var full := Gear.full_set()
	header.append(tr(Gear.SETS[full].name) if full != "" else "")
	phone.gear_header = header
	var lines: Array[String] = []
	var start := clampi(gear_cursor - 2, 0, maxi(opts.size() - 5, 0))
	for i in range(start, mini(start + 5, opts.size())):
		var o: Dictionary = opts[i]
		var worn: bool = e.get(o.slot, "") == o.id
		var name := tr(Gear.DATA[o.id].name) if o.id != "" else tr("(nothing)")
		lines.append("%s%s %s%s" % ["> " if i == gear_cursor else "  ", slot_names[o.slot], name, "  *" if worn else ""])
	var sel: Dictionary = opts[gear_cursor]
	lines.append("")
	if sel.id != "":
		var g: Dictionary = Gear.DATA[sel.id]
		lines.append(tr(g.desc))
		if not g.stats.is_empty():
			lines.append(Gear.describe(g.stats))
		if g.has("set"):
			lines.append(tr("Set: %s - %s") % [tr(Gear.SETS[g.set].name), tr(Gear.SETS[g.set].desc)])
	lines.append(tr("[%s] wear") % _key_name("interact"))
	phone.set_text("\n".join(lines))
	phone.queue_redraw()


# ── 快捷選單（少按鍵：MGS1 式）─────────────────────────────

## 按住多久算「按住」（毫秒，真實時間：選單打開時遊戲會變慢）
const QUICK_HOLD_MS := 220


func _process_quick_menu() -> void:
	if _player.is_hiding or not _player.input_enabled and not quick_menu.visible:
		return
	for key in ["item", "weapon"]:
		if Input.is_action_just_pressed(key) and _qm_key == "":
			if key == "weapon" and _player.combat.aiming:
				continue  # 瞄準中的武器鍵 = 換鎖定目標
			_qm_key = key
			_qm_pressed_ms = Time.get_ticks_msec()
	if _qm_key == "":
		return
	if Input.is_action_pressed(_qm_key):
		if not quick_menu.visible and Time.get_ticks_msec() - _qm_pressed_ms >= QUICK_HOLD_MS:
			_open_quick_menu(_qm_key)
		elif quick_menu.visible:
			if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_down") \
					or Input.is_action_just_pressed("ui_right"):
				quick_menu.move(1)
			elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_up") \
					or Input.is_action_just_pressed("ui_left"):
				quick_menu.move(-1)
		return
	# 放開
	if quick_menu.visible:
		var id := quick_menu.selected_id()
		if _qm_key == "item":
			WorldState.data.quick_item = id
		elif id != "":
			_equip_weapon(id)
		quick_menu.close()
		Engine.time_scale = 1.0
		_player.input_enabled = true
		Sfx.play("ui_confirm")
	elif _qm_key == "item":
		use_quick_item()
	else:
		_cycle_weapon()
	_qm_key = ""


func _open_quick_menu(key: String) -> void:
	var list := quick_items() if key == "item" else quick_weapons()
	if list.is_empty():
		return
	quick_menu.open(key, list, WorldState.data.get("quick_item", "light") if key == "item" else WorldState.equipped)
	Engine.time_scale = 0.2
	_player.input_enabled = false
	_player.velocity = Vector2.ZERO


## 道具列：光源＋身上可以「用」的東西（投擲物、急救、解藥、暖暖包、材料）
func quick_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": "light", "name": tr("Light: %s") % tr(_player.light_name()),
		"icon": Art.tex("props/flashlight"), "count": 0}]
	var seen := {}
	for slot in WorldState.inventory():
		if slot.is_empty() or seen.has(slot.id):
			continue
		var kind: String = Items.get_item(slot.id).kind
		if kind in ["throwable", "heal", "cure", "warm", "craft", "attach", "campfire"]:
			seen[slot.id] = true
			out.append({"id": slot.id, "name": Items.display_name(slot.id), "icon": Art.tex("props/" + slot.id),
				"count": WorldState.inv_count(slot.id)})
	return out


func quick_weapons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w in PlayerCombat.WEAPONS:
		if WorldState.inv_count(w) > 0:
			out.append({"id": w, "name": "%s  %d/%d" % [Items.display_name(w), WorldState.get_loaded(w),
				PlayerCombat.weapon_stats(w).mag], "icon": Art.tex("props/" + w), "count": 0})
	# 近戰：小刀／空手（把刀收起來用拳腳），加上身上有的重兵器。目前用的那個前面打勾
	for m in WorldState.melee_options():
		var label := tr("Bare hands") if m == "fists" else Items.display_name(m)
		out.append({"id": "melee:" + m, "name": ("* " if WorldState.melee() == m else "") + tr("Melee: %s") % label,
			"icon": Art.tex("props/" + ("fists" if m == "fists" else m)), "count": 0})
	return out


## 按一下道具鍵：用選好的道具（光源 = 切換；投擲物 = 丟；其他 = 使用）
func use_quick_item() -> void:
	var id: String = WorldState.data.get("quick_item", "light")
	if id != "light" and WorldState.inv_count(id) <= 0:
		id = "light"
		WorldState.data.quick_item = "light"
	if id == "light":
		_player.cycle_light()
		return
	var kind: String = Items.get_item(id).kind
	if kind == "throwable":
		_player.throw_item(id)
	elif kind == "attach":
		_toggle_suppressor()
	elif _player.use_item(id):
		Sfx.play("ui_confirm")
		show_message(tr("You light a small fire. Warmth - and light anyone can see.") if kind == "campfire"
			else tr("Used %s.") % Items.display_name(id))
	else:
		Sfx.play("gun_empty")


func _toggle_suppressor() -> void:
	var on := WorldState.toggle_suppressor()
	Sfx.play("reload", _player.global_position, 0.2, -8.0)
	show_message(tr("Suppressor fitted. The pistol is quiet now.") if on else tr("Suppressor removed."))


func _cycle_weapon() -> void:
	var list := quick_weapons()
	if list.size() < 2:
		return
	var ids := list.map(func(e): return e.id).filter(func(id): return not String(id).begins_with("melee:"))
	if ids.size() < 2:
		return
	_equip_weapon(ids[(ids.find(WorldState.equipped) + 1) % ids.size()])


func _equip_weapon(id: String) -> void:
	if id.begins_with("melee:"):
		set_melee(id.substr(6))
		return
	if id == WorldState.equipped:
		return
	_player.combat.interrupt()
	WorldState.equipped = id
	Sfx.play("reload", _player.global_position, 0.1, -6.0)
	show_message(tr("Equipped %s.") % Items.display_name(id))


## 換近戰方式：小刀 ⇄ 空手，或消防斧、鐵撬
func set_melee(m: String) -> void:
	if m == WorldState.melee():
		return
	WorldState.set_melee(m)
	_player.combat.combo_step = 0
	Sfx.play("knife_swing", _player.global_position, 0.1, -10.0)
	match m:
		"fists":
			show_message(tr("Knife sheathed. Bare hands: jab, hook, kick."))
		"knife":
			show_message(tr("Knife drawn: slash, slash, thrust."))
		_:
			show_message(tr("Equipped %s.") % Items.display_name(m))


# ── 過場 ──────────────────────────────────────────────

## 這個區域（或房間）有沒有還沒看過的過場
func _check_cutscene(area_id: String) -> void:
	var id: String = Areas.all().get(area_id, {}).get("cutscene", "")
	if id != "":
		# 合併進來的區域：過場裡的「第幾隻敵人」從那個區域自己的第一隻開始算
		var base := 0
		if level:
			for r in level._data.get("regions", []):
				if r.id == area_id:
					base = r.get("enemy_start", 0)
		await play_cutscene(id, base)


## 播放一段過場：遊戲暫停（敵人定格）、上下黑邊、鏡頭移動、對白。看過就不再播。
func play_cutscene(id: String, enemy_base := 0) -> void:
	if WorldState.mode != "story" or not WorldState.cutscenes or not Cutscenes.DATA.has(id) or WorldState.has_flag("scene:" + id) \
			or cutscene.active or _player.is_dead:
		return
	WorldState.set_flag("scene:" + id)
	await _run_steps(Cutscenes.DATA[id], enemy_base)


## 播一串過場步驟（過場、野戰無線電共用）
func _run_steps(steps: Array, enemy_base := 0) -> void:
	if phone.visible:
		close_phone()
	var was_paused := get_tree().paused
	get_tree().paused = true
	_player.velocity = Vector2.ZERO
	await cutscene.open()
	var lights: Array[Node] = []
	for step: Dictionary in steps:
		if cutscene.skipping:
			break
		if step.has("caption"):
			await cutscene.caption(tr(step.caption), step.get("time", 2.0))
		elif step.has("say"):
			await cutscene.say(tr(step.say), tr(step.text), step.get("auto", 0.0), _speaker_portrait(step.say))
		elif step.has("pan"):
			var at := (Vector2(step.pan) + Vector2(0.5, 0.5)) * Level.TILE
			if step.has("light"):
				lights.append(_cutscene_light(at, step.light))
			await _pan_camera(at, step.get("time", 1.5))
		elif step.has("pan_enemy"):
			var i: int = step.pan_enemy + enemy_base
			if i < enemies.size() and is_instance_valid(enemies[i]):
				var e: Enemy = enemies[i]
				e.reveal_for_cutscene()
				lights.append(_cutscene_light(e.global_position, 60.0))
				await _pan_camera(e.global_position, step.get("time", 1.5))
		elif step.has("back"):
			await _pan_camera(_player.global_position, step.back)
		elif step.has("wait"):
			await cutscene.wait(step.wait)
		elif step.has("sfx"):
			Sfx.play(step.sfx)
		elif step.has("era"):
			set_era(step.era)
		# ── 電影式的鏡頭語言 ──
		elif step.has("fade_out"):
			await cutscene.fade_out(step.fade_out)
		elif step.has("fade_in"):
			await cutscene.fade_in(step.fade_in)
		elif step.has("title_card"):
			await cutscene.title_card(tr(step.title_card), tr(step.get("sub", "")), step.get("time", 2.5))
		elif step.has("name"):
			cutscene.name_card(tr(step.name), tr(step.get("role", "")), step.get("time", 3.0))
		elif step.has("credit"):
			cutscene.credit(tr(step.credit), step.get("time", 2.5))
		elif step.has("flash"):
			cutscene.flash(step.flash)
		elif step.has("shake"):
			_shake_camera(step.shake, step.get("time", 0.5))
		elif step.has("zoom"):
			await _zoom_camera(step.zoom, step.get("time", 1.0))
		elif step.has("music"):
			Sfx.play_music(step.music)
	set_era(Areas.get_area(level.area_id).get("era", "") if level else "")
	_camera.zoom = Vector2.ONE
	_camera.offset = Vector2.ZERO
	for l in lights:
		if is_instance_valid(l):
			l.queue_free()
	_camera.snap_to_target()
	await cutscene.close()
	get_tree().paused = was_paused


## ── Boss 戰的演出（Enemy.boss_event）──
var _boss_dark := false
var _boss_banner: Label


func _on_boss_event(kind: String, data: Dictionary) -> void:
	match kind:
		"phase":
			_show_boss_banner(tr(data.get("title", "")), tr(data.get("text", "")))
			_shake_camera(4.0, 0.8)
			Sfx.rumble(300, 0.8)
		"blackout":
			_boss_dark = true
			# 燈全滅：關掉這個區域裡所有的燈（主角的手電筒、Boss 身上的結晶除外）
			for l in level.find_children("*", "PointLight2D", true, false):
				if not _player.is_ancestor_of(l):
					l.set_meta("boss_off", true)
					l.visible = false
			Sfx.play("breaker_off" if SoundList.SFX.has("breaker_off") else "door_locked")
			_apply_darkness()
		"summon":
			var e := spawn_enemy(data.type, data.pos)
			e.set_meta("summoned", true)
			e.answer_call(_player.global_position)
		"icicle":
			Icicle.drop(level, data.pos, data.get("warn", 1.1))
		"flare":
			# 典獄長的照明彈：主角附近亮起一大片，慢慢暗下去
			var light := PointLight2D.new()
			light.texture = LightTextures.make_radial()
			light.texture_scale = 220.0 / (LightTextures.SIZE * 0.5)
			light.color = Color(1.0, 0.55, 0.45)
			light.energy = 1.1
			light.global_position = data.pos
			level.add_child(light)
			Sfx.play("flare_fire" if SoundList.SFX.has("flare_fire") else "pistol_shot", data.pos)
			var t := create_tween()
			t.tween_property(light, "energy", 0.0, 6.0)
			t.tween_callback(light.queue_free)


## 畫面中間的 Boss 階段字（例：苔原之母　狂暴）
func _show_boss_banner(title: String, text: String) -> void:
	if _boss_banner == null:
		_boss_banner = Label.new()
		_boss_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_boss_banner.offset_left = -200
		_boss_banner.offset_right = 200
		_boss_banner.offset_top = 70
		_boss_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boss_banner.add_theme_font_size_override("font_size", 24)
		_boss_banner.add_theme_color_override("font_color", Color(0.95, 0.3, 0.25))
		_boss_banner.add_theme_color_override("font_outline_color", Color.BLACK)
		_boss_banner.add_theme_constant_override("outline_size", 4)
		_boss_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HUD.add_child(_boss_banner)
	_boss_banner.text = "%s\n%s" % [title, text] if title != "" else text
	_boss_banner.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(_boss_banner, "modulate:a", 0.0, 0.8)


## 時代的畫面色調：""＝現在、"1962"＝泛黃的老底片、"2099"＝未來的霓虹幻象
const ERAS := {"": 0.0, "2026": 0.0, "1962": 1.0, "2099": 2.0}


func set_era(era: String) -> void:
	if _film_mat:
		_film_mat.set_shader_parameter("era", ERAS.get(era, 0.0))


func current_era() -> float:
	return _film_mat.get_shader_parameter("era") if _film_mat else 0.0


## 播放盤式錄音機（MemoryReel）：先演過場，再走進那段記憶（或從記憶回到現在）
func _on_play_reel(target_area: String, entry: String, scene: String, flag: String) -> void:
	if _transitioning or target_area == "":
		return
	if scene != "":
		await play_cutscene(scene)
	if flag != "":
		WorldState.set_flag(flag)
		WorldState.emit_event("memory", flag)
	Sfx.play("radio_static")
	await load_area(target_area, entry)


## 對白的頭像：沈若寧依目前狀況（受傷、感染）換表情；守門派是頭盔；無線電另外的人用科瓦契
func _speaker_portrait(speaker: String) -> Texture2D:
	if speaker == Cutscenes.SHEN:
		return Art.tex("portraits/shen_" + _player.get_condition().to_lower())
	if speaker.begins_with("[GATE") or speaker.begins_with("[WARDEN"):
		return Art.tex("portraits/gate")
	if speaker.begins_with("[KOVAC"):
		return Art.tex("portraits/kovac")
	return null


func _pan_camera(to: Vector2, time: float) -> void:
	if cutscene.skipping:
		return
	var t := cutscene.create_tween()
	t.tween_property(_camera, "global_position", to.round(), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## 鏡頭震動（過場）：strength 像素，time 秒內慢慢停下來
func _shake_camera(strength: float, time: float) -> void:
	if cutscene.skipping:
		return
	var t := cutscene.create_tween()
	var steps := int(time / 0.04)
	for i in steps:
		var k := 1.0 - float(i) / steps
		t.tween_property(_camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * strength * k, 0.04)
	t.tween_property(_camera, "offset", Vector2.ZERO, 0.04)


## 鏡頭推近／拉遠（過場的特寫）。zoom = 倍率（1 = 平常）
func _zoom_camera(z: float, time: float) -> void:
	if cutscene.skipping:
		return
	var t := cutscene.create_tween()
	t.tween_property(_camera, "zoom", Vector2(z, z), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _cutscene_light(at: Vector2, radius: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = LightTextures.make_radial()
	light.texture_scale = radius / (LightTextures.SIZE * 0.5)
	light.energy = 0.8
	light.color = Color(0.75, 0.85, 1.0)
	light.global_position = at
	level.add_child(light)
	return light


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished


# ── 被抓到、重來 ──────────────────────────────────────

## 合併進主地圖的房間用「房間:入口」找入口位置
func entry_key(area_id: String, entry: String) -> String:
	return entry if Areas.root_of(area_id) == area_id else "%s:%s" % [area_id, entry]


## 主角現在所在的區域 id（在合併進來的房間裡 = 那個房間的 id，例如 station_safe）
func current_area_id() -> String:
	return level.region_at(_player.global_position) if level else ""


## 走進／走出合併進來的房間：觸發任務事件、換燈光
func _update_region() -> void:
	if level == null or _transitioning:
		return
	if level.fog:
		level.fog.peek_cells = _player.peek_cells()
		level.fog.update(_player.global_position)
	var region := current_area_id()
	if region != _region:
		_region = region
		_checkpoint_at_region_door(region)
		WorldState.emit_event("enter_area", region)
		_apply_darkness()
		_check_cutscene(region)


## 無縫地圖：走過門進入另一個區域（例如從南岸走進研究站）時，跟以前切換區域一樣存檢查點（門口）
func _checkpoint_at_region_door(region: String) -> void:
	if WorldState.mode != "story" or _player.is_dead or level.is_safe_at(_player.global_position):
		return
	var best: Dictionary = {}
	var best_d := 3.5 * Level.TILE
	for rd in level._data.get("region_doors", []):
		if rd.region != region:
			continue
		var d := _player.global_position.distance_to((Vector2(rd.cell) + Vector2(0.5, 0.5)) * Level.TILE)
		if d < best_d:
			best_d = d
			best = rd
	if not best.is_empty():
		WorldState.save_checkpoint(region, best.door)


func _apply_darkness() -> void:
	if _boss_dark:
		_darkness.color = Color(0.035, 0.035, 0.05)
		return
	if level.is_safe_at(_player.global_position):
		_darkness.color = SAFE_DARKNESS
	elif not level.is_indoor_at(_player.global_position):
		_darkness.color = OUTDOOR_DARKNESS if level.climate_id() == "temperate" else Weather.value("dark")
	elif level.is_lit_at(_player.global_position):
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
	play_cutscene("power_on")


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
	# Boss 戰的演出還原：燈、叫出來的手下、還沒掉下來的冰
	_boss_dark = false
	if _boss_banner:
		_boss_banner.modulate.a = 0.0
	if level:
		for l in level.find_children("*", "PointLight2D", true, false):
			if l.has_meta("boss_off"):
				l.remove_meta("boss_off")
				l.visible = true
	for e in enemies.duplicate():
		if e.has_meta("summoned"):
			enemies.erase(e)
			e.queue_free()
	if level:
		for n in level.get_children():
			if n is Icicle:
				n.queue_free()
	WorldState.restore_checkpoint()
	# 回到檢查點時至少有一半的體溫，避免一進戶外就凍死的死循環
	WorldState.body_temp = maxf(WorldState.body_temp, 60.0)
	level.sync_from_state()
	_player.reset_to(level.get_entry_position(entry_key(WorldState.checkpoint_area(), WorldState.checkpoint_entry())))
	_region = current_area_id()
	_apply_darkness()
	for enemy in enemies:
		enemy.reset()
		enemy.restore_snapshot()
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
	# 長的訊息（錄音、文件、無線電）在通知裡只看得到開頭：完整內容在手機「訊息」
	_message_more.visible = _message.text.length() > MESSAGE_SHORT
	_message_more.text = tr("[%s] Phone") % _key_name("inventory")
	if message_log.is_empty() or message_log[0] != _message.text:
		message_log.push_front(_message.text)
		if message_log.size() > 60:
			message_log.pop_back()


# ── 手機 ──────────────────────────────────────────────

func _build_phone() -> void:
	phone = Phone.new()
	phone.name = "Phone"
	$HUD.add_child(phone)
	$HUD.move_child(phone, _mission_panel.get_index())
	phone.app_pressed.connect(set_phone_app)
	phone.close_pressed.connect(close_phone)
	mission_list = MissionList.new()
	mission_list.name = "MissionList"
	mission_list.main = self
	$HUD.add_child(mission_list)
	$HUD.move_child(mission_list, phone.get_index() + 1)
	# 物品、任務沿用原本的面板，擺進手機螢幕裡
	for p in [_inventory_panel, _mission_panel]:
		p.set_anchors_preset(Control.PRESET_TOP_LEFT)
		p.position = Phone.CONTENT.position
		p.size = Phone.CONTENT.size
		p.custom_minimum_size = Vector2.ZERO
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for t in [_inventory_text, _mission_text]:
		t.clip_text = true
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Phone.CONTENT.size  # clip_text 的 Label 最小高度是 0，要自己給
	# 通知：畫面左上角一行（手機跳出來的通知），不擋遊戲畫面
	_message.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_message.position = Vector2(6, 4)
	_message.size = Vector2(268, 14)
	_message.autowrap_mode = TextServer.AUTOWRAP_OFF
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message.clip_text = true
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_message.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_message_more = Label.new()
	_message_more.add_theme_font_size_override("font_size", 12)
	_message_more.add_theme_color_override("font_color", Color(0.6, 0.95, 0.85))
	_message_more.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_more.add_theme_constant_override("outline_size", 3)
	_message_more.position = Vector2(6, 17)
	_message_more.visible = false
	$HUD.add_child(_message_more)
	# 武器資訊：只有舉槍、裝填、搬東西時出現在右下角
	_items.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_items.offset_left = -260
	_items.offset_right = -4
	_items.offset_top = -52
	_items.offset_bottom = -38


func open_phone(app: String) -> void:
	if not phone.visible:
		Sfx.play("ui_confirm")
		map_view = ""
	phone.visible = true
	get_tree().paused = true
	set_phone_app(app)


func close_phone() -> void:
	phone.visible = false
	_inventory_panel.visible = false
	_mission_panel.visible = false
	mission_list.visible = false
	get_tree().paused = false
	Sfx.play("ui_cancel")


func set_phone_app(app: String) -> void:
	if phone.app != app or not phone.visible:
		map_view = ""  # 打開地圖時先看目前所在的區域
	if phone.app != app:
		Sfx.play("ui_move")
	phone.set_app(app)
	_inventory_panel.visible = false
	_mission_panel.visible = false
	mission_list.visible = app == "missions"
	mission_list.queue_redraw()
	if app == "messages":
		_message_cursor = 0
	_refresh_phone()


func _process_phone_input() -> void:
	var step := 0
	if Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("ui_right"):
		step = 1
	elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("ui_left"):
		step = -1
	if step != 0:
		set_phone_app(phone.next_app(step))
		return
	match phone.app:
		"missions":
			if Input.is_action_just_pressed("phone") or Input.is_action_just_pressed("pause") \
					or Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("inventory"):
				close_phone()
			elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
				mission_list.move(1)
			elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
				mission_list.move(-1)
			elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
				mission_list.toggle()
				_arrow_timer = 0.0
		_:
			if Input.is_action_just_pressed("inventory") or Input.is_action_just_pressed("phone") \
					or Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("ui_cancel"):
				close_phone()
			elif phone.app == "gear":
				var n := _gear_options().size()
				if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
					gear_cursor = (gear_cursor + 1) % n
					Sfx.play("ui_move")
					_refresh_phone()
				elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
					gear_cursor = (gear_cursor + n - 1) % n
					Sfx.play("ui_move")
					_refresh_phone()
				elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
					var opt: Dictionary = _gear_options()[gear_cursor]
					if WorldState.equip_gear(opt.slot, opt.id):
						Sfx.play("ui_confirm")
					_refresh_phone()
			elif phone.app == "map":
				var areas := known_map_areas()
				var flip := 0
				if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
					flip = 1
				elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
					flip = -1
				if flip != 0 and areas.size() > 1:
					map_view = areas[(areas.find(map_view) + flip + areas.size()) % areas.size()]
					Sfx.play("ui_move")
					_refresh_phone()
			elif phone.app == "codex":
				var n := Codex.ENTRIES.size()
				if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
					codex_cursor = (codex_cursor + 1) % n
					Sfx.play("ui_move")
					_refresh_phone()
				elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
					codex_cursor = (codex_cursor + n - 1) % n
					Sfx.play("ui_move")
					_refresh_phone()
			elif phone.app == "messages" and not message_log.is_empty():
				if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("ui_down"):
					_message_cursor = mini(_message_cursor + 1, message_log.size() - 1)
					Sfx.play("ui_move")
				elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("ui_up"):
					_message_cursor = maxi(_message_cursor - 1, 0)
					Sfx.play("ui_move")


## 手機各 App 的內容
func _refresh_phone() -> void:
	phone.level = level
	phone.player_pos = _player.global_position
	phone.portrait = Art.tex("portraits/shen_" + _player.get_condition().to_lower())
	match phone.app:
		"status":
			phone.set_text(_build_status_text())
		"messages":
			if message_log.is_empty():
				phone.set_text(tr("No messages."))
			else:
				phone.set_text("%d / %d\n\n%s" % [_message_cursor + 1, message_log.size(), message_log[_message_cursor]])
		"codex":
			_refresh_codex()
		"gear":
			_refresh_gear()
		"map":
			_refresh_map()


## 圖鑑 App：上下選一筆。沒遇過的只顯示剪影和「???」
func _refresh_codex() -> void:
	var ids := Codex.ids()
	codex_cursor = clampi(codex_cursor, 0, ids.size() - 1)
	var id: String = ids[codex_cursor]
	var e: Dictionary = Codex.ENTRIES[id]
	var open := Codex.unlocked(id)
	phone.codex_locked = not open
	phone.codex_icon = Art.tex(e.sprite) if e.sprite != "" else null
	var header: Array[String] = ["%s  %d/%d" % [tr(Codex.GROUP_TITLES[e.group]), codex_cursor + 1, ids.size()],
		tr(e.name) if open else "???"]
	if open and e.group != "weapon":
		header.append(tr("Downed: %d") % WorldState.codex_kills(id))
	header.append(tr("Found %d/%d") % [Codex.count_unlocked(), ids.size()])
	phone.codex_header = header
	if open:
		phone.set_text("%s\n\n%s" % [tr(e.desc), tr("Tip: %s") % tr(e.tip)])
	else:
		phone.set_text(tr("Not yet encountered.") + "\n\n" + tr("[Up/Down] browse"))
	phone.queue_redraw()


func _build_status_text() -> String:
	var lines: Array[String] = []
	lines.append(tr("Condition: %s%s%s") % [tr(_player.get_condition()),
		tr("  (infected)") if _player.infection >= WorldState.MAX_INFECTION else "", ""])
	lines.append(tr("Infection: %s") % tr(_infection_word()))
	if level and Climates.has_exposure(level.climate_id()):
		lines.append(tr("  Body: %s").replace("\u3000", "").strip_edges() % tr(_player.get_body_temp_state()))
	lines.append(tr("Light: %s") % tr(_player.light_name()))
	var weapon := _player.combat.current_weapon()
	if weapon != "":
		lines.append("%s %d/%d (+%d)" % [Items.display_name(weapon), WorldState.get_loaded(weapon),
			_player.combat.magazine_size, WorldState.inv_count(_player.combat.stats().ammo)])
	var throwable := _player.current_throwable()
	if throwable != "":
		lines.append(tr("Throw: %s x%d") % [Items.display_name(throwable), WorldState.inv_count(throwable)])
	if WorldState.access_level > 0:
		lines.append(tr("Card Lv%d") % WorldState.access_level)
	if level:
		lines.append("")
		lines.append(tr(level.region_title(current_area_id())))
	return "\n".join(lines)


func _infection_word() -> String:
	var v := _player.infection
	if v >= WorldState.MAX_INFECTION:
		return "Critical"
	if v >= 60.0:
		return "Severe"
	if v >= 25.0:
		return "Mild"
	return "None"


# ── 安全屋：無線電、儲物箱 ──────────────────────────────

## 用無線電：接收新的委託、在無線電旁邊存檢查點、存到硬碟，然後打開調頻介面。
func _on_radio_used() -> void:
	if WorldState.mode != "story":
		show_message(tr("Only static. No saving out here tonight."))
		return
	_radio_transcript.clear()
	if not WorldState.has_flag("radio:intro"):
		WorldState.set_flag("radio:intro")
		_radio_transcript.append(tr(KOVAC_INTRO))
	for text in RadioCalls.receive():
		_radio_transcript.append(tr(text))
	for text in Missions.receive_radio():
		_radio_transcript.append(tr(text))
	WorldState.save_checkpoint(current_area_id(), "radio")
	var saved := WorldState.save_to_disk()
	_radio_transcript.append(tr("Progress saved.") if saved else tr("Save failed."))
	if saved:
		Sfx.play("save_chime")
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
		Sfx.play("radio_tune")
	elif Input.is_action_just_pressed("switch_target"):
		_next_memo()
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		Sfx.play("radio_static")
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
	if radio_dial:
		radio_dial.freq = _radio_freq
		radio_dial.strength = strength
		radio_dial.known = WorldState.known_freqs()
	var lines: Array[String] = [
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
	if backpack.visible:
		backpack.close()
	else:
		Sfx.play("ui_confirm")
		get_tree().paused = true
		backpack.open("storage")


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
	Sfx.play("uplink_transmit")
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
	style.set_content_margin_all(12)
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
	Sfx.play_music("ending", 3.0)
	Sfx.play_ambience("")
	await get_tree().create_timer(ENDING_DELAY).timeout
	# 段落之間不空行（加了 2099 年的那一句之後，空行會讓文字超出畫面）
	var lines: Array[String] = [tr(last_ending.title), ""]
	for line in last_ending.lines:
		lines.append(tr(line))
	lines.append("")
	lines.append(tr("THE END"))
	_ending_text.text = "\n".join(lines)
	set_era("2099")  # 結局的最後一句是 2099 年：畫面換成未來的霓虹色調
	_ending_panel.visible = true
	get_tree().paused = true


# ── 暫停選單 ──────────────────────────────────────────

func _toggle_pause() -> void:
	_pause_panel.visible = not _pause_panel.visible
	# 操作說明放在暫停選單（遊戲畫面、手機都不用一直擺）
	var box := _pause_panel.get_node("Box")
	var help: Label = box.get_node_or_null("Controls")
	if help == null:
		help = Label.new()
		help.name = "Controls"
		help.add_theme_font_size_override("font_size", 12)
		help.add_theme_color_override("font_color", Color(0.65, 0.75, 0.8))
		# 中文的操作說明是一整行：要自動換行，不然暫停選單會被撐到超出畫面
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.custom_minimum_size = Vector2(300, 0)
		box.add_child(help)
	help.text = _build_hint().replace("  ", "\n")
	# 內容變了（操作說明、選項按鈕）：重新算大小，放回畫面正中間
	_pause_panel.reset_size()
	_pause_panel.position = ((get_viewport().get_visible_rect().size - _pause_panel.size) * 0.5).floor()
	Sfx.play("ui_confirm" if _pause_panel.visible else "ui_cancel")
	get_tree().paused = _pause_panel.visible
	if _pause_panel.visible:
		_resume_button.grab_focus()


# ── 生存模式 ──────────────────────────────────────────

func _start_survival() -> void:
	survival = SurvivalMode.new()
	survival.name = "Survival"
	add_child(survival)
	survival.setup(self, WorldState.survival_setup.get("map", "station_1f"))
	survival_results = SurvivalResults.new()
	$HUD.add_child(survival_results)
	survival.finished.connect(_on_survival_finished)
	survival_results.retry.connect(func():
		get_tree().paused = false
		WorldState.start_survival(WorldState.survival_setup.map, WorldState.survival_setup.weapon)
		get_tree().reload_current_scene())
	survival_results.to_menu.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file(SURVIVAL_MENU_SCENE))
	survival_results.to_title.connect(_quit_to_title)


func _on_survival_died() -> void:
	_player.input_enabled = false
	_banner.text = tr("YOU DIED")
	_banner.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	_banner.visible = true
	await get_tree().create_timer(1.5).timeout
	_banner.visible = false
	survival.finish(false)


func _on_survival_finished(_result: Dictionary) -> void:
	_player.input_enabled = false
	get_tree().paused = true
	survival_results.show_result(_result)


func _quit_to_title() -> void:
	get_tree().paused = false
	# 回標題：沒在無線電存過的進度會遺失
	get_tree().change_scene_to_file(TITLE_SCENE)


func _toggle_mission_panel() -> void:
	if phone.visible and phone.app == "missions":
		close_phone()
	else:
		open_phone("missions")


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
	# 平常不顯示（在手機「狀態」看得到）；舉槍、裝填、搬東西時才在右下角出現
	if not (_player.combat.aiming or _player.combat.reloading or WorldState.carrying != ""):
		return ""
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
	if WorldState.carrying == "fuel":
		parts.append(tr("CARRYING FUEL"))
	elif WorldState.carrying == "extinguisher":
		parts.append(tr("EXTINGUISHER %d  [%s] spray  [%s] throw") % [
			WorldState.extinguisher_charge, _key_name("fire"), _key_name("throw")])
	return "  ".join(parts)


# ── 物品欄 ────────────────────────────────────────────

func _toggle_inventory_panel() -> void:
	if backpack.visible:
		backpack.close()
	else:
		Sfx.play("ui_confirm")
		get_tree().paused = true
		backpack.open("bag")


## 使用背包裡第幾格的東西
func use_inventory_slot(index: int) -> void:
	var slot: Dictionary = WorldState.inventory()[index]
	if slot.is_empty():
		return
	var kind: String = Items.get_item(slot.id).kind
	var made: String = Items.get_item(slot.id).get("recipe", {}).get("makes", "")
	var item_name := Items.display_name(slot.id)
	if kind == "attach":
		_toggle_suppressor()
		return
	if kind == "melee":
		# 重兵器：拿在手上（再選一次 = 換回小刀）
		set_melee("knife" if WorldState.melee() == slot.id else slot.id)
		return
	if _player.use_item(slot.id):
		Sfx.play("ui_confirm")
		match kind:
			"weapon":
				show_message(tr("Equipped %s.") % item_name)
			"throwable":
				show_message(tr("%s ready to throw.") % item_name)
			"warm":
				show_message(tr("The heat pack spreads warmth through your chest."))
			"craft":
				show_message(tr("Made a %s. (Your lighter is always on you.)") % Items.display_name(made))
			"campfire":
				show_message(tr("You light a small fire. Warmth - and light anyone can see."))
				backpack.close()
			_:
				show_message(tr("Used %s.") % item_name)
	else:
		Sfx.play("ui_cancel")
		show_message(tr("Can't use that now."))


## 隨身裝備：小刀 ⇄ 空手、打火機、手電筒
func _use_kit(kit: String) -> void:
	match kit:
		"melee":
			set_melee("fists" if WorldState.melee() != "fists" else "knife")
		"lighter":
			_player.set_light("" if _player.lighter_on else "lighter")
		"flashlight":
			_player.set_light("" if _player.flashlight_on else "flashlight")
	backpack.queue_redraw()


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
		"%s %s" % [_key_name("dodge"), tr("Dodge")],
		"%s %s" % [_key_name("item"), tr("Item (hold: choose)")],
		"%s %s" % [_key_name("weapon"), tr("Weapon (hold: choose)")],
		"%s %s" % [_key_name("interact"), tr("Use")],
		"%s %s" % [_key_name("aim"), tr("Aim")],
		"%s %s" % [_key_name("fire"), tr("Fire")],
		"%s %s" % [_key_name("inventory"), tr("Backpack")],
		"%s %s" % [_key_name("map"), tr("Map")],
		"%s %s" % [_key_name("phone"), tr("Phone")],
		"%s %s" % [_key_name("call"), tr("Radio")],
	]
	return " ".join(parts)


# ── v0.11：野戰無線電、天氣、全島地圖 ─────────────────────

## 排一通來電（同一個 key 只響一次）
## 來電不要太吵（v0.13）：主線的來電（call:）一定排進去；提示類的（fcall:）同時最多等 2 通，
## 警戒中、剛接完電話 25 秒內不響（之後再響），沒接的提示 90 秒後自己掛掉。
const RADIO_TIP_LIMIT := 2
const RADIO_QUIET_AFTER := 25.0
const RADIO_TIP_EXPIRE := 90.0
var _radio_quiet := 0.0


func queue_radio(key: String, steps: Array) -> void:
	if WorldState.has_flag(key) or radio_queue.any(func(c): return c.key == key):
		return
	var tip := key.begins_with("fcall:")
	if tip:
		if _radio_quiet > 0.0 or radio_queue.filter(func(c): return c.tip).size() >= RADIO_TIP_LIMIT:
			return  # 這次不響；條件還在的話之後會再排
		if level and level.alert and level.alert.phase == AlertNetwork.Phase.ALERT and key != "fcall:event:alert":
			return
	radio_queue.append({"key": key, "steps": steps, "tip": tip, "age": 0.0})
	if radio_queue.size() == 1:
		Sfx.play("radio_static")


func radio_ringing() -> bool:
	return not radio_queue.is_empty()


## 接來電；沒有來電 = 自己打過去問柯瓦奇（依現在追蹤的任務）
func answer_radio() -> void:
	if cutscene.active or WorldState.mode != "story":
		return
	if current_era() > 0.5:
		show_message(tr("Only static. There is nobody to call in 1962."))
		return
	if not radio_queue.is_empty():
		var call: Dictionary = radio_queue.pop_front()
		WorldState.set_flag(call.key)
		_radio_quiet = RADIO_QUIET_AFTER
		await _run_steps(call.steps)
		return
	var m := Missions.tracked_mission()
	var steps := [{"sfx": "radio_static"}]
	if m.is_empty():
		steps.append({"say": FieldRadio.K, "text": "Nothing urgent from my end. Stay warm, stay quiet."})
	else:
		steps.append({"say": FieldRadio.K, "text": tr("What you're doing now: %s") % tr(m.title)})
		steps.append({"say": FieldRadio.K, "text": tr(m.desc)})
		steps.append({"say": FieldRadio.K, "text": "It's marked on your map. Press the map key to see it."})
	await _run_steps(steps)


## RadioCalls 的「KOVAC: "…"」→ 過場步驟（先翻譯，再拿掉說話的人，對白框另外標）
func _radio_call_steps(lines: Array) -> Array:
	var out: Array = [{"sfx": "radio_static"}]
	for t in lines:
		var text := tr(t)
		for sep in ["：「", ": \""]:
			var i := text.find(sep)
			if i >= 0 and i < 12:
				text = text.substr(i + sep.length()).trim_suffix("」").trim_suffix("\"")
				break
		out.append({"say": FieldRadio.K, "text": text})
	return out


## 每 0.5 秒看一次：第一次進入區域、第一次看到某種敵人、第一次被發現 → 來電
func _update_field_radio(delta: float) -> void:
	_radio_quiet = maxf(_radio_quiet - delta, 0.0)
	for c in radio_queue:
		c.age += delta
	# 沒接的提示自己掛掉（不設旗標：之後還有機會再響）
	radio_queue = radio_queue.filter(func(c): return not c.tip or c.age < RADIO_TIP_EXPIRE)
	_radio_check -= delta
	if _radio_check > 0.0:
		return
	_radio_check = 0.5
	var region := current_area_id()
	if FieldRadio.AREA.has(region):
		queue_radio("fcall:area:" + region, FieldRadio.steps(FieldRadio.AREA[region]))
	for id in FieldRadio.ENEMY:
		if WorldState.codex_has(id):
			queue_radio("fcall:enemy:" + id, FieldRadio.steps(FieldRadio.ENEMY[id]))
	if level.alert and level.alert.phase == AlertNetwork.Phase.ALERT:
		queue_radio("fcall:event:alert", FieldRadio.steps(FieldRadio.EVENT.alert))
	if level.tracks and level.tracks.followed:
		queue_radio("fcall:event:tracks", FieldRadio.steps(FieldRadio.EVENT.tracks))
	_check_bodies()


## v0.12：屍體被看到 → 通報、整區戒備；倒下太久沒人回報（無線電定時點名）→ 派人去看
const CHECK_IN_MS := 40000
var _check_in_sent := {}


func _check_bodies() -> void:
	var net := level.alert
	for b in enemies:
		if not is_instance_valid(b) or not b.is_human() or b.stashed or b.body_found or not (b.is_dead or b.is_asleep()):
			continue
		for e in enemies:
			if not is_instance_valid(e) or e == b or e.is_dead or e.is_asleep() or e.held_up or not e.is_human():
				continue
			var to: Vector2 = b.global_position - e.global_position
			if to.length() < e.vision_range and e.facing.dot(to.normalized()) > cos(e.get_half_angle()) \
					and Sight.is_clear(e, e.global_position, b.global_position):
				b.body_found = true
				show_message(tr("Enemy radio: \"Man down! We have a man down!\""), true)
				Sfx.play("radio_static")
				if net:
					net.raise_caution(b.global_position)
				e.answer_call(b.global_position)
				break
		if not b.body_found and Time.get_ticks_msec() - b.down_since > CHECK_IN_MS and not _check_in_sent.has(b.get_instance_id()):
			_check_in_sent[b.get_instance_id()] = true
			for e in enemies:
				if is_instance_valid(e) and not e.is_dead and not e.is_asleep() and e.is_human() and not e.held_up:
					show_message(tr("Enemy radio: \"Post, report... Post, respond.\" Somebody is coming to check."), true)
					e.answer_call(b.global_position)
					break


## 天氣：換天氣時通知；戶外的暗度跟著慢慢變
func _update_weather(delta: float) -> void:
	if Weather.update(delta):
		show_message(tr("Weather: %s") % tr(Weather.display_name()))
		if Weather.kind() == "blizzard" or Weather.kind() == "clear":
			queue_radio("fcall:event:" + Weather.kind(), FieldRadio.steps(FieldRadio.EVENT[Weather.kind()]))
	_weather_dark_timer -= delta
	if _weather_dark_timer <= 0.0:
		_weather_dark_timer = 0.5
		_apply_darkness()


## ── 隨機事件（v0.13，開放世界）：戶外偶爾有補給空投（紅色信號彈標出位置，地圖上是藍色星號）──
const DROP_MIN := 200.0
const DROP_MAX := 360.0
const DROP_LOOT := [["med", 1], ["ammo", 10], ["heat_pack", 2], ["shells", 3], ["darts", 3], ["antibiotic", 1], ["rifle_rounds", 3]]
var supply_drops: Array[ItemPickup] = []
var _drop_timer := 240.0


func _update_world_events(delta: float) -> void:
	if level.is_indoor_at(_player.global_position) or level.climate_id() == "temperate":
		return
	_drop_timer -= delta
	if _drop_timer > 0.0:
		return
	_drop_timer = randf_range(DROP_MIN, DROP_MAX)
	spawn_supply_drop()


## 在主角附近（10～22 格外）走得到的戶外雪地丟一個補給。回傳 null = 找不到地方。
func spawn_supply_drop() -> ItemPickup:
	var from := level.cell_of(_player.global_position)
	var nav := level.get_navigation_map()
	for attempt in 80:
		var c := from + Vector2i(randi_range(-22, 22), randi_range(-16, 16))
		var d := Vector2(c - from).length()
		if d < 10.0 or level.char_at(c) != "." or level._is_indoor_cell(c):
			continue
		var pos := (Vector2(c) + Vector2(0.5, 0.5)) * Level.TILE
		var path := NavigationServer2D.map_get_path(nav, _player.global_position, pos, true)
		if path.is_empty() or path[-1].distance_to(pos) > 6.0:
			continue
		var loot: Array = DROP_LOOT[randi() % DROP_LOOT.size()]
		var item := level.add_dynamic_item(loot[0], loot[1], pos, "drop:%d" % Time.get_ticks_msec())
		var flare := PointLight2D.new()
		flare.texture = LightTextures.make_radial()
		flare.texture_scale = 50.0 / (LightTextures.SIZE * 0.5)
		flare.color = Color(1.0, 0.35, 0.25)
		flare.energy = 0.9
		item.add_child(flare)
		supply_drops.append(item)
		show_message(tr("Supply drop: a red flare is burning on the snow. It's marked on your map."), true)
		Sfx.play("pistol_shot", pos, 0.1, -12.0)
		return item
	return null


func _drop_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in supply_drops:
		if is_instance_valid(d) and d.enabled:
			out.append(level.cell_of(d.global_position))
	return out


## 全島地圖的資料（MapPanel 的第一頁）
func island_data() -> Dictionary:
	var known := known_map_areas()
	var places := {}
	for id in Island.PLACES:
		var p: Dictionary = Island.PLACES[id]
		var seen := false
		for r in p.roots:
			if known.has(r):
				seen = true
		places[id] = {"name": tr(p.name), "pos": p.pos, "seen": seen, "here": p.roots.has(level.area_id),
			"safe": p.get("safe", false) and seen}
	var pins: Array[Dictionary] = []
	for pin in Missions.pinned():
		var t := mission_target(pin.mission)
		if not t.is_empty():
			pins.append({"color": pin.color, "title": tr(pin.mission.title), "place": Island.place_of(t.area)})
	return {"island": true, "places": places, "pins": pins, "title": tr("GREYCROW ISLAND"),
		"info": tr("Polar night  |  %s  |  < > change map") % tr(Weather.display_name())}


func _key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return event.as_text_physical_keycode()
	return "?"
