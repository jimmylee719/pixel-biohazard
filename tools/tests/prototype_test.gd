## Prototype 0 行為測試（不需要畫面）。
## 執行：Godot --headless --path . res://tools/tests/prototype_test.tscn
## 全部通過時結束代碼為 0，有失敗為 1；超過 TIMEOUT 秒也算失敗。
extends Node

const TIMEOUT := 90.0

var _failures := 0
var _main: Node
var _player: Player
var _enemy: Enemy
var _level: Level


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(func():
		print("TIMEOUT")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_enemy = _main.get_node("Enemy")
	_level = _main.get_node("Level")
	await _frames(10)

	await _test_level()
	await _test_patrol()
	await _test_player_movement()
	await _test_wall_blocks_vision()
	await _test_sight_to_alert()
	await _test_flashlight_hit()
	await _test_noise()
	await _test_wall_muffles_noise()
	await _test_lose_and_search()
	await _test_caught_reset()
	await _test_enemy_hidden_behind_wall()

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ── 工具 ──

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * 60.0))


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		_failures += 1


func _tile(x: int, y: int) -> Vector2:
	return (Vector2(x, y) + Vector2(0.5, 0.5)) * Level.TILE


## 把敵人放在某處、朝某方向，並停在原地（巡邏點只有自己）。
func _freeze_enemy(pos: Vector2, facing: Vector2) -> void:
	_enemy.patrol_points = [pos] as Array[Vector2]
	_enemy._spawn = pos
	_enemy.reset()
	_enemy.facing = facing


func _place_player(pos: Vector2, flashlight: bool, facing := Vector2.LEFT) -> void:
	_player.reset_to(pos)
	_player.flashlight_on = flashlight
	_player._apply_flashlight()
	_player.facing = facing


func _restore_enemy() -> void:
	_enemy.patrol_points = _level.patrol_points
	_enemy._spawn = _level.patrol_points[0]
	_enemy.reset()


# ── 測試 ──

func _test_level() -> void:
	print("[level]")
	_check(_level.patrol_points.size() == 6, "6 個巡邏點")
	_check(_level.bounds.size == Vector2(640, 400), "地圖大小 640x400")
	var path := NavigationServer2D.map_get_path(
		_level.get_navigation_map(), _level.patrol_points[0], _level.player_spawn, true)
	_check(path.size() >= 2, "導航可以從房間走到出生點（%d 個路徑點）" % path.size())


func _test_patrol() -> void:
	print("[patrol]")
	_place_player(_level.player_spawn, false)
	_restore_enemy()
	var start := _enemy.global_position
	await _seconds(3.0)
	_check(_enemy.global_position.distance_to(start) > 30.0, "敵人會沿路線移動")
	_check(_enemy.state == Enemy.State.UNAWARE, "主角在遠處時敵人保持未察覺")


func _test_player_movement() -> void:
	print("[player]")
	_freeze_enemy(_tile(2, 2), Vector2.UP)
	_place_player(_tile(20, 18), false)
	var start := _player.global_position
	Input.action_press("move_right")
	await _seconds(0.5)
	var walked := _player.global_position.x - start.x
	Input.action_release("move_right")
	_check(walked > 20.0, "InputMap move_right 可以移動主角（%.0f px）" % walked)
	_check(_player.gait == Player.Gait.WALK, "預設是走路")
	Input.action_press("move_right")
	Input.action_press("run")
	await _seconds(0.5)
	_check(_player.gait == Player.Gait.RUN, "按住 run 會奔跑")
	Input.action_release("run")
	Input.action_release("move_right")
	await _frames(10)


func _test_wall_blocks_vision() -> void:
	print("[vision / wall]")
	# 敵人在房間裡朝下看，主角在房間下方的牆後面（走廊外的牆裡不行，所以放在走廊旁邊被牆擋住的位置）
	_freeze_enemy(_tile(4, 11), Vector2.DOWN)
	_place_player(_tile(9, 14), true, Vector2.UP)  # 在垂直走廊裡，被房間下方的牆擋住
	await _seconds(1.0)
	_check(not _enemy.sees_player, "牆壁擋住視線時看不到主角")


func _test_sight_to_alert() -> void:
	print("[vision -> suspicious -> alert]")
	_freeze_enemy(_tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(9, 6), true, Vector2.UP)  # 正前方 6 格、開著手電筒
	await _frames(5)
	_check(_enemy.sees_player, "正前方的主角在視野內")
	await _seconds(0.5)
	_check(_enemy.state == Enemy.State.SUSPICIOUS or _enemy.state == Enemy.State.ALERT, "很快進入起疑（%s）" % _enemy.get_state_name())
	await _seconds(2.0)
	_check(_enemy.state == Enemy.State.ALERT, "察覺值滿後進入警戒（%s）" % _enemy.get_state_name())


func _test_flashlight_hit() -> void:
	print("[flashlight]")
	# 敵人背對主角，主角用手電筒照它
	_freeze_enemy(_tile(10, 6), Vector2.RIGHT)
	_place_player(_tile(3, 6), true, Vector2.RIGHT)
	await _frames(10)
	_check(_enemy.state == Enemy.State.SUSPICIOUS, "背對時被手電筒照到會起疑（%s）" % _enemy.get_state_name())
	# 關掉手電筒就不會
	_freeze_enemy(_tile(10, 6), Vector2.RIGHT)
	_place_player(_tile(3, 6), false, Vector2.RIGHT)
	await _seconds(1.0)
	_check(_enemy.state == Enemy.State.UNAWARE, "關燈時背後的主角不會被發現（%s）" % _enemy.get_state_name())


func _test_noise() -> void:
	print("[noise]")
	_freeze_enemy(_tile(10, 6), Vector2.UP)
	_place_player(_tile(16, 10), false, Vector2.UP)
	await _frames(5)
	# 聲音在敵人正下方 4 格，中間沒有障礙物
	var source := _tile(10, 10)
	NoiseBus.emit_noise(source, 96.0, null)
	await _frames(2)
	_check(_enemy.state == Enemy.State.SUSPICIOUS, "聽到聲音會起疑（%s）" % _enemy.get_state_name())
	await _seconds(3.0)
	_check(_enemy.global_position.distance_to(source) < 12.0, "會走到聲音來源調查（距離 %.0f px）" % _enemy.global_position.distance_to(source))


func _test_wall_muffles_noise() -> void:
	print("[noise / wall]")
	# 敵人在房間，聲音在垂直走廊裡隔著牆，距離超過半徑的一半
	_freeze_enemy(_tile(3, 10), Vector2.UP)
	_place_player(_level.player_spawn, false)
	await _frames(5)
	NoiseBus.emit_noise(_tile(9, 16), 96.0, null)  # 直線距離約 105px > 48px
	await _frames(2)
	_check(_enemy.state == Enemy.State.UNAWARE, "隔著牆的遠處聲音聽不到")


func _test_lose_and_search() -> void:
	print("[alert -> search -> unaware]")
	_freeze_enemy(_tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(10, 6), true)
	for i in 240:  # 最多等 4 秒，一進入警戒就讓主角消失，避免被抓到
		if _enemy.state == Enemy.State.ALERT:
			break
		await _frames(1)
	_check(_enemy.state == Enemy.State.ALERT, "先進入警戒")
	# 主角瞬間移到遠處（模擬甩掉）
	_place_player(_level.player_spawn, false)
	await _seconds(3.0)
	_check(_enemy.state == Enemy.State.SEARCH, "追丟後進入搜索（%s）" % _enemy.get_state_name())
	await _seconds(9.0)
	_check(_enemy.state == Enemy.State.UNAWARE, "搜索結束回到未察覺（%s）" % _enemy.get_state_name())
	_check(_enemy._vigilance_timer > 0.0, "搜索後保持一段時間的警覺")


func _test_caught_reset() -> void:
	print("[caught]")
	_freeze_enemy(_tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(4, 6), true)
	await _seconds(0.5)
	_check(not _player.input_enabled, "被抓到時停止操作")
	await _seconds(2.0)
	_check(_player.global_position.distance_to(_level.player_spawn) < 2.0, "被抓到後主角回到出生點")
	_check(_player.input_enabled, "重生後恢復操作")


func _test_enemy_hidden_behind_wall() -> void:
	print("[visibility]")
	_freeze_enemy(_tile(4, 6), Vector2.UP)
	_place_player(_tile(9, 15), true, Vector2.UP)  # 主角在走廊裡，敵人在房間另一側
	await _seconds(0.5)
	_check(not _enemy.visible_to_player, "主角看不到牆後的敵人")
	_place_player(_tile(7, 6), true, Vector2.LEFT)
	await _seconds(0.3)
	_check(_enemy.visible_to_player, "手電筒照到的敵人看得到")
