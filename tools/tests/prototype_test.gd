## 原型行為測試（不需要畫面）。
## 執行：Godot --headless --path . res://tools/tests/prototype_test.tscn
## 全部通過時結束代碼為 0，有失敗為 1；超過 TIMEOUT 秒也算失敗。
extends Node

const TIMEOUT := 180.0

var _failures := 0
var _main: Node
var _player: Player
var _watcher: Enemy
var _chimer: Enemy
var _level: Level
var _caught_count := 0


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(func():
		print("TIMEOUT")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	WorldState.new_game()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	await _frames(10)

	await _test_world_start()
	await _test_mission_panel()
	await _test_supply_crate()
	await _test_door_into_station()
	await _test_door_back_and_persistence()

	# 以下測試都在研究站一樓進行（從貨運入口進入）
	await _main.load_area("station_1f", "cargo", false)
	_bind_area()
	WorldState.bottles = 0
	WorldState.save_checkpoint("station_1f", "cargo")
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
	await _test_chimer_blind()
	await _test_chimer_hearing()
	await _test_chimer_feel()
	await _test_chimer_shriek()
	await _test_hide_unseen()
	await _test_hide_spotted()
	await _test_bottle()
	await _test_breaker()
	await _test_tape_and_intel()
	await _test_exit()

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ── 工具 ──

func _bind_area() -> void:
	_level = _main.level
	_watcher = _main.enemies[0]
	_chimer = _main.enemies[1] if _main.enemies.size() > 1 else null
	for e in _main.enemies:
		e.caught_player.connect(func(): _caught_count += 1)


## 按住方向鍵直到切換到指定區域（最多 2 秒），切換後立刻放開。
func _walk_until_area(action: String, area_id: String) -> void:
	Input.action_press(action)
	for i in 120:
		if _main.level.area_id == area_id:
			break
		await _frames(1)
	Input.action_release(action)
	while _main._transitioning:
		await _frames(1)
	await _frames(5)


func _spawn_pos() -> Vector2:
	return _level.get_entry_position("cargo")


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


## 只讓指定的敵人運作，其他敵人停住並放回出生點。
func _only(active: Enemy) -> void:
	for e in _main.enemies:
		if e != active:
			e.reset()
			e.process_mode = Node.PROCESS_MODE_DISABLED
	active.process_mode = Node.PROCESS_MODE_INHERIT


func _enable_all() -> void:
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_INHERIT


## 把敵人放在某處、朝某方向，並停在原地（巡邏點只有自己）。
func _freeze(enemy: Enemy, pos: Vector2, facing: Vector2) -> void:
	enemy.patrol_points = [pos] as Array[Vector2]
	enemy._spawn = pos
	enemy.reset()
	enemy.facing = facing


func _place_player(pos: Vector2, flashlight: bool, facing := Vector2.LEFT) -> void:
	_player.reset_to(pos)
	_player.input_enabled = true
	_player.flashlight_on = flashlight
	_player._apply_flashlight()
	_player.facing = facing


## 等上一輪「被抓到／過關」的延遲重來跑完，再把世界恢復原狀。
func _reset_world() -> void:
	while _main._resetting:
		await _frames(1)
	_main.reset_attempt()
	for i in _main.enemies.size():
		var e: Enemy = _main.enemies[i]
		e.patrol_points = _level.enemy_defs[i].points
		e._spawn = e.patrol_points[0]
		e.reset()
	_caught_count = 0


func _find_item(type: Variant, cell: Vector2i) -> Interactable:
	for item in _level.get_interactables():
		if is_instance_of(item, type) and item.global_position.distance_to(_tile(cell.x, cell.y)) < 1.0:
			return item
	return null


func _press(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


# ── 世界：區域、門、任務 ──

func _shore_quiet() -> void:
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED


func _test_world_start() -> void:
	print("[world / start]")
	_check(_main.level.area_id == "south_shore", "遊戲從南岸雪原開始")
	_check(_main.level.outdoor, "南岸是戶外")
	_check(_main.level.is_cold(_player.global_position), "戶外是冷的")
	_check(Missions.tracked_mission().get("id") == "enter_station", "第一個主線是進入研究站")
	_check(not Missions.is_available("lost_tape"), "進站前看不到站內的支線")


func _test_mission_panel() -> void:
	print("[world / mission panel]")
	var panel: Control = _main.get_node("HUD/MissionPanel")
	Input.action_press("map")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("map")
	await get_tree().process_frame
	_check(panel.visible, "按 map 打開任務清單")
	_check(get_tree().paused, "打開任務清單時遊戲暫停")
	Input.action_press("map")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("map")
	await get_tree().process_frame
	_check(not panel.visible and not get_tree().paused, "再按一次關閉並繼續")


func _test_supply_crate() -> void:
	print("[world / supply crate]")
	_shore_quiet()
	_level = _main.level
	var crate := _find_item(SupplyCrate, Vector2i(36, 21))
	_place_player(_tile(36, 20), false, Vector2.DOWN)
	await _frames(3)
	_check(_player.focus == crate, "站在補給箱旁可以打開")
	await _press("interact")
	_check(Missions.is_done("supply_drop"), "完成支線：補給箱")
	_check(_player.bottles == 3, "拿到空瓶＋任務獎勵（%d）" % _player.bottles)
	_check(not crate.enabled, "補給箱已經打開")


func _test_door_into_station() -> void:
	print("[world / door]")
	_shore_quiet()
	_place_player(_tile(6, 8), false, Vector2.UP)
	await _walk_until_area("move_up", "station_1f")
	_check(_main.level.area_id == "station_1f", "走進門會切換到研究站一樓（%s）" % _main.level.area_id)
	_check(_player.global_position.distance_to(_main.level.get_entry_position("front")) < 20.0, "站在對應的門口")
	_check(Missions.is_done("enter_station"), "完成主線：進入研究站")
	_check(Missions.tracked_mission().get("id") == "find_stairs", "下一個主線出現")
	_check(Missions.is_available("lost_tape"), "站內支線出現")
	_check(WorldState.checkpoint_area() == "station_1f", "進入區域時存檢查點")


func _test_door_back_and_persistence() -> void:
	print("[world / back & persistence]")
	_shore_quiet()
	var bottles := _player.bottles
	_player.facing = Vector2.LEFT
	await _walk_until_area("move_left", "south_shore")
	_check(_main.level.area_id == "south_shore", "從正門回到南岸（%s）" % _main.level.area_id)
	_check(_player.bottles == bottles, "空瓶數跟著主角走")
	_level = _main.level
	var crate := _find_item(SupplyCrate, Vector2i(36, 21))
	_check(crate != null and not crate.enabled, "已經打開的補給箱不會重生")


func _test_tape_and_intel() -> void:
	print("[tape / intel]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 2), Vector2.UP)
	var tape := _find_item(TapePickup, Vector2i(38, 11))
	_place_player(_tile(38, 10), false, Vector2.DOWN)
	await _frames(3)
	_check(_player.focus == tape, "可以撿錄音帶")
	await _press("interact")
	_check(Missions.is_done("lost_tape"), "完成支線：錄音帶")
	_check(WorldState.has_flag("intel:station_1f"), "取得一樓的巡邏情報")
	_check(_main.get_node("HUD/Message").visible, "顯示錄音內容")


# ── 基本（值班者）──

func _test_level() -> void:
	print("[level]")
	_check(_level.enemy_defs.size() == 2, "兩隻敵人")
	_check(_level.bounds.size == Vector2(704, 400), "地圖大小 704x400")
	var path := NavigationServer2D.map_get_path(
		_level.get_navigation_map(), _tile(10, 2), _spawn_pos(), true)
	_check(path.size() >= 2, "導航可以從交誼廳走到出生點")
	var lockers := _level.get_interactables().filter(func(i): return i is Locker)
	_check(lockers.size() == 5, "5 個置物櫃")
	_check(_watcher.display_name == "Watcher" and _chimer.display_name == "Chimer", "敵人種類正確")


func _test_patrol() -> void:
	print("[patrol]")
	await _reset_world()
	_place_player(_spawn_pos(), false)
	var a := _watcher.global_position
	var b := _chimer.global_position
	await _seconds(3.0)
	_check(_watcher.global_position.distance_to(a) > 30.0, "值班者沿路線移動")
	_check(_chimer.global_position.distance_to(b) > 20.0, "鳴骨者沿路線移動")
	_check(_watcher.state == Enemy.State.UNAWARE and _chimer.state == Enemy.State.UNAWARE, "主角在遠處時都未察覺")


func _test_player_movement() -> void:
	print("[player]")
	_only(_watcher)
	_freeze(_watcher, _tile(2, 2), Vector2.UP)
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
	_only(_watcher)
	_freeze(_watcher, _tile(4, 11), Vector2.DOWN)
	_place_player(_tile(9, 14), true, Vector2.UP)
	await _seconds(1.0)
	_check(not _watcher.sees_player, "牆壁擋住視線時看不到主角")


func _test_sight_to_alert() -> void:
	print("[vision -> suspicious -> alert]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(9, 6), true, Vector2.UP)
	await _frames(5)
	_check(_watcher.sees_player, "正前方的主角在視野內")
	await _seconds(0.5)
	_check(_watcher.state in [Enemy.State.SUSPICIOUS, Enemy.State.ALERT], "很快進入起疑（%s）" % _watcher.get_state_name())
	await _seconds(2.0)
	_check(_watcher.state == Enemy.State.ALERT, "察覺值滿後進入警戒（%s）" % _watcher.get_state_name())
	await _reset_world()


func _test_flashlight_hit() -> void:
	print("[flashlight]")
	_only(_watcher)
	_freeze(_watcher, _tile(10, 6), Vector2.RIGHT)
	_place_player(_tile(3, 6), true, Vector2.RIGHT)
	await _frames(10)
	_check(_watcher.state == Enemy.State.SUSPICIOUS, "背對時被手電筒照到會起疑（%s）" % _watcher.get_state_name())
	_freeze(_watcher, _tile(10, 6), Vector2.RIGHT)
	_place_player(_tile(3, 6), false, Vector2.RIGHT)
	await _seconds(1.0)
	_check(_watcher.state == Enemy.State.UNAWARE, "關燈時背後的主角不會被發現（%s）" % _watcher.get_state_name())


func _test_noise() -> void:
	print("[noise]")
	_only(_watcher)
	_freeze(_watcher, _tile(10, 6), Vector2.UP)
	_place_player(_tile(16, 10), false, Vector2.UP)
	await _frames(5)
	var source := _tile(10, 10)
	NoiseBus.emit_noise(source, 96.0, null)
	await _frames(2)
	_check(_watcher.state == Enemy.State.SUSPICIOUS, "聽到聲音會起疑（%s）" % _watcher.get_state_name())
	await _seconds(3.0)
	_check(_watcher.global_position.distance_to(source) < 12.0, "會走到聲音來源調查")


func _test_wall_muffles_noise() -> void:
	print("[noise / wall]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 10), Vector2.UP)
	_place_player(_spawn_pos(), false)
	await _frames(5)
	NoiseBus.emit_noise(_tile(9, 16), 96.0, null)
	await _frames(2)
	_check(_watcher.state == Enemy.State.UNAWARE, "隔著牆的遠處聲音聽不到")


func _test_lose_and_search() -> void:
	print("[alert -> search -> unaware]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(10, 6), true)
	for i in 240:
		if _watcher.state == Enemy.State.ALERT:
			break
		await _frames(1)
	_check(_watcher.state == Enemy.State.ALERT, "先進入警戒")
	_place_player(_spawn_pos(), false)
	await _seconds(3.0)
	_check(_watcher.state == Enemy.State.SEARCH, "追丟後進入搜索（%s）" % _watcher.get_state_name())
	await _seconds(9.0)
	_check(_watcher.state == Enemy.State.UNAWARE, "搜索結束回到未察覺（%s）" % _watcher.get_state_name())
	_check(_watcher._vigilance_timer > 0.0, "搜索後保持一段時間的警覺")


func _test_caught_reset() -> void:
	print("[caught]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(4, 6), true)
	await _seconds(0.5)
	_check(not _player.input_enabled, "被抓到時停止操作")
	await _seconds(2.0)
	_check(_player.global_position.distance_to(_spawn_pos()) < 2.0, "被抓到後主角回到出生點")
	_check(_player.input_enabled, "重生後恢復操作")


func _test_enemy_hidden_behind_wall() -> void:
	print("[visibility]")
	_only(_watcher)
	_freeze(_watcher, _tile(4, 6), Vector2.UP)
	_place_player(_tile(9, 15), true, Vector2.UP)
	await _seconds(0.5)
	_check(not _watcher.visible_to_player, "主角看不到牆後的敵人")
	_place_player(_tile(7, 6), true, Vector2.LEFT)
	await _seconds(0.3)
	_check(_watcher.visible_to_player, "手電筒照到的敵人看得到")


# ── 鳴骨者（聽覺型）──

func _test_chimer_blind() -> void:
	print("[chimer / blind]")
	_only(_chimer)
	_freeze(_chimer, _tile(32, 7), Vector2.LEFT)
	_place_player(_tile(26, 7), true, Vector2.RIGHT)  # 正前方、手電筒直照、不動
	await _seconds(1.5)
	_check(not _chimer.sees_player, "鳴骨者看不到主角")
	_check(_chimer.state == Enemy.State.UNAWARE, "手電筒照到也不會起疑（%s）" % _chimer.get_state_name())


func _test_chimer_hearing() -> void:
	print("[chimer / hearing]")
	_only(_chimer)
	_freeze(_chimer, _tile(32, 7), Vector2.LEFT)
	_place_player(_tile(24, 11), false)
	await _frames(5)
	# 走路聲半徑 2 格 = 32px，鳴骨者聽覺 x1.6 = 51px；聲音在 45px 外
	var src := _chimer.global_position + Vector2(-45, 0)
	NoiseBus.emit_noise(src, 32.0, null)
	await _frames(2)
	_check(_chimer.state == Enemy.State.SUSPICIOUS, "聽到 45px 外的腳步聲會起疑（%s）" % _chimer.get_state_name())
	NoiseBus.emit_noise(src, 32.0, null)
	await _frames(2)
	NoiseBus.emit_noise(src, 32.0, null)
	await _frames(2)
	_check(_chimer.state == Enemy.State.ALERT, "連續聽到幾次就進入警戒（%s）" % _chimer.get_state_name())
	await _reset_world()
	_only(_watcher)  # 值班者聽覺普通，同樣距離聽不到
	_freeze(_watcher, _tile(3, 6), Vector2.UP)
	await _frames(2)
	NoiseBus.emit_noise(_watcher.global_position + Vector2(45, 0), 32.0, null)
	await _frames(2)
	_check(_watcher.state == Enemy.State.UNAWARE, "值班者聽不到同樣距離的腳步聲")


func _test_chimer_feel() -> void:
	print("[chimer / feel]")
	_only(_chimer)
	_freeze(_chimer, _tile(32, 7), Vector2.LEFT)
	_place_player(_tile(31, 8), false, Vector2.RIGHT)
	_player.sneaking = true
	Input.action_press("move_right")
	await _seconds(0.6)
	Input.action_release("move_right")
	await _frames(5)
	_check(_chimer.state == Enemy.State.UNAWARE, "潛行從旁邊經過不會被察覺（%s）" % _chimer.get_state_name())
	_freeze(_chimer, _tile(32, 7), Vector2.LEFT)
	_place_player(_tile(31, 8), false, Vector2.RIGHT)
	Input.action_press("move_right")
	await _seconds(0.4)
	Input.action_release("move_right")
	_check(_chimer.state != Enemy.State.UNAWARE, "走路經過會被震動感應察覺（%s）" % _chimer.get_state_name())
	await _reset_world()


func _test_chimer_shriek() -> void:
	print("[chimer / shriek]")
	_enable_all()
	_freeze(_chimer, _tile(32, 7), Vector2.LEFT)
	_freeze(_watcher, _tile(37, 7), Vector2.UP)  # 同一排，中間沒有實驗桌擋住
	_place_player(_spawn_pos(), false)
	await _frames(2)
	_chimer._set_state(Enemy.State.ALERT)
	await _frames(2)
	_check(_watcher.state == Enemy.State.SUSPICIOUS, "鳴骨者尖鳴會讓附近的值班者過來查看（%s）" % _watcher.get_state_name())
	await _reset_world()


# ── 躲藏 ──

func _test_hide_unseen() -> void:
	print("[hide / unseen]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 6), Vector2.LEFT)  # 背對置物櫃
	var locker := _find_item(Locker, Vector2i(7, 1))
	_check(locker != null, "找到 (7,1) 的置物櫃")
	_place_player(_tile(7, 2), true, Vector2.UP)
	await _frames(3)
	_check(_player.focus == locker, "站在櫃子前面時可以互動")
	await _press("interact")
	_check(_player.is_hiding, "按 interact 躲進櫃子")
	_check(not _player.hide_spotted, "沒被看到")
	_check(not _player.flashlight_on, "躲藏時手電筒自動關閉")
	_watcher.facing = (locker.global_position - _watcher.global_position).normalized()  # 轉過來看櫃子
	await _seconds(1.5)
	_check(not _watcher.sees_player, "敵人看不到躲在櫃子裡的主角")
	_check(_caught_count == 0, "沒被抓")
	await _press("interact")
	_check(not _player.is_hiding, "再按一次離開櫃子")
	_check(_player.global_position.distance_to(_tile(7, 2)) < 2.0, "回到櫃子前面")
	_check(_player.flashlight_on, "離開後手電筒恢復")


func _test_hide_spotted() -> void:
	print("[hide / spotted]")
	_only(_watcher)
	_freeze(_watcher, _tile(7, 6), Vector2.UP)
	var locker := _find_item(Locker, Vector2i(7, 1))
	_place_player(_tile(7, 2), true, Vector2.UP)
	for i in 120:
		if _watcher.state != Enemy.State.UNAWARE:
			break
		await _frames(1)
	_check(_watcher.state != Enemy.State.UNAWARE, "值班者先注意到主角")
	_player.enter_hiding(locker)
	_check(_player.hide_spotted, "在敵人面前躲進櫃子會被看到")
	await _seconds(5.0)
	_check(_caught_count > 0, "被看到躲進去的話，敵人會把主角拖出來")
	await _seconds(2.0)
	await _reset_world()


# ── 物品、配電箱、出口 ──

func _test_bottle() -> void:
	print("[bottle]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 6), Vector2.UP)
	var pickup := _find_item(BottlePickup, Vector2i(14, 18))
	_place_player(_tile(14, 17), false, Vector2.DOWN)
	await _frames(3)
	await _press("interact")
	_check(_player.bottles == 1 and not pickup.enabled, "撿起空瓶")
	_place_player(_tile(10, 6), false, Vector2.LEFT)
	_player.bottles = 1
	await _frames(3)
	await _press("throw")
	_check(_player.bottles == 0, "丟出空瓶")
	await _seconds(0.7)
	_check(_watcher.state == Enemy.State.SUSPICIOUS, "空瓶落地的聲音引來敵人（%s）" % _watcher.get_state_name())
	var landing := _tile(10, 6) + Vector2.LEFT * (96.0 - 4.0)
	_check(_watcher._investigate_target.distance_to(landing) < 8.0, "敵人去查看落地點，而不是主角的位置")
	await _reset_world()
	_check(pickup.enabled and _player.bottles == 0, "重來後空瓶回到地上")


func _test_breaker() -> void:
	print("[breaker / temperature]")
	_enable_all()
	_freeze(_chimer, _tile(32, 7), Vector2.LEFT)
	_watcher.process_mode = Node.PROCESS_MODE_DISABLED
	var breaker := _find_item(Breaker, Vector2i(31, 2))
	_place_player(_tile(31, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == breaker, "站在配電箱前可以互動")
	await _press("interact")
	_check(not _level.is_zone_heated("lounge"), "關掉交誼廳的暖氣")
	_check(_level.is_cold(_tile(10, 6)), "交誼廳變冷")
	_check(not _level.is_cold(_tile(32, 7)), "實驗室還是暖的")
	_check(_chimer.state == Enemy.State.SUSPICIOUS, "扳開關的聲音引來附近的鳴骨者（%s）" % _chimer.get_state_name())

	# 冷的區域裡敵人移動變慢
	_only(_watcher)
	_watcher.patrol_points = [_tile(2, 6), _tile(17, 6)] as Array[Vector2]
	_watcher._spawn = _tile(2, 6)
	_watcher.reset()
	_place_player(_spawn_pos(), false)
	await _seconds(1.0)
	var cold_start := _watcher.global_position.x
	await _seconds(1.0)
	var cold_dist := _watcher.global_position.x - cold_start
	_check(_watcher.in_cold, "值班者知道自己在冷的區域")
	_level.set_zone_heated("lounge", true)
	_watcher.reset()
	await _seconds(1.0)
	var warm_start := _watcher.global_position.x
	await _seconds(1.0)
	var warm_dist := _watcher.global_position.x - warm_start
	_check(cold_dist < warm_dist * 0.7, "冷的時候比較慢（冷 %.0f px / 暖 %.0f px）" % [cold_dist, warm_dist])
	await _reset_world()
	_check(_level.is_zone_heated("lounge"), "重來後暖氣恢復")


func _test_exit() -> void:
	print("[exit]")
	_only(_watcher)
	_freeze(_watcher, _tile(17, 10), Vector2.DOWN)
	_place_player(_tile(2, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus is ExitPoint, "站在出口可以互動")
	await _press("interact")
	_check(not _player.input_enabled, "到達出口後結束這一輪")
	_check(Missions.is_done("find_stairs"), "完成主線：到達樓梯")
	await _seconds(2.0)
	await _seconds(1.0)
	_check(_main.level.area_id == "south_shore", "原型結束後重新開始（%s）" % _main.level.area_id)
