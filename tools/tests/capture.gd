## 截圖工具：Godot --path . res://tools/tests/capture.tscn -- <輸出資料夾>
extends Node

var _main: Node
var _player: Player
var _overlay: DebugOverlay
var _out := "user://"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		_out = OS.get_cmdline_user_args()[0]
	WorldState.save_path = "user://capture_save.dat"
	WorldState.new_game()
	WorldState.cutscenes = false
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_overlay = _main.get_node("Overlay/DebugOverlay")
	await _frames(30)

	_overlay.debug_enabled = false
	# 第二個參數 new = 只拍 AFTERSIGNAL 改版的新畫面（快速檢查用）
	if OS.get_cmdline_user_args().has("new"):
		await _aftersignal_shots()
		_main.queue_free()
		var title_new: Control = load("res://scenes/title.tscn").instantiate()
		add_child(title_new)
		await _frames(20)
		await _shot("61_title_neon")
		get_tree().quit()
		return
	await _shot("0_shore_start")
	_put_player(_tile(11, 8), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("0b_shore_door")
	# 無縫：從正門走進研究站（同一張地圖，門外的雪地也看得到）
	_put_player(_tile(16, 8), Vector2.LEFT, true)
	await _frames(40)
	await _shot("0d_station_front_inside")
	_put_player(_tile(58, 22), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("0e_shore_depot_lane")
	_main._toggle_mission_panel()
	await _frames(3)
	await _shot("0c_missions")
	_main._toggle_mission_panel()

	await _enter("station_1f", "cargo", false)
	var level: Level = _main.level
	var chimer: Enemy = _main.enemies[1]
	await _frames(20)
	await _shot("1_start")
	WorldState.set_flag("intel:station_1f")

	# 實驗室：鳴骨者被手電筒照到、看得到喀喀聲波紋
	chimer.patrol_points = [_tile(30, 7)] as Array[Vector2]
	chimer._spawn = chimer.patrol_points[0]
	chimer.reset()
	_put_player(_tile(25, 7), Vector2.RIGHT, true)
	await _frames(70)
	await _shot("2_lab_chimer")
	_overlay.debug_enabled = true
	await _frames(2)
	await _shot("3_lab_debug")

	# 關掉交誼廳暖氣：地板結霜
	level.set_zone_heated("lounge", false)
	_put_player(_tile(16, 6), Vector2.LEFT, true)
	await _frames(40)
	await _shot("4_lounge_cold_debug")

	# 躲進置物櫃
	_overlay.debug_enabled = false
	_put_player(_tile(18, 7), Vector2.RIGHT, true)
	await _frames(5)
	var locker: Locker
	for item in level.get_interactables():
		if item is Locker and item.global_position.distance_to(_tile(18, 8)) < 1.0:
			locker = item
	await _frames(5)
	await _shot("5_locker_prompt")
	var w0: Enemy = _main.enemies[0]
	w0.patrol_points = [_tile(17, 4)] as Array[Vector2]
	w0._spawn = w0.patrol_points[0]
	w0.reset()
	w0.facing = Vector2.DOWN
	_player.enter_hiding(locker)
	await _frames(20)
	await _shot("6_hiding")
	_player.exit_hiding()
	# 觀察窗：第一人稱看另一邊的實驗室
	w0.patrol_points = [_tile(27, 3)] as Array[Vector2]
	w0._spawn = w0.patrol_points[0]
	w0.reset()
	w0.facing = Vector2.LEFT
	_put_player(_tile(18, 3), Vector2.RIGHT, true)
	await _frames(5)
	for item in level.get_interactables():
		if item is WindowPane and item.global_position.distance_to(_tile(19, 3)) < 1.0:
			_main._on_window_look(item, _player.global_position)
	await _frames(20)
	await _shot("6b_window")
	_main.close_window_view()

	# 戰鬥：舉槍鎖定值班者
	var watcher: Enemy = _main.enemies[0]
	watcher.patrol_points = [_tile(11, 6)] as Array[Vector2]
	watcher._spawn = watcher.patrol_points[0]
	watcher.reset()
	watcher.facing = Vector2.UP
	WorldState.inv_add("pistol", 1)
	WorldState.inv_add("ammo", 10)
	WorldState.inv_add("med", 1)
	WorldState.inv_add("antibiotic", 1)
	WorldState.pistol_loaded = 6
	level.set_zone_heated("lounge", true)
	_put_player(_tile(5, 6), Vector2.RIGHT, true)
	Input.action_press("aim")
	await _frames(50)
	await _shot("7_aim_lock")
	Input.action_release("aim")
	await _frames(2)

	# 物品欄
	_main._toggle_inventory_panel()
	await _frames(3)
	await _shot("8_inventory")
	for app in ["status", "messages", "map"]:
		_main.set_phone_app(app)
		await _frames(3)
		await _shot("8_phone_" + app)
	_main.set_phone_app("items")
	_main._toggle_inventory_panel()

	# 感染症狀
	WorldState.health = 30.0
	WorldState.infection = 95.0
	await _frames(10)
	await _shot("9_infected")

	# 安全屋
	WorldState.health = 100.0
	WorldState.infection = 0.0
	await _enter("station_safe", "safe", false)
	_put_player(_tile(4, 3), Vector2.LEFT, true)
	_main._on_radio_used()
	await _frames(5)
	await _shot("10_safe_radio")
	_main.tune_radio(12435)
	_main.listen_radio()
	_main._refresh_radio()
	await _frames(3)
	await _shot("10b_radio_tuned")
	_main._close_radio()
	await _frames(10)
	await _shot("10c_safe_room")
	_main._toggle_storage_panel()
	await _frames(3)
	await _shot("11_storage")
	_main._toggle_storage_panel()
	_main._toggle_pause()
	await _frames(3)
	await _shot("12_pause")
	_main._toggle_pause()

	# 二樓宿舍：凍眠體和普通屍體混在一起
	_main._close_radio()
	await _enter("station_2f", "stairs", false)
	_put_player(_tile(8, 3), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("14_dorm_sleepers")
	_overlay.debug_enabled = true
	await _frames(3)
	await _shot("15_dorm_debug")
	_overlay.debug_enabled = false
	# 站長室
	WorldState.access_level = 1
	await _enter("station_2f_office", "office", false)
	_put_player(_tile(10, 3), Vector2.RIGHT, true)
	await _frames(20)
	await _shot("16_office")

	# 燃料庫（搬著燃料桶）、恢復電力後的地下層
	await _enter("fuel_depot", "depot", false)
	WorldState.carrying = "fuel"
	_put_player(_tile(28, 8), Vector2.LEFT, true)
	await _frames(30)
	await _shot("17_depot_carry")
	WorldState.set_flag("power_on")
	WorldState.carrying = ""
	await _enter("station_b1", "basement", false)
	_put_player(_tile(33, 13), Vector2.UP, true)
	await _frames(30)
	await _shot("18_b1_powered")

	# 機庫 Boss 戰
	await _enter("hangar", "hangar", false)
	_put_player(_tile(5, 7), Vector2.RIGHT, true)
	await _frames(20)
	var bear: Enemy = _main.enemies[0]
	NoiseBus.emit_noise(_tile(8, 7), 112.0, null)
	await _frames(20)
	await _shot("19_boss_windup")

	# 天線塔：庭院、通訊甲板、發訊介面
	bear.health = 0.0
	WorldState.set_flag("defeated:tundra_mother")
	await _enter("tower_yard", "snowcat", false)
	_put_player(_tile(10, 18), Vector2.RIGHT, true)
	await _frames(30)
	await _shot("20_tower_yard")
	await _enter("tower_top", "stairs", false)
	_put_player(_tile(12, 8), Vector2.RIGHT, true)
	await _frames(30)
	await _shot("21_tower_deck")
	_main.level.set_zone_heated("dish", true)
	_put_player(_tile(4, 2), Vector2.LEFT, true)
	await _frames(20)
	await _shot("22_uplink")
	_main._open_signal_panel()
	_main.select_signal(1)
	await _frames(3)
	await _shot("23_signal_choice")
	_main.select_signal(1)
	await _frames(3)
	await _shot("24_signal_reply")
	_main._close_signal_panel()

	# 鑽探井、最終 Boss、結局
	await _enter("drill_shaft", "shaft", false)
	_put_player(_tile(12, 6), Vector2.DOWN, true)
	await _frames(30)
	await _shot("25_drill_shaft")
	await _enter("shaft_bottom", "stairs", false)
	var well: BossWell = _main.enemies[0]
	_put_player(_tile(8, 11), Vector2.RIGHT, true)
	well._set_phase(BossWell.Phase.CHARGING)
	well._phase_time = 0.9
	well.spikes.append({"pos": _tile(20, 10), "t": 0.5})
	await _frames(4)
	await _shot("26_deep_well_charging")
	well._set_phase(BossWell.Phase.EXPOSED)
	await _frames(4)
	await _shot("27_deep_well_exposed")
	WorldState.set_flag("signal", "quarantine")
	_main._show_ending()
	await get_tree().create_timer(_main.ENDING_DELAY + 0.2).timeout
	await _shot("28_ending")
	get_tree().paused = false
	_main._ending_panel.visible = false

	# 環境互動：汽油彈的火、燒起來的油桶、滅火器的白霧；氣象小屋群；觸控介面
	WorldState.data.flags.erase("signal")
	await _enter("weather_huts", "huts", false)
	_put_player(_tile(19, 21), Vector2.UP, false)
	_player.cycle_light()
	_player.cycle_light()  # 打火機
	await _frames(20)
	await _shot("29_huts_lighter")
	_main.level.get_interactables().filter(func(i): return i is OilDrum)[0].interact(_player)
	var fire := Fire.new()
	fire.duration = 0.0
	_main.level.add_child(fire)
	fire.global_position = _tile(24, 21)
	var cloud := SmokeCloud.new()
	cloud.duration = 99.0
	_main.level.add_child(cloud)
	cloud.global_position = _tile(14, 22)
	await _frames(30)
	await _shot("30_fire_smoke")
	_main.touch_controls.set_enabled(true)
	_main.touch_controls.joystick.touch_down(0, Vector2(60, 200))
	_main.touch_controls.joystick.touch_move(Vector2(80, 190))
	await _frames(5)
	await _shot("31_touch_ui")
	_main.touch_controls.joystick.release()
	_main.touch_controls.set_enabled(false)

	# 擴張區域：北港（過場）、東翼、冰洞、圖鑑
	WorldState.cutscenes = true
	_main.load_area("north_harbor", "harbor", false)
	_off = Areas.area_offset("north_harbor")
	await _frames(40)
	await _shot("40_harbor_cutscene")
	_main.cutscene.next()
	await _frames(30)
	await _shot("40b_harbor_cutscene_pan")
	_main.cutscene.skip()
	await _frames(40)
	WorldState.cutscenes = false
	_put_player(_tile(30, 18), Vector2.UP, true)
	await _frames(40)
	await _shot("41_harbor")
	await _enter("station_east_wing", "east_wing", false)
	_put_player(_tile(12, 9), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("42_east_wing")
	await _enter("ice_caves", "caves", false)
	_put_player(_tile(8, 11), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("43_ice_caves")
	await _enter("north_harbor", "harbor", false)
	_put_player(_tile(44, 19), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("43b_harbor_to_caves")
	await _enter("station_2f", "stairs", false)
	_put_player(_tile(47, 4), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("43c_2f_to_east_wing")
	# 守門一號：廣場和基地是同一張無縫地圖
	await _enter("gate_one_yard", "gate_tunnel", false)
	_put_player(_tile(31, 36), Vector2.UP, true)
	await _frames(40)
	await _shot("45_gate_yard")
	_put_player(_tile(31, 30), Vector2.UP, true)
	await _frames(40)
	await _shot("46_gate_lobby")
	_put_player(_tile(30, 10), Vector2.LEFT, true)
	await _frames(40)
	await _shot("47_gate_corridor")
	_put_player(_tile(50, 16), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("48_gate_cells")
	_put_player(_tile(30, 25), Vector2.UP, true)
	await _frames(40)
	await _shot("49_gate_lab")
	for id in ["watcher", "crawler", "husk", "chorister", "rifle"]:
		WorldState.codex_see(id)
	_main.open_phone("codex")
	_main.codex_cursor = 4
	_main._refresh_phone()
	await _frames(3)
	await _shot("44_codex")
	_main.close_phone()

	await _aftersignal_shots()
	# 標題畫面
	_main.queue_free()
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(5)
	await _shot("13_title")
	get_tree().quit()


## AFTERSIGNAL 改版：霓虹燈、1962 年的記憶、訊號霧、2099 色調、選項、聲音提示
func _aftersignal_shots() -> void:
	await _enter("station_1f", "front", false)
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	_put_player(_tile(8, 3), Vector2.UP, true)
	await _frames(30)
	await _shot("50_neon_lobby")
	_put_player(_tile(26, 3), Vector2.UP, false)
	await _frames(20)
	await _shot("51_neon_lab")
	await _enter("station_2f", "stairs", false)
	_put_player(_tile(12, 10), Vector2.UP, false)
	await _frames(30)
	await _shot("52_rec_room_arcade")
	await _enter("station_b1", "basement", false)
	_put_player(_tile(19, 6), Vector2.UP, true)
	await _frames(20)
	await _shot("53_b1_reel")
	await _enter("lantern_1962", "start", false)
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	await _shot("54_lantern_1962")
	_put_player(_tile(30, 8), Vector2.UP, true)
	await _frames(30)
	await _shot("55_lantern_on_air")
	_put_player(_tile(34, 3), Vector2.RIGHT, true)
	await _frames(30)
	await _shot("56_lantern_reel")
	await _enter("station_east_wing", "east_wing", false)
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	_put_player(_tile(23, 4), Vector2.UP, true)
	await _frames(30)
	await _shot("57_signal_haze")
	_main.set_era("2099")
	await _frames(5)
	await _shot("58_era_2099")
	_main.set_era("")
	# 聲音提示：畫面外的敵人在走
	await _enter("station_1f", "front", false)
	var e0: Enemy = _main.enemies[0]
	e0.process_mode = Node.PROCESS_MODE_INHERIT
	_put_player(_tile(3, 5), Vector2.UP, true)
	e0.global_position = _tile(9, 16)
	e0.velocity = Vector2(30, 0)
	await _frames(6)
	await _shot("59_sound_cues")
	_main._toggle_pause()
	await _frames(3)
	await _shot("62_pause")
	_main._pause_panel.visible = false
	_main.options_panel.open()
	await _frames(3)
	await _shot("60_options")
	_main.options_panel.close()
	_main._toggle_pause()
	# 結局畫面（最後一句是 2099 年，畫面換成未來色調）
	await _main._show_ending()
	await _frames(5)
	await _shot("63_ending_2099")


## 座標都是目前區域自己的座標（合併進大地圖的區域要加位移，見 Areas.area_offset）
var _off := Vector2i.ZERO


func _enter(area_id: String, entry: String, fade := false) -> void:
	await _main.load_area(area_id, entry, fade)
	_off = Areas.area_offset(area_id)


func _tile(x: int, y: int) -> Vector2:
	return (Vector2(Vector2i(x, y) + _off) + Vector2(0.5, 0.5)) * Level.TILE


func _put_player(pos: Vector2, facing: Vector2, light: bool) -> void:
	_player.reset_to(pos)
	_player.facing = facing
	_player.flashlight_on = light
	_player._apply_flashlight()
	_main.get_node("Camera").snap_to_target()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("saved ", path)
