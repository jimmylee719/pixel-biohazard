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
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_overlay = _main.get_node("Overlay/DebugOverlay")
	var level: Level = _main.get_node("Level")
	var chimer: Enemy = _main.enemies[1]
	await _frames(30)

	_overlay.debug_enabled = false
	await _shot("1_start")

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
