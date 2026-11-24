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
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_overlay = _main.get_node("Overlay/DebugOverlay")
	await _frames(30)

	_overlay.debug_enabled = false
	await _shot("0_shore_start")
	_put_player(_tile(8, 9), Vector2.UP, true)
	await _frames(40)
	await _shot("0b_shore_door")
	_main._toggle_mission_panel()
	await _frames(3)
	await _shot("0c_missions")
	_main._toggle_mission_panel()

	await _main.load_area("station_1f", "cargo", false)
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
	_player.enter_hiding(locker)
	await _frames(20)
	await _shot("6_hiding")
	_player.exit_hiding()

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
	_main._toggle_inventory_panel()

	# 感染症狀
	WorldState.health = 30.0
	WorldState.infection = 95.0
	await _frames(10)
	await _shot("9_infected")

	# 安全屋
	WorldState.health = 100.0
	WorldState.infection = 0.0
	await _main.load_area("station_safe", "safe", false)
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
	await _main.load_area("station_2f", "stairs", false)
	_put_player(_tile(8, 3), Vector2.RIGHT, true)
	await _frames(40)
	await _shot("14_dorm_sleepers")
	_overlay.debug_enabled = true
	await _frames(3)
	await _shot("15_dorm_debug")
	_overlay.debug_enabled = false
	# 站長室
	WorldState.access_level = 1
	await _main.load_area("station_2f_office", "office", false)
	_put_player(_tile(10, 3), Vector2.RIGHT, true)
	await _frames(20)
	await _shot("16_office")

	# 標題畫面
	_main.queue_free()
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _frames(5)
	await _shot("13_title")
	get_tree().quit()


func _tile(x: int, y: int) -> Vector2:
	return (Vector2(x, y) + Vector2(0.5, 0.5)) * Level.TILE


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
