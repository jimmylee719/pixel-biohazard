## 截圖工具：Godot --path . res://tools/tests/capture.tscn -- <輸出資料夾>
extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var player: Player = main.get_node("Player")
	var enemy: Enemy = main.get_node("Enemy")
	var overlay: DebugOverlay = main.get_node("Overlay/DebugOverlay")
	await _frames(30)
	await _shot(out_dir + "/1_start.png")
	# 主角在房間入口，手電筒朝上，敵人在房間裡
	overlay.debug_enabled = false
	player.reset_to((Vector2(9, 12) + Vector2(0.5, 0.5)) * 16)
	player.facing = Vector2.UP
	main.get_node("Camera").snap_to_target()
	await _frames(90)
	await _shot(out_dir + "/2_room_nodebug.png")
	overlay.debug_enabled = true
	await _frames(5)
	await _shot(out_dir + "/3_room_debug.png")
	player.flashlight_on = false
	player._apply_flashlight()
	await _frames(5)
	await _shot(out_dir + "/4_room_dark.png")
	# 敵人被手電筒照到
	player.flashlight_on = true
	player._apply_flashlight()
	enemy.patrol_points = [Vector2(4.5, 6.5) * 16] as Array[Vector2]
	enemy._spawn = enemy.patrol_points[0]
	enemy.reset()
	player.reset_to(Vector2(9.5, 6.5) * 16)
	player.facing = Vector2.LEFT
	main.get_node("Camera").snap_to_target()
	await _frames(40)
	await _shot(out_dir + "/5_enemy_lit.png")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
