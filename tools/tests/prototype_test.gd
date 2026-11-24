## 原型行為測試（不需要畫面）。
## 執行：Godot --headless --path . res://tools/tests/prototype_test.tscn
## 全部通過時結束代碼為 0，有失敗為 1；超過 TIMEOUT 秒也算失敗。
extends Node

const TIMEOUT := 300.0

var _failures := 0
var _main: Node
var _player: Player
var _watcher: Enemy
var _chimer: Enemy
var _level: Level
var _hit_count := 0


func _ready() -> void:
	get_tree().create_timer(TIMEOUT).timeout.connect(func():
		print("TIMEOUT")
		get_tree().quit(1))
	_run.call_deferred()


func _run() -> void:
	WorldState.save_path = "user://test_save.dat"  # 不要動到真正的存檔
	WorldState.delete_save()
	WorldState.new_game()
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_player.hurt.connect(func(_d): _hit_count += 1)
	await _frames(10)

	await _test_world_start()
	await _test_mission_panel()
	await _test_supply_crate()
	await _test_door_into_station()
	await _test_door_back_and_persistence()

	# 以下測試都在研究站一樓進行（從貨運入口進入）
	await _main.load_area("station_1f", "cargo", false)
	_bind_area()
	await _test_safe_room()
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
	await _test_pickups()
	await _test_aim_and_shoot()
	await _test_reload()
	await _test_corpse_persists()
	await _test_melee()
	await _test_hidden_cache_and_shotgun()
	await _test_enemy_attack_and_death()
	await _test_items_and_infection()
	await _test_inventory_slots()
	await _test_exit()
	await _test_title()
	await _test_save_migration()

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
	_hit_count = 0


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
	_check(Missions.tracked_mission().get("id") == "find_shelter", "下一個主線出現：找安全的地方")
	_check(not Missions.is_available("lost_tape"), "站內支線要用無線電才會出現")
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
	var cache := _find_item(ItemPickup, Vector2i(37, 9))
	_check(cache != null and not cache.enabled and not cache.visible, "還沒聽到作業日誌前，東岸的彈藥藏匿處不存在")


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
	_check(WorldState.is_freq_known(12435), "錄音帶上的頻率記進備忘錄")
	var note := _find_item(ReadableNote, Vector2i(34, 2))
	_place_player(_tile(34, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == note, "可以讀白板")
	await _press("interact")
	_check(WorldState.is_freq_known(12780), "白板上的作業頻率 127.80 記進備忘錄")


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
	await _seconds(1.0)
	_check(_hit_count > 0, "貼在敵人面前會被攻擊")
	await _reset_world()


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
	_check(_hit_count == 0, "沒被攻擊")
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
	_check(_hit_count > 0, "被看到躲進去的話，敵人會把主角拖出來打")
	_check(not _player.is_hiding, "主角被拖出櫃子")
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


# ── 戰鬥與資源 ──

func _revive_watcher() -> void:
	WorldState.data.flags.erase("dead:station_1f:0")
	_watcher.reset()


func _test_pickups() -> void:
	print("[combat / pickups]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 10), Vector2.DOWN)
	var pistol := _find_item(ItemPickup, Vector2i(24, 3))
	_place_player(_tile(25, 3), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus == pistol, "可以撿手槍")
	await _press("interact")
	_check(_player.combat.has_pistol(), "取得手槍")
	_check(WorldState.pistol_loaded == 6, "手槍裡有 6 發")
	_place_player(_tile(17, 2), false, Vector2.UP)
	await _frames(3)
	await _press("interact")
	_check(WorldState.inv_count("ammo") == 6, "撿到 6 發子彈")


func _test_aim_and_shoot() -> void:
	print("[combat / aim & shoot]")
	_only(_watcher)
	_freeze(_watcher, _tile(10, 6), Vector2.UP)
	_place_player(_tile(4, 6), false, Vector2.RIGHT)
	Input.action_press("aim")
	await _seconds(0.9)
	_check(_player.combat.aiming, "按住 aim 舉槍")
	_check(_player.combat.target == _watcher, "自動鎖定面前的敵人")
	_check(_player.combat.aim_focus >= 1.0, "等一下準心完全收束")
	var before := _player.global_position
	Input.action_press("move_right")
	await _frames(10)
	Input.action_release("move_right")
	_check(_player.global_position.distance_to(before) < 1.0, "舉槍時不能移動")
	await _press("fire")
	_check(WorldState.pistol_loaded == 5, "開一槍用掉一發")
	_check(is_equal_approx(_watcher.health, 80.0 - 55.0), "準心收束時傷害最高（剩 %.0f）" % _watcher.health)
	_check(_watcher.state == Enemy.State.ALERT, "被打的敵人立刻警戒")
	await _seconds(0.4)
	await _press("fire")
	_check(_watcher.is_dead, "第二槍打倒值班者")
	_check(WorldState.is_enemy_dead("station_1f:0"), "死亡記錄在世界狀態")
	Input.action_release("aim")
	await _frames(5)
	_check(not _player.combat.aiming, "放開 aim 收槍")


func _test_reload() -> void:
	print("[combat / reload]")
	var loaded := WorldState.pistol_loaded
	var ammo := WorldState.inv_count("ammo")
	await _press("reload")
	_check(_player.combat.reloading, "按 reload 開始裝填")
	await _seconds(1.5)
	var moved := mini(8 - loaded, ammo)
	_check(WorldState.pistol_loaded == loaded + moved, "彈匣裝滿（%d）" % WorldState.pistol_loaded)
	_check(WorldState.inv_count("ammo") == ammo - moved, "子彈從物品欄扣掉")


func _test_corpse_persists() -> void:
	print("[combat / corpse persists]")
	var death_pos := _watcher.global_position
	WorldState.save_checkpoint("station_1f", "cargo")
	await _main.load_area("station_1f", "cargo", false)
	_bind_area()
	await _frames(5)
	_check(_watcher.is_dead, "重新進入區域，打倒的敵人還是死的")
	_check(_watcher.global_position.distance_to(death_pos) < 1.0, "屍體留在倒下的位置")
	_check(not _watcher.is_in_group("enemies"), "屍體不會被鎖定")
	_revive_watcher()


func _test_melee() -> void:
	print("[combat / melee & takedown]")
	_only(_watcher)
	_freeze(_watcher, _tile(8, 6), Vector2.RIGHT)  # 背對主角
	_place_player(_tile(7, 6), false, Vector2.RIGHT)
	_player.sneaking = true
	await _frames(3)
	_check(_watcher.can_be_taken_down_by(_player), "從背後靠近沒察覺的敵人可以偷襲")
	await _press("fire")
	_check(_watcher.is_dead, "背後偷襲一刀解決")
	_revive_watcher()
	_freeze(_watcher, _tile(8, 6), Vector2.LEFT)  # 正面
	_place_player(_tile(7, 6), false, Vector2.RIGHT)
	await _seconds(0.6)  # 等近戰冷卻
	_watcher.facing = Vector2.LEFT  # 面對主角（張望會轉頭，出手前再轉回來）
	await _press("fire")
	_check(not _watcher.is_dead and is_equal_approx(_watcher.health, 60.0), "正面近戰只造成小傷害（剩 %.0f）" % _watcher.health)
	_check(_watcher.state == Enemy.State.ALERT, "被砍的敵人立刻警戒")
	await _reset_world()
	_revive_watcher()


func _test_enemy_attack_and_death() -> void:
	print("[combat / enemy attack & death]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 6), Vector2.RIGHT)
	_place_player(_tile(5, 6), true)
	for i in 180:
		if _hit_count > 0:
			break
		await _frames(1)
	_check(_hit_count > 0, "警戒的敵人靠近會出手")
	_check(_player.health < 100.0, "被打到扣生命值（%.0f）" % _player.health)
	_check(_player.infection > 0.0, "被打到增加感染值（%.0f）" % _player.infection)
	WorldState.health = 5.0
	for i in 180:
		if _player.is_dead:
			break
		await _frames(1)
	_check(_player.is_dead, "生命值歸零就死亡")
	_check(not _player.input_enabled, "死亡時停止操作")
	await _seconds(2.0)
	_check(_player.global_position.distance_to(_spawn_pos()) < 2.0, "死亡後回到檢查點")
	_check(_player.health == 100.0 and _player.infection == 0.0, "生命值、感染值回到檢查點的狀態")
	_check(_player.input_enabled and not _player.is_dead, "重生後恢復操作")


func _test_items_and_infection() -> void:
	print("[resources / items & infection]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 10), Vector2.DOWN)
	_place_player(_tile(16, 10), false)
	WorldState.inv_add("med", 1)
	WorldState.inv_add("antibiotic", 1)
	WorldState.health = 40.0
	WorldState.infection = 80.0
	_check(_player.get_condition() == "Caution", "生命值用狀態文字表示")
	_check(_player.use_item("med"), "使用急救包")
	_check(is_equal_approx(_player.health, 85.0), "回復生命值（%.0f）" % _player.health)
	_check(_player.use_item("antibiotic"), "使用抗菌藥劑")
	_check(is_equal_approx(_player.infection, 20.0), "降低感染值（%.0f）" % _player.infection)
	_check(not _player.use_item("antibiotic"), "沒有藥劑時不能使用")
	WorldState.infection = 100.0
	WorldState.health = 50.0
	await _seconds(1.0)
	_check(_player.health < 50.0, "感染值滿了生命值會流失（%.1f）" % _player.health)
	_check(_player.get_speed_mult() < 1.0, "感染發作時走路變慢")
	await _reset_world()


func _test_inventory_slots() -> void:
	print("[resources / inventory]")
	_only(_watcher)
	var saved: Array = WorldState.data.inventory.duplicate(true)
	WorldState.data.inventory = WorldState._empty_inventory(6)
	_check(WorldState.inv_add("ammo", 30) == 30, "彈藥可以分成兩格疊放")
	_check(WorldState.inventory()[0].count == 24 and WorldState.inventory()[1].count == 6, "一格最多 24 發")
	for id in ["med", "antibiotic", "pistol", "bottle"]:
		WorldState.inv_add(id, 1)
	_check(WorldState.inv_space_for("med") == 1, "急救包那格還能再放 1 個")
	WorldState.inv_add("med", 1)
	_check(WorldState.inv_space_for("med") == 0, "滿了就放不下")
	var panel: Control = _main.get_node("HUD/InventoryPanel")
	Input.action_press("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("inventory")
	await get_tree().process_frame
	_check(panel.visible and get_tree().paused, "按 inventory 打開物品欄並暫停")
	Input.action_press("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("inventory")
	await get_tree().process_frame
	_check(not panel.visible and not get_tree().paused, "再按一次關閉")
	WorldState.data.inventory = saved


# ── 安全屋、存檔、儲物箱、暫停、標題 ──

func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _test_radio_tuning() -> void:
	print("[radio / tuning]")
	var panel: Control = _main.get_node("HUD/RadioPanel")
	_check(panel.visible and get_tree().paused, "用無線電後打開調頻介面並暫停")
	_check(WorldState.known_freqs() == ([12150] as Array[int]), "一開始只知道航空緊急頻率 121.50")
	_main.tune_radio(12150)
	await _tap("interact")
	_check(WorldState.has_flag("freq_heard:guard"), "收聽 121.50 聽到墜機信標")
	# 用方向鍵調到 124.35：上 = +1.00、右 = +0.05
	await _tap("move_up")
	await _tap("move_up")
	for i in 17:
		await _tap("move_right")
	_check(_main._radio_freq == 12435, "方向鍵調頻（%s）" % Frequencies.format(_main._radio_freq))
	_check(not WorldState.has_flag("reveal:shotgun_1f"), "還沒收聽前，散彈槍藏匿處不存在")
	await _tap("interact")
	_check(WorldState.has_flag("reveal:shotgun_1f"), "收聽 Mendez 的錄音，揭露散彈槍藏匿處")
	_check(WorldState.is_freq_known(12435), "聽到的頻率記進備忘錄")
	# 沒有任何線索的頻率：靠訊號強度找
	_main.tune_radio(12630)
	_check(Frequencies.signal_strength(12630) > 0.5, "接近隱藏電台時訊號變強")
	_check(Frequencies.signal_strength(12900) == 0.0, "空白頻段沒有訊號")
	_main.listen_radio()
	_check(_main._radio_transcript[0].begins_with("Something"), "訊號強但沒對準：提示再微調")
	_main.tune_radio(12605)
	_main.listen_radio()
	_check(WorldState.has_flag("lore:retrieval"), "找到隱藏的頻率 126.05")
	_main.tune_radio(12900)
	_main.listen_radio()
	_check(_main._radio_transcript == (["Only static."] as Array[String]), "沒有電台只有雜訊")
	_main.tune_radio(12150)
	await _tap("switch_target")
	_check(_main._radio_freq == 12435, "備忘錄可以快速跳到下一個知道的頻率")
	await _tap("inventory")
	_check(not panel.visible and not get_tree().paused, "關閉無線電")


func _test_hidden_cache_and_shotgun() -> void:
	print("[radio reward / shotgun]")
	_only(_watcher)
	_freeze(_watcher, _tile(3, 10), Vector2.DOWN)
	var gun := _find_item(ItemPickup, Vector2i(38, 19))
	var shells := _find_item(ItemPickup, Vector2i(37, 19))
	_check(gun != null and gun.enabled and gun.visible, "聽過頻率後，走廊東端出現散彈槍")
	_place_player(_tile(38, 18), false, Vector2.DOWN)
	await _frames(3)
	await _press("interact")
	_place_player(_tile(37, 18), false, Vector2.DOWN)
	await _frames(3)
	await _press("interact")
	_check(WorldState.inv_count("shotgun") == 1 and WorldState.get_loaded("shotgun") == 2, "撿到散彈槍（裡面 2 發）")
	_check(WorldState.inv_count("shells") == 3, "撿到 3 發散彈")
	_check(_player.combat.current_weapon() == "pistol", "撿到後還是拿著手槍")
	_check(_player.use_item("shotgun") and _player.combat.current_weapon() == "shotgun", "在物品欄使用散彈槍 = 裝備")
	# 近距離 vs 遠距離
	_freeze(_watcher, _tile(9, 6), Vector2.UP)
	_place_player(_tile(7, 6), false, Vector2.RIGHT)
	Input.action_press("aim")
	await _seconds(0.9)
	await _press("fire")
	Input.action_release("aim")
	_check(_watcher.is_dead, "散彈槍近距離一槍打倒值班者")
	_revive_watcher()
	_freeze(_watcher, _tile(11, 6), Vector2.UP)
	_place_player(_tile(6, 6), false, Vector2.RIGHT)
	await _seconds(1.0)
	Input.action_press("aim")
	await _seconds(0.9)
	await _press("fire")
	Input.action_release("aim")
	_check(not _watcher.is_dead and _watcher.health > 0.0, "距離遠時散彈槍傷害下降（剩 %.0f）" % _watcher.health)
	await _seconds(1.0)
	_check(WorldState.get_loaded("shotgun") == 0, "兩發用完")
	_player.use_item("pistol")
	_check(_player.combat.current_weapon() == "pistol", "換回手槍")
	await _reset_world()
	_revive_watcher()


func _test_save_migration() -> void:
	print("[save / migration]")
	var old := {"area": "station_safe", "entry": "radio", "pistol_loaded": 5, "flags": {}}
	var migrated := WorldState._migrate(old)
	_check(migrated.loaded.pistol == 5, "舊存檔的手槍子彈轉到新格式")
	_check(migrated.has("inventory") and migrated.has("storage") and migrated.equipped == "pistol", "缺少的欄位補上預設值")


func _test_safe_room() -> void:
	print("[safe room / door]")
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	_place_player(_tile(14, 18), false, Vector2.DOWN)
	await _walk_until_area("move_down", "station_safe")
	_check(_main.level.area_id == "station_safe", "走廊的門通往無菌隔離室（%s）" % _main.level.area_id)
	_check(_main.level.safe, "這是安全屋")
	_check(_main.enemies.is_empty(), "安全屋裡沒有敵人")
	_check(Missions.step_index("find_shelter") == 1, "主線「找安全的地方」進行到用無線電")
	_check(not Missions.is_available("lost_tape"), "還沒用無線電前，支線還沒出現")

	print("[safe room / radio & save]")
	_level = _main.level
	var radio := _find_item(RadioConsole, Vector2i(3, 2))
	_place_player(_tile(3, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == radio, "可以使用無線電")
	await _press("interact")
	_check(Missions.is_done("find_shelter"), "完成主線：用無線電")
	_check(Missions.is_available("lost_tape") and Missions.is_available("cold_lounge"), "無線電收到兩個支線委託")
	_check(Missions.tracked_mission().get("id") == "find_stairs", "下一個主線出現")
	_check(WorldState.has_save(), "存檔寫進硬碟")
	_check(WorldState.checkpoint_entry() == "radio", "檢查點改成無線電旁邊")
	_check("KOVAC" in _main._radio_transcript[0], "第一次使用時 Kovac 聯絡主角")
	await _test_radio_tuning()

	print("[safe room / storage]")
	WorldState.inv_add("med", 1)
	var box := _find_item(StorageBox, Vector2i(15, 2))
	_place_player(_tile(15, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == box, "可以打開儲物箱")
	await _press("interact")
	var panel: Control = _main.get_node("HUD/StoragePanel")
	_check(panel.visible and get_tree().paused, "儲物箱介面打開並暫停")
	var first: Dictionary = WorldState.inventory()[0].duplicate()
	Input.action_press("ui_accept")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("ui_accept")
	await get_tree().process_frame
	_check(WorldState.inventory()[0].is_empty() and WorldState.storage().get(first.id, 0) >= first.count,
		"確認鍵把第一格整格放進儲物箱（%s）" % first.get("id"))
	_check(WorldState.retrieve(first.id) == first.count, "可以再拿出來")
	Input.action_press("inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("inventory")
	await get_tree().process_frame
	_check(not panel.visible and not get_tree().paused, "關閉儲物箱")

	print("[save / load]")
	WorldState.store_slot(0)
	_player._invulnerable = 0.0
	WorldState.save_checkpoint("station_safe", "radio")
	WorldState.save_to_disk()
	var stored := WorldState.storage().duplicate()
	WorldState.health = 10.0
	WorldState.data.storage = {}
	_check(WorldState.load_from_disk(), "讀取存檔")
	_check(WorldState.health == 100.0, "生命值回到存檔時的狀態")
	_check(WorldState.storage() == stored, "儲物箱內容也有存")
	_check(Missions.is_done("find_shelter"), "任務進度也有存")

	print("[pause]")
	var pause: Control = _main.get_node("HUD/PausePanel")
	Input.action_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("pause")
	await get_tree().process_frame
	_check(pause.visible and get_tree().paused, "按 pause 打開暫停選單")
	Input.action_press("pause")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("pause")
	await get_tree().process_frame
	_check(not pause.visible and not get_tree().paused, "再按一次繼續")

	print("[safe room / back]")
	_place_player(_tile(9, 2), false, Vector2.UP)
	await _walk_until_area("move_up", "station_1f")
	_check(_main.level.area_id == "station_1f", "從安全屋回到走廊")
	_check(_player.global_position.distance_to(_main.level.get_entry_position("safe")) < 20.0, "站在安全屋門口")


func _test_title() -> void:
	print("[title]")
	var title: Control = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	_check(not title.get_node("Center/Box/Continue").disabled, "有存檔時可以「繼續」")
	title.queue_free()
	WorldState.delete_save()
	title = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	_check(title.get_node("Center/Box/Continue").disabled, "沒有存檔時「繼續」不能按")
	title.queue_free()


func _test_exit() -> void:
	print("[stairs]")
	_only(_watcher)
	_freeze(_watcher, _tile(17, 10), Vector2.DOWN)
	_place_player(_tile(2, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus is ExitPoint, "站在樓梯可以互動")
	await _press("interact")
	while _main._transitioning:
		await _frames(1)
	await _frames(5)
	_check(_main.level.area_id == "station_2f", "樓梯通往二樓（%s）" % _main.level.area_id)
	_check(Missions.is_done("find_stairs"), "完成主線：到達樓上")
	_check(Missions.tracked_mission().get("id") == "director_records", "下一個主線：站長的紀錄")
	_check(_main.level.is_cold(_player.global_position), "二樓暖氣壞了，是冷的")
	_bind_upper()
	await _test_sleepers()
	await _test_keycard_and_office()


var _sleepers: Array[Enemy] = []


func _bind_upper() -> void:
	_level = _main.level
	_watcher = _main.enemies[0]
	_sleepers.clear()
	for e in _main.enemies:
		if e.display_name == "Sleeper":
			_sleepers.append(e)


func _test_sleepers() -> void:
	print("[sleeper]")
	_check(_sleepers.size() == 4, "二樓有 4 隻凍眠體")
	var s: Enemy = _sleepers[0]  # 宿舍 A (12,4)
	_check(s.is_dormant and s.can_be_taken_down_by(_player), "凍眠體一開始躺著（可以偷襲）")
	var decoys := _level.get_children().filter(func(n): return n is CorpseDecor)
	_check(decoys.size() == 5, "地上還有 5 具普通屍體")
	_only(s)
	# 自動鎖定不會鎖到睡著的凍眠體
	_place_player(_tile(9, 4), false, Vector2.RIGHT)
	WorldState.inv_add("pistol", 1)
	Input.action_press("aim")
	await _seconds(0.3)
	_check(_player.combat.target == null, "舉槍不會鎖定睡著的凍眠體")
	Input.action_release("aim")
	await _frames(3)
	# 潛行經過不會醒
	_player.sneaking = true
	_place_player(_tile(10, 3), false, Vector2.RIGHT)
	_player.sneaking = true
	Input.action_press("move_right")
	await _seconds(0.6)
	Input.action_release("move_right")
	await _frames(5)
	_check(s.is_dormant, "潛行經過不會吵醒凍眠體")
	# 走路經過會醒
	s.reset()
	_place_player(_tile(10, 3), false, Vector2.RIGHT)
	Input.action_press("move_right")
	await _seconds(0.5)
	Input.action_release("move_right")
	_check(not s.is_dormant and s.state == Enemy.State.ALERT, "走路經過會吵醒凍眠體並直接警戒")
	await _await_reset()
	# 聲音會吵醒
	s.reset()
	_place_player(_tile(3, 10), false)
	NoiseBus.emit_noise(s.global_position + Vector2(20, 0), 32.0, null)
	await _frames(2)
	_check(not s.is_dormant, "附近的聲音會吵醒凍眠體")
	# 區域變暖會醒
	s.reset()
	_level.set_zone_heated("upper", true)
	await _frames(3)
	_check(not s.is_dormant, "暖氣恢復時凍眠體甦醒")
	_level.set_zone_heated("upper", false)
	# 偷襲：潛行靠近一刀解決
	s.reset()
	_place_player(_tile(11, 4), false, Vector2.RIGHT)
	_player.sneaking = true
	await _seconds(0.6)
	await _press("fire")
	_check(s.is_dead, "潛行靠近睡著的凍眠體可以一刀解決")
	await _reset_world()
	_enable_all()


## 等被攻擊之類的延遲重來跑完
func _await_reset() -> void:
	await _seconds(0.2)
	while _main._resetting:
		await _frames(1)


func _test_keycard_and_office() -> void:
	print("[keycard / office]")
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	_check(WorldState.access_level == 0, "一開始沒有權限卡")
	# 走到辦公室門口：鎖著
	_place_player(_tile(37, 10), false, Vector2.RIGHT)
	Input.action_press("move_right")
	await _seconds(0.6)
	Input.action_release("move_right")
	await _frames(5)
	_check(_main.level.area_id == "station_2f", "沒有權限卡時辦公室的門打不開")
	_check(_main.get_node("HUD/Message").visible and "Locked" in _main.get_node("HUD/Message").text, "顯示需要權限卡")
	# 拿權限卡
	var card := _find_item(AccessCard, Vector2i(27, 2))
	_place_player(_tile(27, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == card, "可以拿權限卡")
	await _press("interact")
	_check(WorldState.access_level == 1, "權限等級 1")
	_check(Missions.step_index("director_records") == 1, "主線進行到使用終端機")
	_check(WorldState.inventory().all(func(s): return s.get("id", "") != "keycard"), "權限卡不佔物品欄")
	# 進辦公室
	_place_player(_tile(37, 10), false, Vector2.RIGHT)
	await _walk_until_area("move_right", "station_2f_office")
	_check(_main.level.area_id == "station_2f_office", "有權限卡就能進站長室")
	_level = _main.level
	var note := _find_item(ReadableNote, Vector2i(3, 2))
	_place_player(_tile(3, 3), false, Vector2.UP)
	await _frames(3)
	await _press("interact")
	_check(WorldState.is_freq_known(12570), "站長的便條：記下 125.70")
	var terminal := _find_item(Terminal, Vector2i(12, 2))
	_place_player(_tile(12, 3), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == terminal, "可以使用終端機")
	await _press("interact")
	_check(Missions.is_done("director_records"), "完成主線：站長的紀錄")
	_check(WorldState.access_level == 2, "權限卡升到等級 2")
	_check(_player.input_enabled, "讀完紀錄後可以繼續（主線：恢復電力）")
	_check(Missions.tracked_mission().get("id") == "restore_power", "下一個主線：恢復電力")
	await _test_power()


func _quiet() -> void:
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED


func _test_power() -> void:
	print("[power / basement door]")
	await _main.load_area("station_1f", "stairs", false)
	_quiet()
	_place_player(_tile(30, 2), false, Vector2.UP)
	await _walk_until_area("move_up", "station_b1")
	_check(_main.level.area_id == "station_b1", "權限卡等級 2 可以進地下層")
	_quiet()
	_level = _main.level
	_check(not _main.level.is_lit(), "停電中：地下層沒有燈")
	_check(_main.level.is_cold(_tile(10, 10)) and _main.level.is_cold(_tile(30, 3)), "停電中：地下層是冷的")
	var gen := _find_item(Generator, Vector2i(34, 10))
	_place_player(_tile(35, 10), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus == gen, "可以檢查發電機")
	await _press("interact")
	_check(not WorldState.power_on and Missions.step_index("restore_power") == 0, "沒有燃料時發電機不會啟動")

	print("[power / fuel depot]")
	await _main.load_area("fuel_depot", "depot", false)
	_quiet()
	_level = _main.level
	_check(_main.level.outdoor, "燃料庫在戶外")
	var can := _find_item(FuelCan, Vector2i(35, 5))
	_place_player(_tile(34, 5), false, Vector2.RIGHT)
	await _frames(3)
	_check(_player.focus == can, "可以搬燃料桶")
	await _press("interact")
	_check(_player.is_carrying() and Missions.step_index("restore_power") == 1, "雙手搬起燃料桶")
	_place_player(_tile(30, 8), false, Vector2.LEFT)
	Input.action_press("run")
	Input.action_press("move_left")
	await _seconds(0.4)
	_check(_player.gait != Player.Gait.RUN, "搬著燃料桶不能跑")
	Input.action_release("move_left")
	Input.action_release("run")
	Input.action_press("aim")
	await _frames(5)
	_check(not _player.combat.aiming, "搬著燃料桶不能舉槍")
	Input.action_release("aim")
	await _press("fire")
	var swing: Dictionary = _player.combat.last_melee
	_check(swing.is_empty() or swing.t > 0.1, "搬著燃料桶不能揮刀")

	print("[power / generator]")
	await _main.load_area("station_b1", "basement", false)
	_quiet()
	_level = _main.level
	_check(_player.is_carrying(), "換區域時燃料桶還在手上")
	var freezer_sleepers: Array = _main.enemies.filter(func(e): return e.display_name == "Sleeper")
	gen = _find_item(Generator, Vector2i(34, 10))
	_place_player(_tile(35, 10), false, Vector2.LEFT)
	await _frames(3)
	await _press("interact")
	_check(WorldState.power_on, "倒入燃料，發電機啟動")
	_check(not _player.is_carrying(), "燃料桶用掉了")
	_check(Missions.is_done("restore_power"), "完成主線：恢復電力")
	_check(_main.level.is_lit(), "地下層的燈亮了")
	_check(_main.get_node("Darkness").color == _main.POWERED_DARKNESS, "畫面變亮")
	_check(not _main.level.is_cold(_tile(30, 3)), "地下層恢復暖氣")
	_check(_main.level.is_cold(_tile(10, 10)), "樣本冷凍庫還是冷的")
	_check(freezer_sleepers.all(func(e): return e.is_dormant), "冷凍庫裡的凍眠體還在睡")
	_check(_player.get_detection_range_mult() >= 1.2, "燈亮著的地方比較容易被發現")
	_check(not _player.input_enabled, "原型在這裡結束")
	await _seconds(7.5)
	_check(_main.level.area_id == "south_shore", "原型結束後重新開始（%s）" % _main.level.area_id)
	_check(not WorldState.power_on, "新遊戲電力還沒恢復")


