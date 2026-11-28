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
	# 行為測試在舊版的固定地圖上跑（座標寫死在測試裡）；正式地圖另外用 _test_real_maps 檢查
	Areas.use_layout(LegacyAreas.DATA, LegacyAreas.ROOMS)
	TranslationServer.set_locale("en")  # 檢查的是英文原文；翻譯另外測
	WorldState.delete_save()
	WorldState.start_loadout = false  # 測試從空手開始（撿槍、裝填都要檢查）；起始裝備在 _test_real_maps 測
	WorldState.new_game()
	WorldState.cutscenes = false  # 過場另外測（_test_cutscene）
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_player.hurt.connect(func(_d): _hit_count += 1)
	await _frames(10)

	await _test_world_start()
	await _test_audio()
	await _test_mission_panel()
	await _test_supply_crate()
	await _test_door_into_station()
	await _test_door_back_and_persistence()

	# 以下測試都在研究站一樓進行（從貨運入口進入）
	await _enter("station_1f", "cargo", false)
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
	await _test_enemy_persistence()
	await _test_caught_reset()
	await _test_enemy_hidden_behind_wall()
	await _test_chimer_blind()
	await _test_chimer_hearing()
	await _test_chimer_feel()
	await _test_chimer_shriek()
	await _test_hide_unseen()
	await _test_hide_spotted()
	await _test_first_person()
	await _test_bottle()
	await _test_breaker()
	await _test_tape_and_intel()
	await _test_pickups()
	await _test_aim_and_shoot()
	await _test_reload()
	await _test_corpse_persists()
	await _test_melee()
	await _test_combo_and_cqc()
	await _test_hidden_cache_and_shotgun()
	await _test_enemy_attack_and_death()
	await _test_items_and_infection()
	await _test_inventory_slots()
	await _test_exit()
	await _test_title()
	await _test_save_migration()
	await _test_expansion()
	await _test_new_systems()
	await _test_aftersignal()
	await _test_mgs_systems()
	await _test_real_maps()
	_test_radio_calls()
	await _test_extras()
	await _test_open_world()
	await _test_stealth_v12()
	await _test_stealth_by_input()
	await _test_survival()

	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# ── 工具 ──

func _bind_area() -> void:
	_level = _main.level
	# 合併進大地圖的區域：這個區域自己的第一隻敵人（Areas._compose 的 enemy_start）
	var start := 0
	for r in _level._data.get("regions", []):
		if r.id == _main.current_area_id():
			start = r.enemy_start
	_watcher = _main.enemies[start]
	_chimer = _main.enemies[start + 1] if _main.enemies.size() > start + 1 else null


## 按住方向鍵直到切換到指定區域（最多 2 秒），切換後立刻放開。
func _walk_until_area(action: String, area_id: String) -> void:
	var root_before: String = _main.level.area_id
	Input.action_press(action)
	for i in 120:
		if _main.current_area_id() == area_id:
			break
		await _frames(1)
	Input.action_release(action)
	while _main._transitioning:
		await _frames(1)
	await _frames(5)
	# 真的換了一張地圖（不是同一張地圖裡走進房間）：之後的座標用新區域的
	if _main.level.area_id != root_before:
		_off = Areas.area_offset(area_id)


func _spawn_pos() -> Vector2:
	var key := "station_1f:cargo" if _level._data.entries.has("station_1f:cargo") else "cargo"
	return _level.get_entry_position(key)


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


## 測試裡的格子座標都是「目前載入的區域（或房間）自己的座標」：
## 合併進大地圖的區域（Areas.rooms()）要加上位移才是地圖上的位置（_enter 會設定）。
var _off := Vector2i.ZERO


func _tile(x: int, y: int) -> Vector2:
	return (Vector2(Vector2i(x, y) + _off) + Vector2(0.5, 0.5)) * Level.TILE


## 載入區域，之後的 _tile() 用這個區域自己的座標
func _enter(area_id: String, entry: String, keep := false) -> void:
	await _main.load_area(area_id, entry, keep)
	_off = Areas.area_offset(area_id)


## 不重新載入，只把之後的 _tile() 換成某個區域（合併進大地圖的房間）自己的座標
## 房間相對於目前 _tile() 座標的位移（舊測試用 _tile(x + off.x, ...) 的寫法）
func _rel_offset(area_id: String) -> Vector2i:
	return Areas.area_offset(area_id) - _off


func _use(area_id: String) -> void:
	_off = Areas.area_offset(area_id)


## 區域自己的格子座標 → 合併後地圖的座標
func _at(area_id: String, cell: Vector2i) -> Vector2i:
	return cell + Areas.area_offset(area_id)


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
	var panel: Control = _main.mission_list
	Input.action_press("phone")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("phone")
	await get_tree().process_frame
	_check(panel.visible, "按手機鍵打開任務清單")
	_check(get_tree().paused, "打開任務清單時遊戲暫停")
	Input.action_press("phone")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release("phone")
	await get_tree().process_frame
	_check(not panel.visible and not get_tree().paused, "再按一次關閉並繼續")
	await _test_phone()
	await _test_pixel_art()


func _test_supply_crate() -> void:
	print("[world / supply crate]")
	_shore_quiet()
	_level = _main.level
	var crate := _find_item(SupplyCrate, Vector2i(50, 38))
	_place_player(_tile(50, 37), false, Vector2.DOWN)
	await _frames(3)
	_check(_player.focus == crate, "站在補給箱旁可以打開")
	await _press("interact")
	_check(Missions.is_done("supply_drop"), "完成支線：補給箱")
	_check(_player.bottles == 3, "拿到空瓶＋任務獎勵（%d）" % _player.bottles)
	_check(not crate.enabled, "補給箱已經打開")


func _test_door_into_station() -> void:
	print("[world / door]")
	_shore_quiet()
	_place_player(_tile(11, 8), false, Vector2.RIGHT)
	var root_before: String = _main.level.area_id
	await _walk_until_area("move_right", "station_1f")
	_check(_main.current_area_id() == "station_1f", "走進正門就在研究站一樓（%s）" % _main.current_area_id())
	_check(_main.level.area_id == root_before, "無縫：沒有切換地圖（同一張 %s）" % root_before)
	_check(_player.global_position.distance_to(_main.level.get_entry_position("station_1f:front")) < 20.0, "站在正門內側")
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
	_check(_main.current_area_id() == "south_shore", "從正門回到南岸（%s）" % _main.current_area_id())
	_check(WorldState.checkpoint_area() == "south_shore" and WorldState.checkpoint_entry() == "front", "走出正門：檢查點在門外")
	_check(_player.bottles == bottles, "空瓶數跟著主角走")
	_level = _main.level
	var crate := _find_item(SupplyCrate, Vector2i(50, 38))
	_check(crate != null and not crate.enabled, "已經打開的補給箱不會重生")
	var cache := _find_item(ItemPickup, Vector2i(55, 29))
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
	_check(_level.enemy_defs.filter(func(d): return d.key.begins_with("station_1f:")).size() == 2, "一樓兩隻敵人")
	_check(_level.bounds.size.x > 704 and _level.area_id == "south_shore", "一樓、安全屋、南岸、燃料庫是同一張地圖（%s）" % _level.bounds.size)
	var path := NavigationServer2D.map_get_path(
		_level.get_navigation_map(), _tile(10, 2), _spawn_pos(), true)
	_check(path.size() >= 2, "導航可以從交誼廳走到出生點")
	var lockers := _level.get_interactables().filter(func(i): return i is Locker and _level.region_at(i.global_position) in ["station_1f", "station_safe"])
	_check(lockers.size() == 5, "一樓 5 個置物櫃（%d）" % lockers.size())
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
	# 類比輕推 = 自動潛行（安靜）
	_place_player(_tile(20, 18), false)
	Input.action_press("move_right", 0.4)
	await _seconds(0.5)
	_check(_player.gait == Player.Gait.SNEAK, "搖桿輕推 = 潛行（%s）" % _player.get_gait_name())
	Input.action_press("move_right", 1.0)
	await _seconds(0.3)
	_check(_player.gait == Player.Gait.WALK, "推到底 = 走路")
	Input.action_release("move_right")
	await _frames(10)
	# 走路有腳步聲（玩家聽到的）
	Sfx.history.clear()
	Input.action_press("move_right")
	await _seconds(0.6)
	Input.action_release("move_right")
	_check(Sfx.history.has("step_concrete"), "室內走路有水泥地腳步聲")
	await _frames(10)
	# 牆角輔助：正面撞上一根柱子的邊緣（只重疊 4 px）會自動滑過去
	var post := StaticBody2D.new()
	post.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	post.add_child(shape)
	_main.level.add_child(post)
	_place_player(_tile(20, 18), false)
	post.global_position = _player.global_position + Vector2(20, 9.0)  # 主角下緣 +5，柱子上緣 +1：重疊 4 px
	await _frames(2)
	var y0 := _player.global_position.y
	Input.action_press("move_right")
	await _seconds(0.8)
	Input.action_release("move_right")
	_check(_player.global_position.x > post.global_position.x, "撞到柱子邊緣會自動滑過去（x=%.0f）" % (_player.global_position.x - post.global_position.x))
	_check(absf(_player.global_position.y - y0) < 8.0, "只挪一點點")
	post.queue_free()
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
	await _frames(2)
	_check(Sfx.current_music == "chase", "被發現 = 追逐音樂")
	_check(Sfx.history.has("alert_sting"), "被發現有提示音")
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
	_check(_watcher.state == Enemy.State.ALERT, "鳴骨者尖鳴＝呼叫同伴，附近的值班者趕過來（%s）" % _watcher.get_state_name())
	await _reset_world()
	await _test_alert_network()


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
	Input.action_press("move_left")
	await _frames(20)
	Input.action_release("move_left")
	var moved := _player.global_position.distance_to(before)
	_check(moved > 4.0 and moved < 20.0, "舉槍時可以慢慢後退（%.1f px）" % moved)
	_check(_player.facing.x > 0.9, "後退時槍口一直對著目標")
	_check(_player.combat.aim_focus <= 0.6 + 0.001, "邊走邊射時準心收不到最準")
	_check(_player.gait != Player.Gait.RUN, "舉槍時不能跑")
	await _seconds(0.7)
	_check(_player.combat.aim_focus >= 1.0, "站定後準心重新收束")
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
	await _enter("station_1f", "cargo", false)
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
	var panel: Control = _main.backpack
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
	_check(_main.current_area_id() == "station_safe", "走廊的門通往無菌隔離室（%s）" % _main.current_area_id())
	_check(_main.level.is_safe_at(_player.global_position), "這是安全屋")
	_check(_main.enemies.all(func(e): return not _main.level.is_safe_at(e.global_position)), "安全屋裡沒有敵人")
	_check(_main.level.area_id == Areas.root_of("station_1f"), "安全屋和走廊是同一張地圖（不切換畫面）")
	_place_player(_tile(14, 24), false, Vector2.DOWN)
	await _frames(3)
	var fog: RoomFog = _main.level.fog
	_check(fog != null and fog.is_hidden_cell(_main.level.cell_of(_tile(14, 18))), "在安全屋裡看不到門外的走廊")
	_check(not fog.is_hidden_cell(_main.level.cell_of(_player.global_position)), "看得到自己所在的房間")
	# 敵人追不進安全屋
	var w: Enemy = _main.enemies[0]
	w.process_mode = Node.PROCESS_MODE_INHERIT
	w.global_position = _tile(14, 17)
	w.answer_call(_player.global_position)
	await _seconds(2.5)
	_check(not _main.level.is_safe_at(w.global_position), "敵人進不了安全屋（%s）" % w.global_position)
	_check(WorldState.health == WorldState.MAX_HEALTH, "在安全屋裡不會被打到")
	w.process_mode = Node.PROCESS_MODE_DISABLED
	w.reset()
	WorldState.health = WorldState.MAX_HEALTH
	_check(Missions.step_index("find_shelter") == 1, "主線「找安全的地方」進行到用無線電")
	_check(not Missions.is_available("lost_tape"), "還沒用無線電前，支線還沒出現")

	print("[safe room / radio & save]")
	var off := _rel_offset("station_safe")
	_level = _main.level
	var radio := _find_item(RadioConsole, Vector2i(3, 2) + off)
	_place_player(_tile(3 + off.x, 3 + off.y), false, Vector2.UP)
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
	var box := _find_item(StorageBox, Vector2i(15, 2) + off)
	_place_player(_tile(15 + off.x, 3 + off.y), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == box, "可以打開儲物箱")
	await _press("interact")
	var panel: BackpackPanel = _main.backpack
	_check(panel.visible and panel.mode == "storage" and get_tree().paused, "儲物箱介面（背包＋箱子的格子）打開並暫停")
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
	_place_player(_tile(9 + off.x, 2 + off.y), false, Vector2.UP)
	await _walk_until_area("move_up", "station_1f")
	_check(_main.current_area_id() == "station_1f", "從安全屋走回走廊")
	# 無縫地圖：門口那一格已經算走廊，再往前走幾步
	Input.action_press("move_up")
	await _frames(20)
	Input.action_release("move_up")
	_check(_player.global_position.y < _tile(14, 20).y, "穿過自動門到了走廊")
	await _frames(2)
	_check(_main.level.fog.is_hidden_cell(_main.level.cell_of(_tile(14, 25))), "出來之後看不到安全屋裡面")
	_enable_all()


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

	print("[translation]")
	TranslationServer.set_locale("zh_TW")
	_check(tr("Go upstairs") == "上樓" and Items.display_name("stone") == "石頭", "繁體中文翻譯")
	var texts: Array[String] = []
	for m in Missions.DATA:
		texts.append_array([m.title, m.desc])
		if m.has("radio"):
			texts.append(m.radio)
	for id in Items.DATA:
		texts.append_array([Items.DATA[id].name, Items.DATA[id].desc])
	for a in Areas.all().values():
		texts.append(a.title)
		texts.append_array(a.messages.values())
		if a.has("boss"):
			texts.append(a.boss)
	for f in Frequencies.DATA:
		texts.append(f.label)
		texts.append_array(f.lines)
	for e in Endings.DATA.values():
		texts.append(e.title)
		texts.append_array(e.lines)
	for u in UplinkMessages.DATA:
		texts.append_array([u.label, u.sent, u.reply])
	texts.append_array(UplinkMessages.INTRO)
	texts.append_array(UplinkMessages.HOLD_REPLY)
	for call in RadioCalls.DATA:
		texts.append_array(call.lines)
	for table in [FieldRadio.AREA, FieldRadio.ENEMY, FieldRadio.EVENT]:
		for lines in table.values():
			for l in lines:
				texts.append(l[1])
	for w in Weather.KINDS.values():
		texts.append(w.name)
	for p in Island.PLACES.values():
		texts.append(p.name)
	for id in Items.MODS:
		texts.append_array([Items.MODS[id].name, Items.MODS[id].desc])
	for area in Extras.DATA.values():
		for ex in area.values():
			texts.append(ex.get("text", ""))
	for id in Cutscenes.DATA:
		for step in Cutscenes.DATA[id]:
			for key in ["caption", "say", "text", "sub", "name", "role", "credit"]:
				if step.has(key):
					texts.append(step[key])
	for id in Codex.ENTRIES:
		texts.append_array([Codex.ENTRIES[id].name, Codex.ENTRIES[id].desc, Codex.ENTRIES[id].tip])
	for id in SurvivalData.MAPS:
		texts.append_array([SurvivalData.MAPS[id].name, SurvivalData.MAPS[id].desc])
	for id in SurvivalData.UNLOCKS:
		texts.append_array([SurvivalData.UNLOCKS[id].name, SurvivalData.UNLOCKS[id].desc])
	var missing := texts.filter(func(t): return t != "" and TranslationServer.translate(t) == t)
	_check(missing.is_empty(), "所有劇情、任務、物品文字都有中文（缺 %d：%s）" % [missing.size(), str(missing.slice(0, 3))])
	TranslationServer.set_locale("en")


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
	_check(_main.level.area_id == "station_2f", "樓梯通往二樓（%s）" % _main.current_area_id())
	_check(Missions.is_done("find_stairs"), "完成主線：到達樓上")
	_check(Missions.tracked_mission().get("id") == "director_records", "下一個主線：站長的紀錄")
	_check(_main.level.is_cold(_player.global_position), "二樓暖氣壞了，是冷的")
	_use("station_2f")
	_bind_upper()
	await _test_sleepers()
	await _test_keycard_and_office()


var _sleepers: Array[Enemy] = []


func _bind_upper() -> void:
	_level = _main.level
	_watcher = _main.enemies[0]
	_sleepers.clear()
	for e in _main.enemies:
		# 二樓和東翼是同一張地圖：只算二樓自己的
		if e.display_name == "Sleeper" and e.enemy_key.begins_with("station_2f:"):
			_sleepers.append(e)


func _test_sleepers() -> void:
	print("[sleeper]")
	_check(_sleepers.size() == 4, "二樓有 4 隻凍眠體")
	var s: Enemy = _sleepers[0]  # 宿舍 A (12,4)
	_check(s.is_dormant and s.can_be_taken_down_by(_player), "凍眠體一開始躺著（可以偷襲）")
	var decoys := _level.get_children().filter(func(n): return n is CorpseDecor and _level.region_at(n.global_position) == "station_2f")
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
	_check(_main.current_area_id() == "station_2f", "沒有權限卡時辦公室的門打不開")
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
	_check(_main.current_area_id() == "station_2f_office", "有權限卡就能進站長室")
	_level = _main.level
	_check(_level.area_id == "station_2f", "站長室和二樓是同一張地圖")
	var off := _rel_offset("station_2f_office")
	var note := _find_item(ReadableNote, Vector2i(3, 2) + off)
	_place_player(_tile(3 + off.x, 3 + off.y), false, Vector2.UP)
	await _frames(3)
	await _press("interact")
	_check(WorldState.is_freq_known(12570), "站長的便條：記下 125.70")
	var terminal := _find_item(Terminal, Vector2i(12, 2) + off)
	_place_player(_tile(12 + off.x, 3 + off.y), false, Vector2.UP)
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
	await _enter("station_1f", "stairs", false)
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
	await _enter("fuel_depot", "depot", false)
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
	await _enter("station_b1", "basement", false)
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
	_check(_player.input_enabled, "恢復電力後可以繼續（主線：機庫）")
	_check(Missions.tracked_mission().get("id") == "hangar_snowcat", "下一個主線：機庫")
	await _test_hangar()


func _wait_phase(bear: BossBear, phase: int, max_frames := 240) -> bool:
	for i in max_frames:
		if bear.phase == phase:
			return true
		await _frames(1)
	return bear.phase == phase


func _test_hangar() -> void:
	print("[hangar / electric door]")
	await _enter("south_shore", "hangar", false)
	_quiet()
	WorldState.data.flags.erase("power_on")
	_place_player(_tile(7, 2), false, Vector2.UP)
	Input.action_press("move_up")
	await _seconds(0.6)
	Input.action_release("move_up")
	await _frames(5)
	_check(_main.level.area_id == "south_shore", "沒電時機庫的電動門打不開")
	_check("electric" in _main.get_node("HUD/Message").text, "提示需要電力")
	WorldState.set_flag("power_on")
	_place_player(_tile(7, 2), false, Vector2.UP)
	await _walk_until_area("move_up", "hangar")
	_check(_main.level.area_id == "hangar", "有電之後可以進機庫")
	_level = _main.level
	var cam: FollowCamera = _main.get_node("Camera")
	_check(cam.fixed and cam.global_position == _level.bounds.get_center().round(), "Boss 戰鏡頭固定看整個機庫")
	var bear: BossBear = _main.enemies[0]
	await _frames(2)
	_check(_main.get_node("HUD/BossBar").visible, "顯示 Boss 血條")
	_check(Missions.step_index("hangar_snowcat") == 1, "主線進行到打倒 Boss")

	print("[boss / charge & stun]")
	WorldState.health = 100.0
	_place_player(_tile(27, 14), false, Vector2.UP)
	_player.sneaking = true
	await _frames(5)
	_check(not bear._has_target, "潛行站著不動時 Boss 不知道你在哪")
	bear.reset()
	await _frames(2)
	NoiseBus.emit_noise(Vector2(100, 120), 112.0, null)  # 瓶子落地的大小
	await _frames(2)
	_check(bear.phase == BossBear.Phase.WINDUP, "聽到附近的聲音就準備衝撞")
	_check(await _wait_phase(bear, BossBear.Phase.CHARGE), "直線衝撞")
	_check(await _wait_phase(bear, BossBear.Phase.STUNNED), "撞到牆就暈眩")
	var hp := bear.health
	bear.take_damage(10.0, _player.global_position, 0.0)
	_check(is_equal_approx(hp - bear.health, 15.0), "暈眩時受到的傷害 x1.5")

	print("[boss / swipe]")
	bear.reset()
	WorldState.health = 100.0
	_player._invulnerable = 0.0
	_place_player(bear.global_position + Vector2(-20, 0), false, Vector2.RIGHT)
	var hits := _hit_count
	await _seconds(1.2)
	_check(_hit_count > hits, "太靠近會被揮爪打到")
	_check(_player.infection > 0.0, "Boss 的攻擊也會感染")
	await _await_reset()

	print("[boss / hiding]")
	bear.reset()
	WorldState.health = 100.0
	var locker := _find_item(Locker, Vector2i(2, 12))
	_place_player(_tile(3, 12), false, Vector2.LEFT)
	_player.enter_hiding(locker)
	hits = _hit_count
	await _seconds(3.0)
	_check(_hit_count == hits, "躲在置物櫃裡不會被打到")
	_player.exit_hiding()

	print("[boss / cold]")
	bear.reset()
	var breaker := _find_item(Breaker, Vector2i(14, 1))
	_place_player(_tile(14, 2), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == breaker, "機庫裡有配電箱")
	await _press("interact")
	await _frames(3)
	_check(bear.in_cold, "關掉暖氣後 Boss 在冷的環境裡")
	_check(bear._has_target, "扳開關的聲音引來 Boss")
	await _await_reset()

	print("[boss / defeat]")
	bear.reset()
	WorldState.health = 100.0
	WorldState.inv_add("pistol", 1)
	WorldState.inv_add("ammo", 8)
	WorldState.equipped = "pistol"
	WorldState.set_loaded("pistol", 8)
	bear.health = 5.0
	_place_player(_tile(10, 7), false, Vector2.RIGHT)
	Input.action_press("aim")
	await _seconds(0.5)
	_check(_player.combat.target == bear, "可以鎖定 Boss")
	await _press("fire")
	Input.action_release("aim")
	await _frames(3)
	_check(bear.is_dead, "打倒苔原之母")
	_check(WorldState.has_flag("defeated:tundra_mother"), "記錄 Boss 已被打倒")
	_check(Missions.step_index("hangar_snowcat") == 2, "主線進行到雪地車")
	_check(not _main.get_node("HUD/BossBar").visible, "Boss 死後血條消失")

	print("[snowcat]")
	var snowcat := _find_item(Snowcat, Vector2i(14, 12))
	_place_player(_tile(14, 11), false, Vector2.DOWN)
	await _frames(3)
	_check(_player.focus == snowcat, "可以使用雪地車")
	_check("Antenna Tower" in snowcat.get_prompt(_player), "雪地車開往天線塔")
	await _press("interact")
	_check(Missions.is_done("hangar_snowcat"), "完成主線：機庫")
	while _main._transitioning:
		await _frames(1)
	await _frames(3)
	_check(_main.level.area_id == "tower_yard", "雪地車開到天線塔")
	_check(_player.input_enabled and not _main._resetting, "機庫不再是原型的終點")
	_check(Missions.tracked_mission().get("id") == "send_signal", "下一個主線：天線塔")
	await _test_tower()


func _test_tower() -> void:
	print("[tower / yard]")
	_quiet()
	_level = _main.level
	_check(_player.global_position.distance_to(_level.get_entry_position("snowcat")) < 1.0, "站在雪地車旁邊")
	_check(_level.outdoor and _level.is_cold(_tile(20, 16)), "天線塔的庭院在戶外，很冷")
	_check(_main.enemies.size() == 2, "庭院有兩隻值班者")
	var back := _find_item(Snowcat, Vector2i(4, 20))
	_check(back != null and "Hangar" in back.get_prompt(_player), "雪地車可以開回機庫")
	var stairs := _find_item(ExitPoint, Vector2i(15, 3))
	_check(stairs != null and stairs.get_prompt(_player) == "Go upstairs", "塔底的樓梯往上")
	_place_player(_tile(16, 3), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus == stairs, "可以爬上塔頂")
	await _press("interact")
	while _main._transitioning:
		await _frames(1)
	await _frames(3)
	_check(_main.level.area_id == "tower_top", "到達通訊甲板")
	_check(Missions.step_index("send_signal") == 1, "主線進行到發出訊號")

	print("[tower / iced dish]")
	_quiet()
	_level = _main.level
	var down := _find_item(ExitPoint, Vector2i(2, 11))
	_check(down != null and down.get_prompt(_player) == "Go downstairs", "塔頂的樓梯往下")
	var uplink := _find_item(Uplink, Vector2i(3, 1))
	_check(uplink != null and not uplink.dish_ready(), "天線碟結冰：還不能發訊號")
	_place_player(_tile(3, 2), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == uplink and uplink.get_prompt(_player) == "Uplink (no signal)", "終端機提示沒有訊號")
	await _press("interact")
	var panel: Control = _main.get_node("HUD/SignalPanel")
	_check(not panel.visible, "結冰時打不開發訊介面")
	_check("iced" in _main.get_node("HUD/Message").text, "提示天線碟結冰")
	_check(Missions.step_index("send_signal") == 1, "沒發出訊號不算完成")

	print("[tower / de-icer]")
	var sleepers: Array = _main.enemies.filter(func(e): return e.display_name == "Sleeper")
	_check(sleepers.size() == 2 and sleepers.all(func(e): return e.is_dormant), "平台上的凍眠體在睡")
	for e in sleepers:
		e.process_mode = Node.PROCESS_MODE_INHERIT
	var breaker := _find_item(Breaker, Vector2i(31, 2))
	_place_player(_tile(31, 3), false, Vector2.UP)
	_player.sneaking = true
	await _frames(3)
	_check(_player.focus == breaker and "dish de-icer" in breaker.get_prompt(_player), "除冰器的配電箱")
	await _press("interact")
	_player.sneaking = false
	await _frames(5)
	_check(uplink.dish_ready() and uplink.get_prompt(_player) == "Transmit", "除冰後可以發訊號")
	_check(sleepers.all(func(e): return not e.is_dormant), "平台變暖，凍眠體醒來")
	_quiet()

	print("[tower / signal choice]")
	WorldState.health = 100.0
	_place_player(_tile(3, 2), false, Vector2.UP)
	await _frames(3)
	await _press("interact")
	await _frames(2)
	_check(panel.visible and get_tree().paused, "打開發訊介面（遊戲暫停）")
	_check(_main._signal_armed == -1, "打開介面的那一下不會直接選取")
	await _tap("move_down")
	_check(_main._signal_cursor == 1, "上下選擇訊息")
	await _tap("interact")
	_check(_main._signal_armed == 1 and WorldState.signal_choice() == "", "第一次只是選取，還沒發出")
	await _tap("move_up")
	_check(_main._signal_armed == -1, "換選項會取消選取")
	await _tap("move_down")
	await _tap("interact")
	await _tap("interact")
	_check(WorldState.signal_choice() == "quarantine", "再選一次才發出：隔離")
	_check("126.05" in _main.get_node("HUD/SignalPanel/Box/Text").text, "收到不明的回覆")
	_check(12605 in WorldState.known_freqs(), "不明頻率記進無線電備忘錄")
	_main.send_signal("rescue")
	_check(WorldState.signal_choice() == "quarantine", "訊號只能發一次")
	_check(Missions.step_index("send_signal") == 1, "看完回覆前還不算完成")
	await _tap("interact")
	_check(not panel.visible and not get_tree().paused, "關閉介面")
	_check(Missions.is_done("send_signal"), "完成主線：天線塔")
	_check(uplink.get_prompt(_player) == "Uplink (signal sent)", "終端機記得已經發過")
	_check(_player.input_enabled and not _main._resetting, "天線塔不再是原型的終點")
	_check(WorldState.access_level == 3, "權限卡升到等級 3")
	_check(Missions.tracked_mission().get("id") == "the_shaft", "下一個主線：鑽探井")

	print("[tower / touch buttons]")
	WorldState.data.flags.erase("signal")
	_main._open_signal_panel()
	var buttons: Array = _main._signal_buttons
	_check(buttons.all(func(b): return b.visible), "三個訊息＋離開，都有按鈕可以點")
	buttons[3].pressed.emit()
	_check(not panel.visible and WorldState.signal_choice() == "", "可以先離開，之後再決定")
	_main._open_signal_panel()
	buttons[2].pressed.emit()
	buttons[2].pressed.emit()
	_check(WorldState.signal_choice() == "destroy", "點同一個按鈕兩次發出：摧毀")
	_check(buttons[0].visible and buttons[0].text == "Close" and not buttons[2].visible, "發出後只剩關閉按鈕")
	buttons[0].pressed.emit()
	_check(not panel.visible, "點關閉")
	WorldState.set_flag("signal", "quarantine")
	await _test_shaft()


func _test_shaft() -> void:
	print("[shaft / door]")
	await _enter("station_b1", "basement", false)
	_quiet()
	_level = _main.level
	WorldState.data.access_level = 2  # 權限只會升不會降：測試直接改資料
	_place_player(_tile(21, 14), false, Vector2.DOWN)
	Input.action_press("move_down")
	await _seconds(0.6)
	Input.action_release("move_down")
	await _frames(5)
	_check(_main.level.area_id == "station_b1", "權限卡等級 2 打不開鑽探井")
	WorldState.access_level = 3
	_place_player(_tile(21, 14), false, Vector2.DOWN)
	await _walk_until_area("move_down", "drill_shaft")
	_check(_main.level.area_id == "drill_shaft", "等級 3 可以進鑽探井")
	_quiet()
	_level = _main.level
	_check(_level.is_cold(_tile(10, 10)), "鑽探井裡很冷")
	var shaft_sleepers: Array = _main.enemies.filter(func(e): return e.display_name == "Sleeper")
	_check(shaft_sleepers.size() == 3 and shaft_sleepers.all(func(e): return e.is_dormant), "井壁走道上有凍眠體在睡")
	var ladder := _find_item(ExitPoint, Vector2i(22, 19))
	_check(ladder != null and ladder.get_prompt(_player) == "Go downstairs", "往井底的梯子")
	_place_player(_tile(21, 19), false, Vector2.RIGHT)
	await _frames(3)
	await _press("interact")
	while _main._transitioning:
		await _frames(1)
	await _frames(3)
	_check(_main.level.area_id == "shaft_bottom", "到達井底")
	_check(Missions.step_index("the_shaft") == 1, "主線進行到打倒深井")

	print("[final boss / pulse]")
	_level = _main.level
	var cam: FollowCamera = _main.get_node("Camera")
	_check(cam.fixed, "Boss 戰鏡頭固定")
	var well: BossWell = _main.enemies[0]
	await _frames(2)
	_check(_main.get_node("HUD/BossBar").visible and "DEEP WELL" in _main.get_node("HUD/BossBar/Name").text, "顯示深井的血條")
	WorldState.health = 100.0
	WorldState.infection = 0.0
	_player._invulnerable = 0.0
	_place_player(_tile(15, 11), false, Vector2.UP)
	_player.sneaking = true
	well.reset()
	well._set_phase(BossWell.Phase.CHARGING)
	var hits := _hit_count
	await _seconds(1.6)
	_check(well.pulse_count == 1 and well.last_pulse_hit and _hit_count > hits, "站在空地會被共鳴脈衝打到")
	_check(well.is_exposed() and "EXPOSED" in _main.get_node("HUD/BossBar/Name").text, "脈衝之後核心露出來")
	await _await_reset()

	print("[final boss / cover]")
	well.reset()
	WorldState.health = 100.0
	_player._invulnerable = 0.0
	_place_player(_tile(4, 2), false, Vector2.UP)
	_player.sneaking = true
	well._set_phase(BossWell.Phase.CHARGING)
	hits = _hit_count
	await _seconds(1.6)
	_check(well.pulse_count == 1 and not well.last_pulse_hit and _hit_count == hits, "躲在柱子後面擋得住脈衝")
	well.reset()
	var locker := _find_item(Locker, Vector2i(2, 13))
	_place_player(_tile(3, 13), false, Vector2.LEFT)
	_player.enter_hiding(locker)
	well._set_phase(BossWell.Phase.CHARGING)
	await _seconds(1.6)
	_check(not well.last_pulse_hit and _hit_count == hits, "躲在置物櫃裡也安全")
	_player.exit_hiding()

	print("[final boss / armor & spikes]")
	well.reset()
	var hp := well.health
	well.take_damage(100.0, _tile(4, 11), 0.0)
	_check(is_equal_approx(hp - well.health, 15.0), "核心沒露出來時幾乎打不動")
	_check(well.spikes.size() == 1, "被打到就在你的位置刺出結晶")
	well.reset()
	well._set_phase(BossWell.Phase.EXPOSED)
	well.take_damage(100.0, _tile(4, 11), 0.0)
	_check(is_equal_approx(hp - well.health, 100.0), "核心露出來時打得痛")
	_check(well.spikes.is_empty(), "核心露出來時不會刺")
	well.reset()
	WorldState.health = 100.0
	_player._invulnerable = 0.0
	_place_player(_tile(24, 9), false, Vector2.UP)
	_player.sneaking = true
	await _frames(3)
	_check(well.spikes.is_empty(), "潛行不會被感覺到")
	NoiseBus.emit_noise(_tile(8, 6), 112.0, null)  # 瓶子丟到別的地方
	await _frames(2)
	_check(well.spikes.size() == 1, "聽到聲音就在那裡預告結晶刺")
	hits = _hit_count
	await _seconds(1.1)
	_check(well.spikes.is_empty() and _hit_count == hits, "結晶刺被瓶子引開，打不到你")
	well._spike_cd = 0.0
	NoiseBus.emit_noise(_player.global_position, 112.0, null)
	await _seconds(1.1)
	_check(_hit_count > hits, "站在預告的位置會被刺到")
	await _await_reset()

	print("[final boss / cold & lift]")
	well.reset()
	var lift := _find_item(ShaftLift, Vector2i(26, 1))
	_place_player(_tile(25, 1), false, Vector2.RIGHT)
	await _frames(3)
	_check(_player.focus == lift and lift.get_prompt(_player) == "Lift (jammed)", "Boss 還活著時升降機不會動")
	await _press("interact")
	_check(Missions.step_index("the_shaft") == 1, "升降機卡住不算完成")
	var breaker := _find_item(Breaker, Vector2i(13, 13))
	_place_player(_tile(13, 12), false, Vector2.DOWN)
	await _frames(3)
	_check(_player.focus == breaker and "drill heaters" in breaker.get_prompt(_player), "井底的鑽頭加熱器")
	await _press("interact")
	await _frames(3)
	_check(well.in_cold, "關掉加熱器後深井變冷（蓄力變慢）")

	print("[final boss / defeat]")
	well.reset()
	WorldState.inv_add("pistol", 1)
	WorldState.inv_add("ammo", 8)
	WorldState.equipped = "pistol"
	WorldState.set_loaded("pistol", 8)
	well.health = 5.0
	well._set_phase(BossWell.Phase.EXPOSED)
	_place_player(_tile(15, 11), false, Vector2.UP)
	Input.action_press("aim")
	await _seconds(0.5)
	_check(_player.combat.target == well, "可以鎖定深井")
	await _press("fire")
	Input.action_release("aim")
	await _frames(3)
	_check(well.is_dead, "打倒深井")
	_check(WorldState.has_flag("defeated:deep_well"), "記錄最終 Boss 已被打倒")
	_check(Missions.step_index("the_shaft") == 2, "主線進行到搭升降機")
	_check(not _main.get_node("HUD/BossBar").visible, "Boss 死後血條消失")

	print("[ending]")
	_check(Endings.resolve_id("rescue", 10.0) == "evacuation", "救援＋沒被感染 = 撤離")
	_check(Endings.resolve_id("rescue", 80.0) == "last_light", "救援但已被感染 = 最後的光")
	_check(Endings.resolve("rescue", 80.0).lines[0] == Endings.INFECTED_LINE, "被感染時結局的第一句不同")
	_check(Endings.resolve_id("destroy", 0.0) == "last_light", "要求摧毀 = 最後的光")
	_check(Endings.resolve_id("quarantine", 90.0) == "quarantine" and Endings.DATA.quarantine.canon, "隔離 = 正史結局")
	WorldState.infection = 10.0
	_place_player(_tile(25, 1), false, Vector2.RIGHT)
	await _frames(3)
	_check(lift.get_prompt(_player) == "Ride the lift up", "升降機可以搭了")
	await _press("interact")
	_check(Missions.is_done("the_shaft"), "完成主線：鑽探井")
	_check(not _player.input_enabled, "主線完成，進入結局")
	await _seconds(_main.ENDING_DELAY + 0.3)
	var ending_panel: Control = _main.get_node("HUD/EndingPanel")
	_check(ending_panel.visible and get_tree().paused, "顯示結局畫面")
	_check(_main.last_ending.get("id") == "quarantine", "發出隔離訊號 → 隔離結局")
	_check("THE END" in _main._ending_text.text, "結局畫面寫著 THE END")

	# 收尾：回到新遊戲，讓後面的測試從頭開始
	ending_panel.visible = false
	get_tree().paused = false
	_main._resetting = false
	WorldState.new_game()
	await _enter(WorldState.data.area, WorldState.data.entry, false)
	_check(WorldState.signal_choice() == "" and not WorldState.power_on, "新遊戲的狀態是乾淨的")
	await _test_environment()


var _noises: Array = []


func _listen_noise() -> void:
	_noises.clear()
	if not NoiseBus.noise_emitted.is_connected(_on_test_noise):
		NoiseBus.noise_emitted.connect(_on_test_noise)


func _on_test_noise(pos: Vector2, radius: float, source: Node) -> void:
	_noises.append({"pos": pos, "radius": radius, "source": source})


func _loudest() -> float:
	var r := 0.0
	for n in _noises:
		r = maxf(r, n.radius)
	return r


func _test_environment() -> void:
	print("[light / lighter]")
	_quiet()
	_level = _main.level
	_place_player(_tile(20, 12), true, Vector2.RIGHT)
	_player.cycle_light()
	_check(not _player.flashlight_on and _player.lighter_on, "手電筒 → 打火機")
	_check(_player.can_see_point(_player.global_position + Vector2(-58, 0)), "打火機照得到身邊一圈")
	_check(not _player.is_in_flashlight(_player.global_position + Vector2(100, 0)), "打火機沒有光束")
	var lighter_mult := _player.get_detection_range_mult()
	_player.cycle_light()
	_check(not _player.flashlight_on and not _player.lighter_on, "打火機 → 全關")
	_check(_player.get_detection_range_mult() < lighter_mult, "全暗比打火機更不容易被發現")
	_player.cycle_light()
	_check(_player.flashlight_on, "全關 → 手電筒")

	print("[throw / stones & firebomb]")
	_listen_noise()
	WorldState.inv_add("stone", 3)
	_check(_player.current_throwable() == "stone", "沒有空瓶時改丟石頭")
	_check(_player.throw_item(), "丟出石頭")
	await _seconds(0.6)
	_check(WorldState.inv_count("stone") == 2, "石頭少一顆")
	_check(is_equal_approx(_loudest(), 4.0 * Player.TILE), "石頭的聲音比空瓶小（%.0f）" % _loudest())
	WorldState.inv_add("ethanol", 1)
	_check(not _player.use_item("ethanol"), "沒有空瓶就做不出汽油彈")
	WorldState.inv_add("bottle", 1)
	_check(_player.use_item("ethanol"), "酒精＋空瓶 = 汽油彈")
	_check(WorldState.inv_count("molotov") == 1 and WorldState.inv_count("bottle") == 0 \
		and WorldState.ready_throw == "molotov", "做好的汽油彈準備好丟")
	var victim: Enemy = _main.enemies[0]
	var landing := _player.global_position + Vector2.RIGHT * (_player.throw_distance - 4.0)
	_freeze(victim, landing, Vector2.UP)
	victim.process_mode = Node.PROCESS_MODE_INHERIT
	var hp := victim.health
	_check(_player.throw_item(), "丟出汽油彈")
	await _seconds(0.6)
	var fires := get_tree().get_nodes_in_group(Fire.GROUP)
	_check(fires.size() == 1, "汽油彈落地起火")
	_check(Fire.lit_at(get_tree(), landing), "火光照亮附近")
	await _seconds(1.2)
	_check(victim.health < hp, "站在火裡的敵人被燒傷（%.0f → %.0f）" % [hp, victim.health])
	for f in fires:
		f.put_out()
	_quiet()

	print("[extinguisher]")
	await _enter("station_1f", "cargo", false)
	_quiet()
	_level = _main.level
	var mount := _find_item(ExtinguisherMount, Vector2i(9, 17))
	_place_player(_tile(10, 17), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus == mount, "牆上有滅火器")
	await _press("interact")
	_check(WorldState.carrying == "extinguisher" and WorldState.extinguisher_charge == 6, "雙手拿起滅火器")
	Input.action_press("aim")
	await _frames(5)
	Input.action_release("aim")
	_check(not _player.combat.aiming, "拿著滅火器不能舉槍")
	_place_player(_tile(14, 18), false, Vector2.RIGHT)
	var fire := Fire.new()
	_level.add_child(fire)
	fire.global_position = _player.global_position + Vector2(30, 0)
	var watcher: Enemy = _main.enemies[0]
	_freeze(watcher, _player.global_position + Vector2(36, 0), Vector2.LEFT)
	watcher.process_mode = Node.PROCESS_MODE_INHERIT
	watcher._set_state(Enemy.State.ALERT)
	await _press("fire")
	await _frames(2)
	_check(get_tree().get_nodes_in_group(Fire.GROUP).is_empty(), "噴滅火器撲滅火")
	_check(WorldState.extinguisher_charge == 5, "噴一次用掉一格")
	_check(watcher._stagger > 2.0 and watcher.state == Enemy.State.SEARCH,
		"噴到的敵人看不見、失去你的位置（stagger %.1f state %s）" % [watcher._stagger, watcher.get_state_name()])
	_check(SmokeCloud.blocks(get_tree(), _player.global_position, _player.global_position + Vector2(60, 0)), "白霧擋住視線")
	_quiet()
	_listen_noise()
	await _press("throw")
	await _seconds(0.6)
	_check(WorldState.carrying == "", "把滅火器丟出去")
	_check(_loudest() >= 10.0 * Player.TILE, "滅火器落地很大聲（誘餌）")

	print("[breakables / drum / stones / knock]")
	await _enter("fuel_depot", "depot", false)
	_quiet()
	_level = _main.level
	var crate := _find_item(Breakable, Vector2i(22, 13))
	_place_player(_tile(23, 13), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus == crate and "Kick" in crate.get_prompt(_player), "木箱可以踢開")
	_listen_noise()
	await _press("fire")
	_check(crate.enabled, "割一下還沒開")
	await _seconds(0.55)
	await _press("fire")
	await _frames(2)
	_check(not crate.enabled, "小刀割兩下打開木箱")
	_check(_loudest() <= 2.0 * Player.TILE + 0.1, "用刀割很安靜")
	var loot: Interactable = null
	for item in _level.get_interactables():
		if item is ItemPickup and item.pickup_item == "ethanol" and item.enabled:
			loot = item
	_check(loot != null, "木箱裡掉出酒精")
	var crate2 := _find_item(Breakable, Vector2i(36, 9))
	_place_player(_tile(36, 10), false, Vector2.UP)
	await _frames(3)
	_listen_noise()
	await _press("interact")
	_check(not crate2.enabled and _loudest() >= 7.0 * Player.TILE, "踢開木箱：一下就開，但很大聲")
	var boards := _find_item(Breakable, Vector2i(27, 15))
	_check(not Sight.is_clear(_player, _tile(27, 13), _tile(27, 17)), "木板封住倉庫的後門")
	_place_player(_tile(27, 16), false, Vector2.UP)
	await _frames(3)
	_check(_player.focus == boards, "可以拆木板")
	await _press("interact")
	await _frames(3)
	_check(Sight.is_clear(_player, _tile(27, 13), _tile(27, 17)), "拆掉木板 = 一條捷徑")
	var path := NavigationServer2D.map_get_path(_level.get_navigation_map(), _tile(27, 13), _tile(27, 17), true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	_check(path.size() > 0 and length < 80.0, "敵人也走得過拆掉的通道（路徑 %.0f）" % length)
	var drum := _find_item(OilDrum, Vector2i(5, 16))
	_place_player(_tile(6, 16), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus == drum, "可以點燃油桶")
	await _press("interact")
	_check(drum.is_lit() and Fire.lit_at(get_tree(), _tile(5, 16)), "油桶燒起來，照亮附近")
	var pile := _find_item(StonePile, Vector2i(8, 18))
	_place_player(_tile(8, 17), false, Vector2.DOWN)
	await _frames(3)
	var stones := WorldState.inv_count("stone")
	await _press("interact")
	_check(WorldState.inv_count("stone") > stones and WorldState.inv_count("stone") % 5 == 0, "從碎石堆撿石頭")
	_place_player(_tile(1, 5), false, Vector2.LEFT)
	await _frames(3)
	_listen_noise()
	await _press("interact")
	_check(_noises.is_empty(), "面對牆壁按互動不會敲牆（已取消）")
	await _enter("south_shore", "depot", false)
	await _enter("fuel_depot", "depot", false)
	_level = _main.level
	_check(_find_item(OilDrum, Vector2i(5, 16)).is_lit(), "回到燃料庫，油桶還在燒")
	_check(not _find_item(Breakable, Vector2i(27, 15)).enabled, "拆掉的木板不會復原")
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		f.put_out()

	WorldState.new_game()
	await _enter(WorldState.data.area, WorldState.data.entry, false)
	await _test_cold_and_huts()


func _test_cold_and_huts() -> void:
	print("[body temperature]")
	_quiet()
	_level = _main.level
	_check(Climates.has_exposure(_level.climate_id()), "灰鴉島是北極氣候：會失溫")
	_check(not Climates.has_exposure("temperate"), "溫帶氣候（之後的資料片）不會失溫")
	WorldState.body_temp = 100.0
	_place_player(_tile(30, 36), true, Vector2.UP)
	await _seconds(1.0)
	_check(WorldState.body_temp < 99.95 and WorldState.body_temp > 99.5, "戶外會慢慢失溫（主角很耐冷：%.2f）" % WorldState.body_temp)
	_check("Body:" in _main.get_node("HUD/Condition").text, "會失溫的地方顯示體溫")
	var fire := Fire.new()
	fire.harmful = false
	fire.duration = 0.0
	_level.add_child(fire)
	fire.global_position = _player.global_position + Vector2(30, 0)
	var before := WorldState.body_temp
	await _seconds(0.5)
	_check(WorldState.body_temp > before, "火堆旁邊會回暖")
	fire.put_out()
	WorldState.body_temp = 30.0
	await _frames(2)
	_check(_player.is_shivering() and _player.get_speed_mult() < 1.0, "體溫太低會發抖、走得慢")
	WorldState.inv_add("heat_pack", 1)
	_check(_player.use_item("heat_pack") and WorldState.body_temp > 85.0, "暖暖包讓體溫回升")
	WorldState.body_temp = 0.0
	WorldState.health = 100.0
	await _seconds(0.5)
	_check(WorldState.health < 100.0, "體溫降到 0 生命值開始流失")
	WorldState.body_temp = 100.0
	WorldState.health = 100.0

	print("[weather huts]")
	WorldState.set_flag("mission:enter_station", 1)
	WorldState.set_flag("mission:find_shelter", 2)
	var radio_text := " ".join(Missions.receive_radio())
	_check("weather camp" in radio_text, "無線電接到氣象小屋的委託")
	_check(Missions.is_active("weather_station"), "支線：氣象小屋")
	_place_player(_tile(1, 32), false, Vector2.LEFT)
	await _walk_until_area("move_left", "weather_huts")
	_check(_main.level.area_id == "weather_huts", "南岸西邊通往氣象小屋群")
	_quiet()
	_level = _main.level
	_check(_level.bounds.size.x >= 64 * Level.TILE, "氣象小屋群是一大片雪原")
	_check(_level.exposure_at(_tile(15, 12)) < _level.exposure_at(_tile(10, 22)), "小屋裡擋風，失溫比較慢")
	_place_player(_tile(45, 13), false, Vector2.UP)
	await _walk_until_area("move_up", "huts_safe")
	_check(_main.current_area_id() == "huts_safe", "進入床鋪小屋（第二間安全屋）")
	_check(_main.level.is_safe_at(_player.global_position) and _main.level.exposure_at(_player.global_position) < 0.0, "安全屋很暖和")
	_check(_main.level.area_id == "weather_huts", "床鋪小屋和雪原是同一張地圖")
	_check(Missions.step_index("weather_station") == 1, "支線進行到 Pieter 的下落")
	await _enter("weather_huts", "bunk", false)
	_quiet()
	_level = _main.level
	var packs := WorldState.inv_count("heat_pack")
	_place_player(_tile(33, 25), false, Vector2.UP)
	await _frames(3)
	await _press("interact")
	_check(Missions.is_done("weather_station"), "完成支線：氣象小屋")
	_check(WorldState.inv_count("heat_pack") == packs + 2, "獎勵：暖暖包")
	_check(Missions.is_active("signal_fire"), "支線：稜線上的信標")
	var cache := _find_item(ItemPickup, Vector2i(6, 32))
	_check(cache != null and not cache.enabled, "補給還沒投下")
	_place_player(_tile(11, 4), false, Vector2.LEFT)
	await _frames(3)
	_check(_player.focus is OilDrum, "信標油桶")
	await _press("interact")
	_check(Missions.is_done("signal_fire"), "點燃信標：完成支線")
	_check(cache.enabled, "補給無人機投下東西")
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		f.put_out()

	WorldState.new_game()
	await _enter(WorldState.data.area, WorldState.data.entry, false)
	await _test_touch()


func _test_enemy_persistence() -> void:
	print("[enemies stay where they were]")
	_enable_all()
	var key := _watcher.enemy_key
	_watcher.global_position = _tile(10, 10)
	_watcher._start_search(_tile(10, 10))
	await _frames(2)
	var left_at := _watcher.global_position
	await _enter("south_shore", "front", false)
	await _enter("station_1f", "cargo", false)
	_bind_area()
	_check(_watcher.enemy_key == key, "同一隻敵人")
	_check(_watcher.global_position.distance_to(left_at) < 2.0, "離開再回來，敵人還在原本的地方")
	_check(_watcher.state == Enemy.State.SEARCH, "離開時在找你，回來時牠還在附近搜索")
	# 恢復原狀，後面的測試從巡邏起點開始
	WorldState.data.enemies.clear()
	await _enter("station_1f", "cargo", false)
	_bind_area()
	WorldState.save_checkpoint("station_1f", "cargo")
	await _frames(5)


func _test_alert_network() -> void:
	print("[alert network / calls / radio]")
	var net: AlertNetwork = _main.level.alert
	# 範圍外沒有同伴：叫了也沒人來
	_enable_all()
	_freeze(_watcher, _tile(3, 18), Vector2.UP)
	_freeze(_chimer, _tile(38, 3), Vector2.LEFT)
	_place_player(_spawn_pos(), false)
	await _frames(2)
	_watcher.awareness = 1.0
	_watcher._make_contact(_player.global_position)
	_watcher._set_state(Enemy.State.ALERT)
	await _frames(3)
	_check(_chimer.state == Enemy.State.UNAWARE, "叫聲傳不到的同伴不會來（%s）" % _chimer.get_state_name())
	_check(net.phase == AlertNetwork.Phase.ALERT, "有敵人追你 = ALERT")
	# 跟丟 → EVASION → CAUTION → 平常（敵人停住，只看警戒狀態怎麼變）
	_watcher._start_search(_watcher.global_position)
	_watcher.process_mode = Node.PROCESS_MODE_DISABLED
	_chimer.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(3)
	_check(net.phase == AlertNetwork.Phase.EVASION, "跟丟了 = EVASION")
	net.timer = 0.01
	await _frames(3)
	_check(net.phase == AlertNetwork.Phase.CAUTION, "搜索時間到 = CAUTION")
	_check(_watcher._vigilance_timer > 0.0, "CAUTION 時大家比較警覺")
	net.timer = 0.01
	await _frames(3)
	_check(net.phase == AlertNetwork.Phase.NONE, "CAUTION 結束回到平常")
	await _reset_world()

	# 人類：無線電通報（被打斷就失敗）、增援、開槍
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	var guard: Enemy = _main.spawn_enemy("guard", _tile(6, 6))
	var buddy: Enemy = _main.spawn_enemy("guard", _tile(38, 18))
	guard.ranged_accuracy = 1.0
	_place_player(_tile(11, 6), true, Vector2.LEFT)
	guard.facing = Vector2.RIGHT
	await _seconds(1.5)
	_check(guard.state == Enemy.State.ALERT, "人類看到你就警戒（%s）" % guard.get_state_name())
	_check(guard.radio_timer > 0.0 or net.radio_calls > 0, "發現你就拿起無線電")
	guard.take_damage(5.0, _player.global_position, 0.4)
	await _frames(3)
	_check(guard.radio_interrupted and net.radio_calls == 0, "通報途中被打中 = 通報失敗")
	_check(buddy.state == Enemy.State.UNAWARE, "通報失敗，遠處的同伴不知道")
	await _seconds(0.5)  # 等硬直結束（硬直中拿無線電會被打斷）
	guard._raise_alarm()
	await _seconds(guard.radio_time + 0.2)
	_check(net.radio_calls == 1, "沒被打斷就通報成功")
	_check(buddy.state == Enemy.State.ALERT, "通報成功，整個區域的人類都知道你在哪")
	var hp := WorldState.health
	guard._ranged_cd = 0.0
	await _seconds(1.2)
	_check(not guard.last_ranged.is_empty(), "人類會開槍")
	_check(WorldState.health < hp, "被打中會受傷")
	for e in [guard, buddy]:
		_main.enemies.erase(e)
		e.queue_free()
	WorldState.health = WorldState.MAX_HEALTH
	await _reset_world()
	_enable_all()


func _test_combo_and_cqc() -> void:
	print("[combat / combo, kick, grab]")
	var combat: PlayerCombat = _player.combat
	# 連段：刀 → 拳 → 踢（踢倒）
	_only(_watcher)
	_revive_watcher()
	_freeze(_watcher, _tile(12, 6), Vector2.DOWN)
	_watcher.max_health = 500.0
	_watcher.health = 500.0
	_place_player(_tile(12, 7), false, Vector2.UP)
	await _seconds(0.6)
	var moves := []
	for i in 3:
		_watcher.global_position = _tile(12, 6)
		await _press("fire")
		moves.append(combat.last_melee.get("move", ""))
		await _seconds(0.3)
	_check(moves == ["slash", "slash_back", "stab"], "拿刀連按 = 揮 → 反手揮 → 刺（%s）" % [moves])
	_check(not _watcher.knocked_down, "刀不會把人打倒")
	# 把刀收起來：刺拳 → 鉤拳 → 踢
	_main.set_melee("fists")
	_check(WorldState.melee() == "fists" and combat.melee_moves() == PlayerCombat.FIST_COMBO, "收刀 = 空手")
	await _seconds(0.8)
	moves = []
	for i in 3:
		_watcher.global_position = _tile(12, 6)
		await _press("fire")
		moves.append(combat.last_melee.get("move", ""))
		await _seconds(0.3)
	_check(moves == ["punch", "hook", "kick"], "空手連按 = 刺拳 → 鉤拳 → 踢（%s）" % [moves])
	_check(_watcher.knocked_down, "最後一腳把敵人踢倒")
	_check(_watcher.can_be_taken_down_by(_player), "倒地的敵人可以補刀")
	await _seconds(0.8)
	await _press("fire")
	_check(combat.last_melee.get("move", "") == "punch", "停頓太久，連段從頭開始")
	# 踢飛撞牆：額外受傷
	_freeze(_watcher, _tile(12, 2), Vector2.DOWN)
	_watcher.max_health = 500.0
	_watcher.health = 500.0
	_place_player(_tile(12, 3), false, Vector2.UP)
	await _seconds(0.6)
	combat.combo_step = 1
	combat._since_melee = 0.0
	var hp := _watcher.health
	Sfx.history.clear()
	await _press("fire")
	await _seconds(0.3)
	_check(Sfx.history.has("body_slam"), "踢到牆邊 = 撞牆")
	_check(hp - _watcher.health > 30.0, "撞牆額外受傷（%.0f）" % (hp - _watcher.health))
	_main.set_melee("knife")
	_check(WorldState.melee() == "knife" and combat.melee_moves() == PlayerCombat.KNIFE_COMBO, "把刀拔出來")
	# 擒拿：從背後抓住 → 摔倒；再抓 → 勒昏解決
	_revive_watcher()
	_freeze(_watcher, _tile(12, 6), Vector2.UP)  # 背對主角
	_place_player(_tile(12, 7), false, Vector2.UP)
	_player.sneaking = true
	await _frames(3)
	await _press("interact")
	_check(combat.grabbed == _watcher, "從背後按互動 = 抓住")
	_check(_watcher.state == Enemy.State.UNAWARE, "抓住的那一刻不會直接放開")
	await _seconds(0.3)
	_check(_watcher.global_position.distance_to(_player.global_position) < 14.0, "敵人被拖在面前")
	await _press("throw")
	_check(combat.grabbed == null and _watcher.knocked_down, "按投擲 = 摔在地上")
	await _seconds(0.2)
	await _press("interact")
	_check(combat.grabbed == _watcher, "倒地的敵人可以再抓起來")
	await _press("fire")
	_check(_watcher.is_dead, "抓住時攻擊 = 解決")
	# 太久沒動作，敵人掙脫
	_revive_watcher()
	_freeze(_watcher, _tile(12, 6), Vector2.UP)
	_place_player(_tile(12, 7), false, Vector2.UP)
	await _seconds(0.3)
	await _press("interact")
	combat._grab_timer = 0.05
	await _seconds(0.2)
	_check(combat.grabbed == null and _watcher.state == Enemy.State.ALERT, "抓太久敵人會掙脫並警戒")
	_player.sneaking = false
	_watcher.max_health = 80.0
	_revive_watcher()
	await _reset_world()


func _test_first_person() -> void:
	print("[locker, window, door peek (no first person)]")
	_only(_watcher)
	_freeze(_watcher, _tile(7, 5), Vector2.UP)
	_watcher.process_mode = Node.PROCESS_MODE_DISABLED
	_place_player(_tile(7, 2), false, Vector2.UP)
	await _frames(3)
	await _press("interact")
	_check(_player.is_hiding and _main._vignette.visible, "躲進櫃子：維持俯視，四周變暗")
	await _press("interact")
	_check(not _player.is_hiding and not _main._vignette.visible, "離開櫃子")
	# 窗戶：休息室和實驗室中間的觀察窗。站到窗邊就看得到另一邊的房間（不用互動、不換視角）
	var fog: RoomFog = _main.level.fog
	var lab_room: int = _main.level.room_of[_main.level.cell_of(_tile(24, 3))]
	_place_player(_tile(16, 3), false, Vector2.RIGHT)
	await _frames(4)
	_check(_player.peek_cells().is_empty(), "離窗戶遠：沒有從窗戶看進去")
	_place_player(_tile(18, 3), false, Vector2.RIGHT)
	await _frames(4)
	_check(_player.focus == null, "窗戶不用互動")
	_check(fog.visible_rooms.has(lab_room) and _player.peek_cells().has(_main.level.cell_of(_tile(23, 3))), "站在窗邊：看得到另一邊的房間")
	_check(_player.input_enabled, "看窗戶時照常可以移動")
	# 門：平常走過去自己開；潛行靠近不會開，可以推開一條縫看
	var door: InteriorDoor = null
	for d in _main.level.get_inner_doors():
		if d.access == 0 and not d.safe_door and d.is_horizontal():
			door = d
			break
	_check(door != null, "有室內門")
	if door:
		var cell: Vector2i = door.cell
		var below := "#C".find(_main.level.char_at(cell + Vector2i.DOWN)) < 0
		var side := Vector2(0, 16) if below else Vector2(0, -16)
		_place_player(door.global_position + side * 0.8, false, -side.normalized())
		await _seconds(0.3)
		_check(door.is_open, "平常走到門邊，門自己打開")
		_place_player(door.global_position + side * 3.0, false, -side.normalized())
		await _seconds(1.0)
		_check(not door.is_open, "離開後門關上")
		_place_player(door.global_position + side, false, -side.normalized())
		_player.sneaking = true
		await _seconds(0.4)
		_check(not door.is_open, "潛行靠近：門不會自己開")
		_check(_player.peek_candidate() == door, "可以把門推開一條縫")
		var far := door.global_position - side * 2.5
		_check(not _player.can_see_point(far), "門關著看不到裡面")
		_listen_noise()
		await _press("interact")
		_check(_player.peeking == door and door.ajar and not door.is_open, "按互動 = 門縫（門還是關著的）")
		_check(_noises.size() == 1 and _noises[0].radius <= 2.0 * Player.TILE, "門軸只響一小聲")
		_check(fog.visible_rooms.has(_main.level.room_of.get(_main.level.cell_of(door.global_position - side), -1)), "看得到門後面的房間")
		_check(_player.can_see_point(far), "從門縫看得到正前方")
		_check(not _player.can_see_point(door.global_position - side + Vector2(40, 0)), "門縫看不到旁邊（只有窄窄的扇形）")
		await _press("interact")
		_check(_player.peeking == null and not door.ajar, "再按一次：門關回去")
		Input.action_press("move_up" if below else "move_down")
		await _seconds(0.6)
		Input.action_release("move_up" if below else "move_down")
		_check(door.is_open, "潛行時往門推一下，門才打開")
		_player.sneaking = false
	await _reset_world()
	_enable_all()


func _test_phone() -> void:
	print("[phone]")
	var phone: Phone = _main.phone
	_main.show_message("TAPE (test): a very long message that should only show its beginning in the notification.")
	await _frames(2)
	_check(_main.message_log[0].begins_with("TAPE (test)"), "訊息記在手機裡")
	_check(_main._message_more.visible, "長訊息提示到手機看全文")
	# 物品鍵 = 格子背包（不是手機）
	var bag: BackpackPanel = _main.backpack
	WorldState.inv_add("med", 1)
	WorldState.inv_add("bottle", 2)
	await _press("inventory")
	_check(bag.visible and bag.mode == "bag" and not phone.visible and get_tree().paused, "物品鍵 = 打開格子背包（遊戲暫停）")
	var first: String = WorldState.inventory()[0].get("id", "")
	bag.zone = "bag"
	bag.cursor = 0
	await _press("reload")
	_check(bag.held == 0, "裝填鍵 = 把這一格拿起來")
	await _press("move_right")
	await _press("move_right")
	await _press("move_right")
	await _press("reload")
	_check(bag.held == -1 and WorldState.inventory()[3].get("id", "") == first and first != "", "放到別格 = 搬位置")
	WorldState.move_slot(3, 0)
	bag.zone = "kit"
	bag.cursor = 0
	await _press("interact")
	_check(WorldState.melee() == "fists", "隨身裝備：選小刀 = 收起來（空手）")
	await _press("interact")
	_check(WorldState.melee() == "knife", "再選一次 = 拔刀")
	await _press("inventory")
	_check(not bag.visible and not get_tree().paused, "再按物品鍵關掉背包")
	WorldState.inv_remove("med", 1)
	WorldState.inv_remove("bottle", 2)
	# 地圖鍵 = 全螢幕地圖（可以縮放）
	await _press("map")
	var mp: MapPanel = _main.map_panel
	_check(mp.visible and get_tree().paused and mp.map.get("player") != null, "地圖鍵 = 直接打開地圖，看得到自己的位置")
	var z0: int = mp.zoom_index
	mp.zoom_by(1)
	_check(mp.zoom_index == z0 + 1 or z0 == MapPanel.ZOOMS.size() - 1, "地圖可以放大")
	mp.zoom_by(-2)
	_check(mp.zoom_index < z0 + 1, "地圖可以縮小")
	await _press("map")
	_check(not mp.visible and not get_tree().paused, "再按一次關掉地圖")
	# 手機（P）：任務、訊息、檔案、地圖、裝備
	await _press("phone")
	_check(phone.visible and phone.app == "missions" and _main.mission_list.visible, "手機鍵 = 打開手機的任務 App")
	_check(get_tree().paused, "看手機時遊戲暫停")
	# 任務指引：選任務按確認 = 開／關箭頭；主線永遠黃色
	_check(WorldState.pin_main() and Missions.pinned().size() >= 1, "主線預設有指引箭頭")
	_check(Missions.pinned()[0].color == Missions.MAIN_COLOR, "主線的箭頭是黃色")
	_main.mission_list.cursor = 0
	await _press("interact")
	_check(not WorldState.pin_main(), "在任務清單按確認 = 關掉這個任務的箭頭")
	await _press("interact")
	_check(WorldState.pin_main(), "再按一次 = 打開")
	WorldState.toggle_pin("__side_a", false)
	WorldState.toggle_pin("__side_b", false)
	_check(WorldState.pinned_sides() == ["__side_a", "__side_b"], "可以同時勾好幾個支線")
	WorldState.toggle_pin("__side_a", false)
	WorldState.toggle_pin("__side_b", false)
	_check(Missions.SIDE_COLORS[0] != Missions.MAIN_COLOR and Missions.SIDE_COLORS[0] != Missions.SIDE_COLORS[1], "每個任務的顏色不同")
	await _press("move_right")
	_check(phone.app == "messages" and "very long message" in phone.get_text(), "訊息 App 看得到全文")
	await _press("move_left")
	await _press("move_left")
	_check(phone.app == "status" and "Condition" in phone.get_text(), "狀態 App")
	await _frames(20)
	_check(_main.map_pins(_main.level.area_id).size() > 0 or _main.mission_target(Missions.tracked_mission()).is_empty(), "主線標在地圖上（v0.11 起畫面上不畫箭頭）")
	_main.set_phone_app("map")
	_check(phone.app == "map", "地圖 App")
	_main.set_phone_app("gear")
	_check(phone.app == "gear" and "BODY" in "".join(phone.gear_header), "裝備 App（紙娃娃）")
	await _press("phone")
	_check(not phone.visible and not get_tree().paused, "再按手機鍵關掉手機")
	_check(not _main.get_node("HUD/Objective").visible and not _main.get_node("HUD/Hint").visible, "遊戲畫面上不擺目標和操作說明")


func _test_audio() -> void:
	print("[audio]")
	# 提示詞文件（給生成工具）和程式清單要一致
	var doc := FileAccess.get_file_as_string("res://docs/AUDIO_PROMPTS.md")
	var re := RegEx.new()
	re.compile("\\| `([a-z0-9_]+)` \\|")
	var doc_ids := {}
	for m in re.search_all(doc):
		doc_ids[m.get_string(1)] = true
	var ids := SoundList.all_ids()
	var missing_doc := ids.filter(func(id): return not doc_ids.has(id))
	var missing_code := doc_ids.keys().filter(func(id): return not ids.has(id))
	_check(missing_doc.is_empty(), "每個聲音都有提示詞 %s" % [missing_doc])
	_check(missing_code.is_empty(), "提示詞文件裡的聲音都在清單裡 %s" % [missing_code])
	var no_file := ids.filter(func(id): return not Sfx.has_file(id))
	_check(no_file.is_empty(), "每個聲音都有檔案（正式或暫代） %s" % [no_file])
	# 區域的音樂、環境音、腳步
	await _frames(2)
	_check(Sfx.current_music == "explore_outdoor", "戶外探索音樂")
	_check(Sfx.current_ambience == "amb_blizzard", "北極戶外是暴風雪環境音")
	_check(_main.level.step_surface(_player.global_position) == "snow", "戶外踩雪")
	Sfx.history.clear()
	Sfx.play("pistol_shot", _player.global_position)
	Sfx.play("not_a_sound")
	_check(Sfx.history == ["pistol_shot"], "播放會記錄；不在清單裡的不會播")


func _test_touch() -> void:
	print("[touch controls]")
	_check(not TouchControls.should_show(), "桌面版預設不顯示觸控介面")
	var tc: TouchControls = _main.touch_controls
	_check(tc != null, "有觸控介面")
	for action in ["fire", "aim", "interact", "item", "weapon", "dodge", "reload", "run", "sneak", "inventory", "map", "pause"]:
		var b := tc.button_for(action)
		if b == null:
			_check(false, "缺少觸控按鈕：" + action)
	_check(tc.buttons.size() >= 12, "每個操作都有觸控按鈕")
	_check(tc.buttons.all(func(b): return Rect2(0, 0, 480, 270).has_point(b.position)), "按鈕都在畫面內")
	tc.set_enabled(true)
	var joy := tc.joystick
	_quiet()
	_place_player(_tile(20, 12), false, Vector2.UP)
	var start := _player.global_position
	joy.touch_down(0, Vector2(60, 200))
	joy.touch_move(Vector2(100, 200))
	_check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"), "搖桿往右 = move_right")
	_check(is_equal_approx(Input.get_action_strength("move_right"), 1.0), "拉到底是全速")
	await _seconds(0.4)
	_check(_player.global_position.x > start.x + 10.0, "用搖桿走路")
	joy.touch_move(Vector2(70, 200))
	_check(Input.get_action_strength("move_right") < 0.5 and Input.is_action_pressed("move_right"), "輕推 = 慢慢走")
	joy.release()
	_check(not Input.is_action_pressed("move_right"), "放開搖桿就停")
	joy.touch_down(0, Vector2(60, 200))
	joy.touch_move(Vector2(62, 201))
	_check(not Input.is_action_pressed("move_right"), "中心附近有死區")
	joy.release()
	_main._toggle_inventory_panel()
	await _frames(2)
	_main.backpack.zone = "bag"
	_main.backpack.cursor = 0
	joy.touch_down(0, Vector2(60, 200))
	joy.touch_move(Vector2(100, 200))
	await get_tree().process_frame
	await get_tree().process_frame
	joy.release()
	_check(_main.backpack.cursor == 1, "背包裡用搖桿選格子")
	_main._toggle_inventory_panel()
	tc.set_enabled(false)


## 像素美術（tools/gen_pixel_art.py）：每個角色的動作都在、圖示齊全、站在牆前面時會畫在牆上面
func _test_pixel_art() -> void:
	print("[pixel art]")
	var needs := {
		"player": ["idle", "walk", "sneak", "aim_pistol", "aim_shotgun", "slash", "punch", "kick"],
		"watcher": ["walk", "idle", "attack"], "listener": ["walk", "listen", "attack"],
		"guard": ["walk", "idle", "aim", "hurt"], "hound": ["walk", "idle", "attack"],
		"crawler": ["walk", "attack"], "husk": ["walk", "attack", "hurt"], "chorister": ["walk", "listen", "attack"],
		"bear": ["walk", "idle", "attack", "hurt"],
	}
	var cs_p := CharacterSprite.new()
	cs_p.setup("player")
	_check(cs_p.sprite_frames.get_frame_count("walk_down") >= 8 and cs_p.sprite_frames.get_frame_count("kick_right") >= 6
		and cs_p.has_anim("shoot_shotgun") and cs_p.has_anim("hurt"), "動作格數夠多（走路 8 格、踢 6 格、開槍後座力、受傷）")
	cs_p.free()
	for obj in ["crate", "boards", "generator", "radio", "terminal", "storage_box", "snowcat", "oil_drum"]:
		_check(Art.tex("props/" + obj) != null, "物件像素圖 %s" % obj)
	for st in ["idle_0", "charge_5", "exposed_0", "dead_0"]:
		_check(Art.tex("well/" + st) != null, "深井的像素圖 %s" % st)
	for por in ["shen_fine", "shen_danger", "kovac", "gate"]:
		_check(Art.tex("portraits/" + por) != null, "頭像 %s" % por)
	for fx_id in ["slash_4", "hit_3", "impact_3", "smoke_3", "muzzle_big_2", "nail", "flare"]:
		_check(Art.tex("fx/" + fx_id) != null, "特效 %s" % fx_id)
	for id in needs:
		var cs := CharacterSprite.new()
		var ok := cs.setup(id)
		for anim in needs[id]:
			ok = ok and cs.has_anim(anim)
		_check(ok, "%s 的動作圖都在" % id)
		cs.free()
	var missing := []
	for item_id in Items.DATA:
		if Art.tex("props/" + item_id) == null:
			missing.append(item_id)
	_check(missing.is_empty(), "每個物品都有圖示 %s" % [missing])
	for fx in ["bullet", "pellet", "muzzle_0", "casing", "slash", "shadow"]:
		_check(Art.tex("fx/" + fx) != null, "特效圖 %s" % fx)
	# 找一格「北邊是牆」的地板：站在那裡的角色要畫在牆上面；北邊兩格都不是擋住的東西就不用
	var level: Level = _main.level
	var over: OverWall = level.get_node("OverWall").get_child(0)
	var front := Vector2i(-1, -1)
	var open_cell := Vector2i(-1, -1)
	for cell in level._floor_cells:
		var up := level.char_at(cell + Vector2i.UP)
		if up == "#" and front.x < 0:
			front = cell
		var clear := true
		for dy in [1, 2]:
			for dx in [-1, 0, 1]:
				if Level.OCCLUDER_CHARS.contains(level.char_at(cell + Vector2i(dx, -dy))):
					clear = false
		if clear and open_cell.x < 0:
			open_cell = cell
	var feet := (Vector2(front) + Vector2(0.5, 0.9)) * Level.TILE
	_check(front.x >= 0 and not over.mask_rects(feet).is_empty(), "站在牆前面：角色補畫在牆上面")
	_check(open_cell.x >= 0 and over.mask_rects((Vector2(open_cell) + Vector2(0.5, 0.9)) * Level.TILE).is_empty(),
		"前面沒有牆：不用補畫")


## 擴張：新區域（北港、冰洞、東翼）、新武器、圖鑑、過場
func _test_expansion() -> void:
	print("[expansion]")
	# 門要兩邊對得上
	for area_id in Areas.all():
		for door_id in Areas.all()[area_id].doors:
			var to: String = Areas.all()[area_id].doors[door_id].to
			_check(Areas.all().has(to) and Areas.all()[to].doors.has(door_id), "門 %s:%s 兩邊相通" % [area_id, door_id])
	for area_id in ["north_harbor", "ice_caves", "station_east_wing"]:
		var entry: String = Areas.all()[area_id].doors.keys()[0]
		await _enter(area_id, entry, false)
		_quiet()
		var types := {}
		for e in _main.enemies:
			types[e.get_species()] = true
		_check(_main.enemies.size() >= 4, "%s 有敵人（%s）" % [area_id, types.keys()])
		_check(_main.level.title != "", "%s 載入" % area_id)
	_check(not Areas.all().north_harbor.reinforcements.is_empty(), "北港有增援（無線電通報）")
	# 守門一號：廣場＋基地（安全屋合併進基地、有區域地圖、保險箱、多個房間）
	# 無縫：廣場、基地、安全屋是同一張地圖（Areas.rooms() 巢狀合併，房間裡也有敵人）
	_check(Areas.root_of("gate_one_safe") == "north_harbor", "安全屋→基地→廣場→冰洞→北港：同一張地圖")
	await _enter("gate_one_yard", "gate_tunnel", false)
	_quiet()
	var gate_enemies: Array = _main.enemies.filter(func(en): return en.enemy_key.begins_with("gate_one_"))
	_check(_main.level.area_id == "north_harbor" and gate_enemies.size() == 13, "廣場和基地的敵人一起載入（%d 隻）" % gate_enemies.size())
	var base := Areas.get_area("gate_one_base")
	var ids: Array = base.regions.map(func(r): return r.id)
	_check(ids.find("gate_one_safe") < ids.find("gate_one_base") and base.regions[ids.find("gate_one_safe")].safe, "安全屋在基地裡面（最裡面的範圍先比對）")
	var lobby := (Vector2(_at("gate_one_base", Vector2i(31, 31))) + Vector2(0.5, 0.5)) * Level.TILE
	var yard_pos := (Vector2(_at("gate_one_yard", Vector2i(31, 34))) + Vector2(0.5, 0.5)) * Level.TILE
	_check(_main.level.region_at(lobby) == "gate_one_base" and _main.level.is_indoor_at(lobby), "基地大廳是室內")
	_check(not _main.level.is_indoor_at(yard_pos), "廣場是戶外")
	_check(_main.level.exposure_at(yard_pos) > _main.level.exposure_at(lobby), "走進基地就不會失溫")
	var inside_safe := (Vector2(Areas.area_offset("gate_one_safe") + Vector2i(5, 3)) + Vector2(0.5, 0.5)) * Level.TILE
	_check(_main.level.is_safe_at(inside_safe), "安全屋的位置換算正確")
	# 從基地的門口直接走出廣場：不切換畫面
	_place_player(lobby, true, Vector2.DOWN)
	await _frames(2)
	var walk_area: String = _main.level.area_id
	_player.global_position = yard_pos
	await _frames(3)
	_check(_main.level.area_id == walk_area and _main.current_area_id() == "gate_one_yard", "走出基地＝同一張地圖，沒有切換區域")
	await _enter("gate_one_base", "base_gate", false)
	_quiet()
	_check(_main.current_area_id() == "gate_one_base", "從房間 id 載入：站在基地大廳")
	# 子彈穿薄牆：走廊往寢室開槍（中間一格牆）打得到；厚的外牆打不穿
	var cc := func(c: Vector2i) -> Vector2: return _tile(c.x, c.y)
	_place_player(cc.call(Vector2i(8, 9)), true, Vector2.UP)
	await _frames(1)
	var thin: Dictionary = _player.combat.trace_shot(_player.global_position, Vector2.UP, 170.0, [1, 0.55])
	_check(thin.holes.size() >= 1 and _main.level.cell_of(thin.holes[0]) == _at("gate_one_base", Vector2i(8, 8)) and thin.end.y < cc.call(Vector2i(8, 7)).y, "手槍穿過一格厚的牆（還有床鋪）")
	var thick: Dictionary = _player.combat.trace_shot(_player.global_position, Vector2.UP, 170.0, [0, 1.0])
	_check(thick.holes.is_empty() and thick.end.y > cc.call(Vector2i(8, 8)).y - 1.0, "不能穿牆的武器停在牆上")
	var dummy: Enemy = _main.enemies[0]
	dummy.process_mode = Node.PROCESS_MODE_DISABLED
	dummy.global_position = cc.call(Vector2i(8, 5))
	for other in _main.enemies:
		if other != dummy:
			other.global_position = cc.call(Vector2i(50, 28))
	var hp := dummy.health
	WorldState.inv_add("pistol", 1)
	WorldState.equipped = "pistol"
	WorldState.set_loaded("pistol", 8)
	_player.combat.target = null
	_player.combat._cooldown = 0.0
	_player.facing = Vector2.UP
	_check(_player.combat.shoot(), "對著牆開槍")
	_check(dummy.health < hp and _player.combat.last_shot.hit, "牆後的敵人被穿牆的子彈打中")
	_check(hp - dummy.health < PlayerCombat.WEAPONS.pistol.damage_min, "穿牆後傷害變小")
	dummy.process_mode = Node.PROCESS_MODE_INHERIT
	_check(base.entries.has("radio"), "守門一號安全屋有無線電入口")
	var rows: Array = base.map
	var joined := "".join(rows)
	_check(joined.contains("l") and joined.contains("s") and joined.count("+") >= 20, "基地有地圖、保險箱、很多室內門")
	var safe_area: Dictionary = Areas.all().gate_one_base.safes["46,2"]
	_check(Areas.all().gate_one_yard.hidden.values().has(safe_area.reveal), "基地保險箱的情報指向廣場的隱藏物品")
	# 圖鑑：看到就解鎖、打倒會記數
	var e: Enemy = _main.enemies[0]
	var sp := e.get_species()
	WorldState.data.codex.erase(sp)
	e.process_mode = Node.PROCESS_MODE_INHERIT
	_place_player(e.global_position + Vector2(0, 20), true, Vector2.UP)
	await _frames(4)
	_check(WorldState.codex_has(sp), "看到 %s：圖鑑解鎖" % sp)
	var kills := WorldState.codex_kills(sp)
	e.take_damage(9999.0, _player.global_position, 1.0)
	await _frames(2)
	_check(WorldState.codex_kills(sp) == kills + 1, "打倒：圖鑑記一次")
	_main.open_phone("codex")
	await _frames(1)
	_check(_main.phone.get_text() != "" and _main.phone.codex_header.size() >= 2, "手機的檔案 App 顯示圖鑑")
	_main.close_phone()
	# 信號槍：落點起火
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		f.queue_free()
	WorldState.inv_add("flare_gun", 1)
	WorldState.equipped = "flare_gun"
	WorldState.set_loaded("flare_gun", 1)
	_player.combat._cooldown = 0.0
	_check(_player.combat.shoot(), "信號槍可以開火")
	await _frames(2)
	_check(get_tree().get_nodes_in_group(Fire.GROUP).size() >= 1, "信號彈落點起火")
	WorldState.inv_remove("flare_gun", 1)
	# 消防斧：揮砍傷害變大
	_check(_player.combat.melee_weapon() == "", "沒有斧頭時用小刀")
	WorldState.inv_add("fire_axe", 1)
	_check(_player.combat.melee_weapon() == "", "撿到消防斧：還是拿刀，要自己換")
	_main.set_melee("fire_axe")
	_check(_player.combat.melee_weapon() == "fire_axe" and _player.combat.melee_moves()[0].get("smash", false), "換成消防斧：一下劈開木箱")
	WorldState.inv_remove("fire_axe", 1)
	_check(WorldState.melee() == "knife", "斧頭不在身上就自動換回小刀")
	# 新武器：左輪、衝鋒槍（連發）、十字弓（無聲、箭可以回收）
	_check(PlayerCombat.WEAPONS.smg.get("auto", false) and PlayerCombat.WEAPONS.smg.ammo == "ammo", "衝鋒槍連發、吃手槍子彈")
	_check(PlayerCombat.WEAPONS.revolver.damage_max > PlayerCombat.WEAPONS.pistol.damage_max * 2.0, "左輪威力大")
	_check(PlayerCombat.WEAPONS.crossbow.noise_tiles < 2.0 and PlayerCombat.WEAPONS.crossbow.get("retrieve", false), "十字弓沒聲音、箭可以回收")
	# 打火機＋可燃物 = 腳邊生一堆火取暖
	WorldState.inv_add("kindling", 1)
	var fires_before := get_tree().get_nodes_in_group(Fire.GROUP).size()
	_check(_player.use_item("kindling"), "用可燃物生火")
	await _frames(3)
	_check(get_tree().get_nodes_in_group(Fire.GROUP).size() == fires_before + 1 and WorldState.inv_count("kindling") == 0, "腳邊多一堆火")
	_check(Fire.warm_at(get_tree(), _player.global_position), "火堆旁邊是暖的")
	for f in get_tree().get_nodes_in_group(Fire.GROUP):
		f.put_out()
	await _frames(2)
	_check(PlayerCombat.WEAPONS.nailgun.noise_tiles < PlayerCombat.WEAPONS.pistol.noise_tiles * 0.3, "釘槍幾乎沒聲音")
	# 過場：暫停遊戲、黑邊、跳過後恢復
	WorldState.cutscenes = true
	WorldState.data.flags.erase("scene:clean_room")
	_main.play_cutscene("clean_room")
	await _frames(3)
	_check(_main.cutscene.active and get_tree().paused, "過場：遊戲暫停、黑邊出現")
	_main.cutscene.skip()
	await _seconds(0.8)
	_check(not _main.cutscene.active and not get_tree().paused, "跳過過場後恢復遊戲")
	_check(WorldState.has_flag("scene:clean_room"), "看過的過場不再播")
	WorldState.cutscenes = false


## 生存模式「長夜」：波次、分數、補給、撤離、殘響點數、解鎖、主線補給箱

## AFTERSIGNAL 改版：1962 年的記憶（燈籠站）、時代色調、霓虹燈、選項
func _test_aftersignal() -> void:
	print("[AFTERSIGNAL: 1962 memory / options / new infected]")
	await _enter("station_b1", "basement", false)
	_quiet()
	_level = _main.level
	var reel := _first(MemoryReel) as MemoryReel
	_check(reel != null and reel.target_area == "lantern_1962", "B1 有 1962 年的盤式錄音機")
	var medkit := _find_item(ItemPickup, Vector2i(23, 5))
	_check(medkit != null and not medkit.visible, "佐藤藏的急救包：還沒看過記憶時看不到")
	await _main._on_play_reel(reel.target_area, reel.target_entry, reel.scene, reel.flag)
	_off = Areas.area_offset("lantern_1962")
	_level = _main.level
	_quiet()
	_check(_main.level.area_id == "lantern_1962", "播放錄音帶 = 走進 1962 年的記憶")
	_check(is_equal_approx(_main.current_era(), 1.0), "1962 年的畫面是泛黃的老底片")
	_check(_main.enemies.size() == 3 and _main.enemies.all(func(en): return en.faction == "human"), "1962 年的敵人是三個士兵")
	_check(WorldState.checkpoint_area() == "lantern_1962", "被抓到會從記憶的開頭重來")
	var last := _find_item(MemoryReel, Vector2i(36, 2)) as MemoryReel
	_check(last != null and last.target_area == "station_b1", "錄音室的最後一捲帶子回到現在")
	await _main._on_play_reel(last.target_area, last.target_entry, last.scene, last.flag)
	_off = Areas.area_offset("station_b1")
	_level = _main.level
	_quiet()
	_check(_main.level.area_id == "station_b1" and is_equal_approx(_main.current_era(), 0.0), "回到 2026 年的地下室")
	_check(WorldState.has_flag("memory:lantern"), "記錄看過 1962 年的記憶")
	medkit = _find_item(ItemPickup, Vector2i(23, 5))
	_check(medkit != null and medkit.visible, "看完記憶：佐藤藏的急救包出現了")
	_main.set_era("2099")
	_check(is_equal_approx(_main.current_era(), 2.0), "2099 年的未來色調")
	_main.set_era("")
	# 選項（依 iOS 玩家評價加的）
	WorldState.set_option("assist", true, false)
	_check(is_equal_approx(WorldState.assist_mult(), 0.5), "輔助模式：受傷、雜訊減半")
	WorldState.set_option("assist", false, false)
	WorldState.set_option("battery_saver", true, false)
	_check(Engine.max_fps == 30, "省電模式：30 FPS")
	WorldState.set_option("battery_saver", false, false)
	_check(Engine.max_fps == 0, "關掉省電模式：不限 FPS")
	WorldState.set_option("left_handed", true, false)
	_check(_main.touch_controls.joystick.zone.position.x > 200.0, "左手模式：搖桿換到右邊")
	WorldState.set_option("left_handed", false, false)
	_check(_main.touch_controls.joystick.zone.position.x < 1.0, "右手模式：搖桿在左邊")
	_check(_main.sound_cues != null and WorldState.option("sound_cues"), "畫面聲音提示預設開啟")
	_main.options_panel.open()
	_check(_main.options_panel.visible, "暫停選單可以打開選項")
	_main.options_panel.close()
	_check(Missions.get_mission("lantern_1962").size() > 0, "支線：燈籠站，1962")
	# 新的感染體：狂奔者、噴孢者、冰甲巨人
	for t in ["runner", "spitter", "brute"]:
		var en: Enemy = _main.spawn_enemy(t, _player.global_position + Vector2(200, 0))
		_check(en != null and Codex.ENTRIES.has(en.get_species()) and Art.tex(t + "/walk_down_0") != null, "新感染體：%s（有圖、有圖鑑）" % t)
		if t == "spitter":
			_check(en.ranged_style == "spit" and en.ranged_infection > 0.0, "噴孢者：遠距離吐孢子，打中會感染")
		if t == "brute":
			en.facing = Vector2.LEFT
			var hp0 := en.health
			en.take_damage(20.0, en.global_position + Vector2.LEFT * 20.0, 0.3)
			var front := hp0 - en.health
			hp0 = en.health
			en.take_damage(20.0, en.global_position + Vector2.RIGHT * 20.0, 0.3)
			_check(front < 10.0 and hp0 - en.health > 19.0, "冰甲巨人：正面很硬，背後全額傷害")
		if t == "runner":
			_check(en.chase_speed > 100.0 and en.max_health < 60.0, "狂奔者：很快、很脆")
		_main.enemies.erase(en)
		en.queue_free()


## 潛龍諜影式的系統：多種視角、貼牆、戰術 HUD、Boss 階段、郵輪與典獄長
func _test_mgs_systems() -> void:
	print("[MGS-style views / bosses / cruise ship]")
	# ── 郵輪：北港的棧橋上船，甲板和船艙是同一張地圖 ──
	_check(Areas.get_area("north_harbor").doors.has("gangway"), "北港有往郵輪的棧橋")
	await _enter("cruise_deck", "gangway", false)
	_quiet()
	_level = _main.level
	_check(_main.level.area_id == "cruise_deck" and Areas.root_of("cruise_interior") == "cruise_deck", "郵輪甲板＋船艙是無縫地圖")
	_check(_main.enemies.size() >= 8, "郵輪上有敵人（甲板＋船艙）")
	# 鏡頭：不傾斜、不切固定機位，只有進小房間會推近
	_use("cruise_interior")
	_place_player(_tile(24, 13), true)
	await _frames(40)
	_check(_main._camera.frame_point == null and is_zero_approx(_main._tilt), "不切固定機位、畫面不傾斜")
	_place_player(_tile(10, 5), true)
	await _frames(30)
	_check(_main._camera.zoom_target >= 1.1, "客艙走廊：鏡頭推近（%.2f）" % _main._camera.zoom_target)
	_check(absf(_main._camera.zoom.x - _main._camera.zoom_target) < 0.25 and _main._camera.zoom.x > 1.0, "鏡頭是慢慢推近的")
	await _seconds(1.5)
	_check(is_equal_approx(_main._camera.zoom.x, _main._camera.zoom_target), "推到定位")
	# ── 貼牆：往牆推一下就背貼著牆，鏡頭往前推出去一點（不傾斜）──
	_place_player(_tile(10, 5), true, Vector2.UP)
	Input.action_press("move_up")
	await _seconds(1.0)
	_check(_player.wall_press == Vector2.DOWN, "往牆推 = 背貼牆（面向離開牆的方向）")
	await _frames(10)
	_check(_main._camera.wall_offset.y > 40.0 and is_zero_approx(_main._tilt), "貼牆：鏡頭往前推，不傾斜")
	Input.action_release("move_up")
	await _frames(3)
	_check(_player.wall_press == Vector2.ZERO, "放開方向就離開牆")
	# ── 戰術 HUD ──
	_main._pause_panel.visible = false
	get_tree().paused = false
	await _frames(2)
	_check(_main.tactical_hud != null and _main.tactical_hud.visible, "戰術 HUD（LIFE、道具框、武器框）")
	# ── 貨艙、頂層甲板 ──
	_check(Areas.get_area("cruise_deck").stairs.values().has("cruise_hold") and Areas.get_area("cruise_deck").stairs.values().has("cruise_sundeck"), "甲板的樓梯：往下貨艙、往上頂層甲板")
	await _enter("cruise_sundeck", "stairs", false)
	_level = _main.level
	var warden := _main.enemies[0] as BossWarden
	_check(warden != null and warden.is_boss(), "頂層甲板的 Boss：典獄長")
	for e in _main.enemies:
		e.process_mode = Node.PROCESS_MODE_DISABLED
	warden.process_mode = Node.PROCESS_MODE_INHERIT
	warden.reset()
	_place_player(warden.global_position + Vector2(0, 110), false)
	_player.sneaking = false
	var hp0 := WorldState.health
	await _seconds(2.4)
	_check(warden.shots_fired >= 1, "典獄長：雷射鎖定後開槍")
	_check(WorldState.health < hp0, "站在開闊處被狙擊到")
	_check(warden.phase == BossWarden.Phase.RELOAD or warden.phase == BossWarden.Phase.AIM, "開槍後要拉槍機")
	warden._set_phase(BossWarden.Phase.RELOAD)
	var h0 := warden.health
	warden.take_damage(20.0, _player.global_position, 0.0)
	_check(h0 - warden.health > 25.0, "拉槍機的時候受到的傷害比較高")
	warden.health = warden.max_health * 0.45
	warden.take_damage(1.0, _player.global_position, 0.0)
	_check(warden.stage == 2, "血量一半以下：第二階段（照明彈）")
	# 聲音騙他：看不到主角時，聽到聲音就把雷射轉過去
	warden._set_phase(BossWarden.Phase.AIM)
	_player.is_hiding = true
	var decoy := warden.global_position + Vector2(-60, 80)
	warden._on_noise(decoy, 6.0 * Level.TILE, null)
	_check(warden._noise_target != null, "看不到主角時，聲音會吸引他的槍口")
	_player.is_hiding = false
	WorldState.health = 100.0
	# ── 苔原之母的階段 ──
	await _enter("hangar", "snowcat", false)
	var bear := _main.enemies[0] as BossBear
	var events: Array = []
	bear.boss_event.connect(func(k, d): events.append(k))
	bear.health = bear.max_health * 0.6
	bear.take_damage(1.0, bear.global_position + Vector2(30, 0), 0.0)
	_check(bear.stage == 2 and events.has("phase") and events.has("icicle"), "苔原之母：狂暴（第二階段、冰柱掉下來）")
	bear.health = bear.max_health * 0.3
	bear.take_damage(1.0, bear.global_position + Vector2(30, 0), 0.0)
	_check(bear.stage == 3 and _main._boss_dark, "苔原之母：熄燈（第三階段、整個機庫變暗）")
	await _frames(2)
	_check(_main.level.get_children().any(func(n): return n is Icicle), "冰柱（落地前有影子預告）")
	_main.reset_attempt()
	_check(not _main._boss_dark and bear.stage == 1, "重來：燈恢復、Boss 回到第一階段")
	WorldState.health = 100.0
	# ── 深井的階段 ──
	await _enter("shaft_bottom", "stairs", false)
	var well: BossWell = null
	for e in _main.enemies:
		if e is BossWell:
			well = e
	if well:
		var n0: int = _main.enemies.size()
		well.health = well.max_health * 0.55
		well.take_damage(1.0 / well.armor_mult, _player.global_position, 0.0)
		_check(well.stage == 2, "深井：合唱回應了（第二階段）")
		well.pulse_count = 1
		well._pulse()
		_check(_main.enemies.size() == n0 + 2, "深井第二階段：脈衝後叫出兩隻狂奔者")
		_main.reset_attempt()
		_check(_main.enemies.size() == n0, "重來：叫出來的手下消失")
	else:
		_check(false, "井底有深井")
	WorldState.health = 100.0

func _test_survival() -> void:
	print("[survival]")
	WorldState.profile_path = "user://test_profile.cfg"
	WorldState.reset_profile()
	_check(not SurvivalData.map_unlocked("north_harbor") and SurvivalData.map_unlocked("station_1f"), "北港地圖要解鎖")
	_check(SurvivalData.wave_size(1) == 5 and SurvivalData.rank_for(30000) == "S", "波數、評價表")
	# 換成生存模式的主場景
	_main.queue_free()
	await _frames(2)
	WorldState.start_survival("station_1f", "pistol")
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	await _frames(10)
	var sv: SurvivalMode = _main.survival
	_check(sv != null and _main.enemies.is_empty(), "生存模式：沒有區域原本的敵人")
	_check(WorldState.inv_count("pistol") == 1 and WorldState.inv_count("med") >= 1, "起始裝備")
	sv.timer = 0.0
	await _frames(3)
	_check(sv.wave == 1 and _main.enemies.size() == SurvivalData.wave_size(1), "第 1 波刷出 %d 隻（%d）" % [SurvivalData.wave_size(1), _main.enemies.size()])
	var far := true
	for e in _main.enemies:
		if e.global_position.distance_to(_player.global_position) < 60.0:
			far = false
	_check(far, "敵人不會刷在玩家身邊")
	for e in _main.enemies:
		e.take_damage(9999.0, e.global_position, 1.0)
	await _frames(3)
	_check(sv.kills == 5 and sv.score >= 500 + SurvivalData.WAVE_BONUS, "擊倒＋過波獎勵（%d 分）" % sv.score)
	_check(sv.combo >= 2, "連殺倍率")
	var drops := 0
	for item in _main.level.get_interactables():
		if item.item_id.begins_with("survival:drop"):
			drops += 1
	_check(sv.phase == "break" and drops >= 2, "波間空投補給（%d 個）" % drops)
	_check(not sv.extract_open, "第 1 波後還不能撤離")
	# 第 5 波：深夜潮＋撤離
	sv.wave = 4
	sv.timer = 0.0
	await _frames(3)
	var types := {}
	for e in sv._alive:
		types[e.get_species()] = true
	_check(types.has("husk") and types.has("chorister"), "第 5 波深夜潮：膨脹者和詠者")
	for e in sv._alive.duplicate():
		e.take_damage(9999.0, e.global_position, 1.0)
	await _frames(3)
	_check(sv.extract_open and sv._extract != null, "第 5 波後出現撤離點")
	var before := WorldState.profile_points()
	var score := sv.score
	sv._extract.interact(_player)
	await _frames(3)
	_check(sv.phase == "over" and sv.result.extracted, "撤離成功")
	_check(WorldState.profile_points() == before + int(score * SurvivalData.POINTS_PER_SCORE), "撤離：殘響點數全拿（+%d）" % (WorldState.profile_points() - before))
	_check(_main.survival_results.visible and get_tree().paused, "結算畫面")
	_check(not WorldState.best_record("station_1f").is_empty(), "記錄最高分")
	get_tree().paused = false
	# 解鎖與主線補給箱
	WorldState.profile.points = 500
	_check(WorldState.buy_unlock("cache_1", SurvivalData.UNLOCKS.cache_1.cost), "用點數解鎖")
	_check(not WorldState.buy_unlock("cache_1", 0), "已經解鎖的不能再買")
	WorldState.start_story()
	WorldState.new_game()
	_check(WorldState.storage().get("med", 0) >= 1, "主線新遊戲：儲物箱裡有補給箱的東西")
	_check(WorldState.mode == "story", "回到主線模式")
	WorldState.reset_profile()


func _first(type: Variant) -> Interactable:
	for item in _main.level.get_interactables():
		if is_instance_of(item, type):
			return item
	return null


## 操作（背對自動瞄準、閃躲、快捷選單）、紙娃娃裝備、孢子區、地圖、保險箱
func _test_new_systems() -> void:
	print("[controls / gear / map]")
	await _enter("station_1f", "front", false)
	_quiet()
	_level = _main.level
	var e: Enemy = _main.enemies.filter(func(en): return en.enemy_key == "station_1f:1")[0]
	e.global_position = _tile(30, 7)
	e.is_dormant = false
	WorldState.inv_add("pistol", 1)
	WorldState.equipped = "pistol"
	_place_player(_tile(26, 7), true, Vector2.LEFT)
	await _frames(2)
	_check(_player.combat.find_targets().has(e), "背對敵人按瞄準也鎖定得到（可以邊後退邊開槍）")
	# 閃躲
	var p0 := _player.global_position
	_check(_player.dodge(Vector2.ZERO), "閃躲")
	var hp := WorldState.health
	_player.take_hit(20.0, 0.0, _player.global_position + Vector2(10, 0))
	_check(WorldState.health == hp, "跳開的時候不會被打到")
	await _seconds(0.4)
	_check(_player.global_position.x < p0.x - 25.0, "往面向快速跳開（%.0f px）" % (p0.x - _player.global_position.x))
	# 快捷選單
	WorldState.inv_add("med", 1)
	var ids: Array = _main.quick_items().map(func(x): return x.id)
	_check(ids.has("light") and ids.has("med"), "道具列：光源＋急救包")
	WorldState.data.quick_item = "med"
	WorldState.health = 40.0
	_main.use_quick_item()
	_check(WorldState.health > 40.0, "按一下道具鍵：用選好的急救包")
	WorldState.data.quick_item = "light"
	var lit := _player.flashlight_on
	_main.use_quick_item()
	_check(_player.flashlight_on != lit, "光源也在道具鍵裡（切換手電筒）")
	_player.flashlight_on = true
	_player._apply_flashlight()
	# 紙娃娃
	for id in ["eod_armor", "eod_helmet", "eod_boots", "hazmat_suit", "gas_mask", "hazmat_boots"]:
		WorldState.add_gear(id)
	WorldState.equip_gear("body", "eod_armor")
	_check(Gear.stat("armor") < 1.0 and Gear.stat("speed") < 1.0, "防爆裝甲：防禦大增、走路變慢")
	_check(_player._sprite.sprite_frames == CharacterSprite.load_frames("player_eod"), "穿上去外型跟著換")
	WorldState.equip_gear("head", "gas_mask")
	_check(_player._sprite._layers.size() == 1, "頭部裝備疊在角色上")
	_check(not WorldState.equip_gear("body", ""), "身體不能空著")
	WorldState.equip_gear("body", "hazmat_suit")
	WorldState.equip_gear("feet", "hazmat_boots")
	_check(Gear.full_set() == "hazmat" and Gear.stat("hazard") == 0.0, "防護套裝整套：完全不受孢子影響")
	# 孢子區
	await _enter("station_east_wing", "east_wing", false)
	_quiet()
	_level = _main.level
	_check(_level.hazard_at(_tile(23, 2)) == "spores", "東翼的實驗室有孢子")
	_place_player(_tile(23, 2), true, Vector2.UP)
	WorldState.infection = 0.0
	await _seconds(1.0)
	_check(WorldState.infection < 0.01, "穿著防護套裝：孢子沒影響")
	WorldState.equip_gear("body", "parka")
	WorldState.equip_gear("head", "")
	WorldState.equip_gear("feet", "snow_boots")
	await _seconds(1.0)
	_check(WorldState.infection > 1.0, "沒穿防護裝備：在孢子裡一直感染（%.1f）" % WorldState.infection)
	WorldState.infection = 0.0
	# 地圖：去過的地方、樓層地圖、主線方向
	# 地圖是一整張（二樓＋站長室＋東翼）：記在合併後的主地圖底下
	_check(WorldState.data.explored.has(Areas.root_of("station_east_wing")), "走過的地方記在地圖上")
	var map_item := _first(AreaMapPickup)
	_check(map_item != null, "每個區域都撿得到地圖")
	map_item.use(_player)
	_check(WorldState.has_flag("map:" + Areas.root_of("station_east_wing")), "撿到地圖 = 整張地圖顯示")
	_main.open_phone("map")
	await _frames(1)
	_check(_main.phone.map.known and _main.phone.map.title != "", "地圖 App 顯示這張地圖")
	_main.close_phone()
	var doors: Array[Vector2i] = _main.objective_doors("south_shore", "station_b1")
	_check(not doors.is_empty(), "主線方向：標出往目的地的門")
	# 保險箱 → 藍色星號
	await _enter("station_b1", "basement", false)
	_quiet()
	var safe := _first(SafeBox)
	_check(safe != null, "地下一樓有保險箱")
	safe.use(_player)
	_check(WorldState.has_flag("reveal:cache_caves"), "打開保險箱：解鎖隱藏要素的情報")
	WorldState.set_flag("map:" + Areas.root_of("ice_caves"))
	_main.open_phone("map")
	_main.map_view = Areas.root_of("ice_caves")
	_main._refresh_map()
	_check(_main.phone.map.stars.size() == 2, "地圖上出現藍色星號（%d）" % _main.phone.map.stars.size())
	_main.close_phone()
	# 新武器真的放在地圖上
	await _enter("ice_caves", "caves", false)
	_quiet()
	var rifle := false
	for item in _main.level.get_interactables():
		if item is ItemPickup and item.pickup_item == "rifle":
			rifle = true
	_check(rifle, "冰洞撿得到獵槍")
	for d in ["server_rack", "specimen_tank", "desk_row_m", "bunk_l", "blood_0", "monitor", "pipe"]:
		_check(Art.tex("decor/" + d) != null, "室內裝潢 %s" % d)


## 正式的地圖（scripts/world/areas.gd）：其他測試都在舊版的固定地圖上跑，這裡檢查正式地圖本身沒壞，
## 以及只跟正式地圖有關的新東西（開場在不冷的碼頭、起始配槍、消音器、道具放在容器裡、背後一擊的提示）。
func _test_real_maps() -> void:
	print("[real maps]")
	Areas.use_layout()
	var same_names := true
	var keys_ok := true
	var doors_ok := true
	var routes_ok := true
	for id in Areas.all():
		var a: Dictionary = Areas.all()[id]
		var old: Dictionary = LegacyAreas.DATA[id]
		for field in ["names", "gear", "stairs"]:
			# 和舊地圖比的是地圖本身（Areas.DATA），追加的調查點（Extras）另外由 _test_extras 檢查
			var x: Array = Areas.DATA[id].get(field, {}).values()
			var y: Array = old.get(field, {}).values()
			x.sort()
			y.sort()
			if str(x) != str(y):
				same_names = false
				print("    ", id, ".", field, " 不一樣：", x, " / ", y)
		for field in ["names", "hidden", "loot", "gear", "stairs", "safes", "reels"]:
			for key: String in a.get(field, {}):
				var p := key.split(",")
				var ch: String = String(a.map[int(p[1])])[int(p[0])]
				if "#.C".contains(ch):
					keys_ok = false
					print("    ", id, ".", field, " ", key, " 指到 ", ch)
		for d in a.doors:
			var to: String = a.doors[d].to
			var c: Vector2i = a.doors[d].cell
			if not Areas.all().has(to) or not Areas.all()[to].doors.has(d) or String(a.map[c.y])[c.x] != "D":
				doors_ok = false
				print("    ", id, " 的門 ", d)
		for e in a.get("enemies", []):
			for ch in String(e.get("route", "")):
				if Areas._find_char(a.map, ch).x < 0:
					routes_ok = false
		for row in a.map:
			if String(row).length() != String(a.map[0]).length():
				keys_ok = false
				print("    ", id, " 的地圖每列長度不一樣")
	_check(same_names, "正式地圖：任務物件、裝備、樓梯和舊地圖一樣多（沒有漏掉）")
	_check(keys_ok, "正式地圖：寫了座標的物件都真的在那一格")
	_check(doors_ok, "正式地圖：每扇門兩邊都接得起來")
	_check(routes_ok, "正式地圖：敵人的巡邏點都在")
	# 每張主地圖：所有走得到的地方連在一起、載入不出錯
	var connected := true
	var loaded := true
	for id in Areas.all():
		if Areas.rooms().has(id):
			continue
		var data := Areas.get_area(id)
		var open := {}
		for y in data.map.size():
			var row: String = data.map[y]
			for x in row.length():
				if not "#CH=~".contains(row[x]):
					open[Vector2i(x, y)] = true
		var seen := {}
		var stack: Array[Vector2i] = [open.keys()[0]]
		seen[stack[0]] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if open.has(c + d) and not seen.has(c + d):
					seen[c + d] = true
					stack.append(c + d)
		if seen.size() != open.size():
			connected = false
			print("    ", id, " 有 ", open.size() - seen.size(), " 格走不到")
		await _main.load_area(id, "", false)
		if _main.level == null or _main.enemies.size() != data.enemies.size():
			loaded = false
			print("    ", id, " 載入有問題")
	_check(connected, "正式地圖：每張地圖能走的地方都連在一起")
	_check(loaded, "正式地圖：每張地圖都能載入、敵人數量正確")
	# 開場：海閘碼頭（室內、不冷）、身上有配槍
	WorldState.start_loadout = true
	WorldState.new_game()
	_check(WorldState.inv_count("pistol") == 1 and WorldState.get_loaded("pistol") == 8 and WorldState.inv_count("ammo") == 16,
		"主線開始：身上有手槍（滿彈匣）和備彈")
	await _main.load_area(Areas.START_AREA, Areas.START_ENTRY, false)
	var lv: Level = _main.level
	var pos: Vector2 = _player.global_position
	_check(lv.is_indoor_at(pos) and lv.set_at(lv.cell_of(pos)) == "dock", "開場在海閘碼頭（水泥碼頭，不是雪地）")
	_check(lv.exposure_at(pos) <= 0.0 and not Climates.has_exposure(lv.climate_at(pos)), "碼頭不冷：不會失溫")
	_check(lv._water_cells.size() > 50 and lv.char_at(lv._water_cells[0]) == "~", "碼頭有水道（走不過去）")
	var depot := Areas.area_offset("fuel_depot")
	_check(not lv._is_indoor_cell(depot + Vector2i(4, 10)) and lv.set_at(depot + Vector2i(4, 10)) == "yard"
		and lv.exposure_at(lv._cell_center(depot + Vector2i(4, 10))) > 0.0, "燃料庫在戶外：雪地、會失溫")
	var st := Areas.area_offset("station_1f")
	_check(lv.set_at(st + Vector2i(8, 3)) == "mess" and lv.set_at(st + Vector2i(34, 3)) == "lab", "研究站一樓的房間各有用途（餐廳、實驗室……）")
	# 道具放在容器裡：拿走之後容器留著（打開）
	var med: ItemPickup = null
	for item in lv.get_interactables():
		if item is ItemPickup and item.pickup_item == "med" and item.enabled:
			med = item
			break
	_check(med != null and med.stash_art() == "medbox" and Art.tex("stash/medbox") != null, "急救包放在牆上的急救箱裡")
	if med:
		med.interact(_player)
		_check(WorldState.inv_count("med") == 1 and med.visible and not med.enabled, "拿走之後急救箱還在（空的），不能再拿")
	# 消音器
	WorldState.inv_add("suppressor", 1)
	_check(not WorldState.suppressor_on(), "消音器撿到時還沒裝上")
	_main._toggle_suppressor()
	_check(WorldState.suppressor_on() and PlayerCombat.SUPPRESSED_NOISE_TILES < PlayerCombat.WEAPONS.pistol.noise_tiles * 0.5,
		"裝上消音器：手槍的槍聲傳得近很多")
	var heard := [0.0]
	var on_noise := func(_p: Vector2, radius: float, _src: Node) -> void: heard[0] = maxf(heard[0], radius)
	NoiseBus.noise_emitted.connect(on_noise)
	WorldState.equipped = "pistol"
	_player.combat._cooldown = 0.0
	_player.combat.shoot()
	NoiseBus.noise_emitted.disconnect(on_noise)
	_check(is_equal_approx(heard[0], PlayerCombat.SUPPRESSED_NOISE_TILES * Player.TILE), "消音手槍開槍的聲音範圍 = 3.5 格")
	_main._toggle_suppressor()
	# 背後一擊的提示
	var foe: Enemy = _main.enemies[0]
	for e in _main.enemies:
		e.set_physics_process(e == foe)
	foe.global_position = pos + Vector2(40, 0)
	foe.facing = Vector2.RIGHT
	foe.state = Enemy.State.UNAWARE
	foe.awareness = 0.0
	_player.reset_to(foe.global_position + Vector2(-14, 0))
	_player.facing = Vector2.RIGHT
	_check(_player.combat.takedown_target() == foe, "潛行到敵人背後：出現「背後一擊」的對象")
	_player.reset_to(foe.global_position + Vector2(14, 0))
	_check(_player.combat.takedown_target() == null, "站在敵人正面：不能背後一擊")
	for e in _main.enemies:
		e.set_physics_process(false)
	# 換回測試用的固定地圖
	Areas.use_layout(LegacyAreas.DATA, LegacyAreas.ROOMS)
	WorldState.start_loadout = false
	WorldState.new_game()
	await _main.load_area(Areas.START_AREA, Areas.START_ENTRY, false)
	_enable_all()


## 主線無線電通話：完成主線任務之後，在無線電聽到柯瓦奇的話，每段只播一次
func _test_radio_calls() -> void:
	var ids := Missions.DATA.map(func(m): return m.id)
	_check(RadioCalls.DATA.all(func(c): return c.after in ids), "radio calls: every call follows a real mission")
	WorldState.data.flags.erase("call:find_shelter")
	var done_before := Missions.is_done("find_shelter")
	var first := RadioCalls.receive()
	var second := RadioCalls.receive()
	_check(second.is_empty(), "radio calls: each call plays once")
	_check(done_before == first.any(func(t): return t.contains("Frostchime")), "radio calls: only after the mission is done")


## v0.10：追加的調查點（Extras）、桌子、改裝件、藏寶圖
func _test_extras() -> void:
	Areas.use_layout()
	for id in Extras.DATA:
		var rows: Array = Areas.DATA[id].map
		for key in Extras.DATA[id]:
			var xy := String(key).split(",")
			_check(String(rows[int(xy[1])])[int(xy[0])] == ".", "extras: %s %s is a floor cell" % [id, key])
			var ex: Dictionary = Extras.DATA[id][key]
			if ex.kind == "mod":
				_check(Items.MODS.has(ex.id) and Art.tex("props/" + ex.id) != null, "extras: mod %s has data and an icon" % ex.id)
			elif ex.kind == "chart":
				_check(not Missions.get_mission(ex.mission).is_empty(), "extras: chart %s has a mission" % ex.id)
	for w in ["carbine", "harpoon"]:
		_check(Art.tex("props/" + w) != null and Items.DATA.has(w) and Codex.ENTRIES.has(w), "special weapon %s has icon, item and codex" % w)
	# 改裝件：加長彈匣、前握把
	_check(PlayerCombat.weapon_stats("pistol").mag == 8, "pistol magazine is 8 without the mod")
	WorldState.set_flag("mod:ext_mag")
	_check(PlayerCombat.weapon_stats("pistol").mag == 12 and PlayerCombat.weapon_stats("rifle").mag == 5, "extended magazine: pistol 12, rifle unchanged")
	WorldState.data.flags.erase("mod:ext_mag")
	# 藏寶圖任務：有旗標才出現，目標找得到
	_check(not Missions.is_available("cache_harpoon"), "cache mission hidden before the chart")
	WorldState.set_flag("reveal:harpoon")
	_check(Missions.is_available("cache_harpoon"), "cache mission appears after the chart")
	var t: Dictionary = _main.mission_target(Missions.get_mission("cache_harpoon"))
	_check(t.get("area", "") == Areas.root_of("north_harbor") and t.get("cell") != null, "cache mission points at the harbour shed")
	WorldState.data.flags.erase("reveal:harpoon")
	# 正式地圖：道具放在桌上，桌子不會把路堵死（check_maps 另外檢查連通）
	WorldState.cutscenes = false
	await _enter("station_1f", "front")
	var stands := 0
	var extra_seen := false
	for item in _main.level.get_interactables():
		if item is ItemPickup and item.stand != "":
			stands += 1
		if item is ExtraPickup:
			extra_seen = true
	_check(stands >= 3, "real map: pickups sit on stands (%d)" % stands)
	_check(extra_seen, "real map: the extended magazine is placed")
	# 新過場（站長室、恢復電力）在正式地圖上真的播得完：開始之後按跳過，確認會正常結束、旗標有設
	WorldState.cutscenes = true
	for id in ["director_office", "power_on"]:
		WorldState.data.flags.erase("scene:" + id)
		_main.play_cutscene(id)
		await _frames(20)
		var started: bool = _main.cutscene.active
		_main.cutscene.skipping = true
		for i in 240:
			if not _main.cutscene.active:
				break
			await _frames(1)
		_check(started and not _main.cutscene.active and WorldState.has_flag("scene:" + id) and not get_tree().paused,
			"cutscene %s starts, can be skipped, and hands control back" % id)
	WorldState.cutscenes = false
	Areas.use_layout(LegacyAreas.DATA, LegacyAreas.ROOMS)


## v0.11：天氣、雪地腳印、野戰無線電、雷達、全島地圖、箭頭不顯示
func _test_open_world() -> void:
	# 天氣：暴風雪讓戶外的敵人看不遠
	Weather.set_kind("blizzard")
	_check(is_equal_approx(float(Weather.value("sight")), 0.6) and float(Weather.value("cold")) > 1.0, "weather: blizzard cuts sight, adds cold")
	Weather.set_kind("snow")
	for id in FieldRadio.ENEMY:
		_check(Codex.ENTRIES.has(id), "field radio: enemy call %s matches a codex entry" % id)
	for id in FieldRadio.AREA:
		_check(Areas.all().has(id), "field radio: area call %s matches an area" % id)
	for id in Island.PLACES:
		for r in Island.PLACES[id].roots:
			_check(Areas.all().has(r) and Areas.root_of(r) == r, "island: %s is a root map" % r)
	# 腳印：在戶外雪地走路會留下腳印，敵人走過去會起疑
	Areas.use_layout()
	WorldState.cutscenes = false
	await _enter("south_shore", "start")
	var tracks: SnowTracks = _main.level.tracks
	var snow := Vector2i(-1, -1)
	for y in _main.level._map.size():
		for x in String(_main.level._map[y]).length():
			var c := Vector2i(x, y)
			if snow.x < 0 and _main.level.char_at(c) == "." and not _main.level._is_indoor_cell(c) and _main.level.floor_kind_at(c) == "snow" \
					and _main.level.char_at(c + Vector2i.RIGHT) == "." and _main.level.char_at(c + Vector2i(2, 0)) == ".":
				snow = c
	_check(snow.x >= 0, "tracks: found open snow next to the dock (fuel depot)")
	tracks.prints.clear()
	for i in 6:
		_player.global_position = (Vector2(snow) + Vector2(0.1 + i * 0.5, 0.5)) * Level.TILE
		tracks.step(_player)
	_check(tracks.prints.size() >= 3, "tracks: walking on snow leaves footprints (%d)" % tracks.prints.size())
	# 野戰無線電：排進來電、接起來會播、只響一次
	_main.radio_queue.clear()
	WorldState.data.flags.erase("fcall:test")
	_main.queue_radio("fcall:test", FieldRadio.steps([[FieldRadio.K, "test"]]))
	_main.queue_radio("fcall:test", FieldRadio.steps([[FieldRadio.K, "test"]]))
	_check(_main.radio_queue.size() == 1 and _main.radio_ringing(), "field radio: a call rings once")
	_main.answer_radio()
	await _frames(10)
	_main.cutscene.skipping = true
	for i in 240:
		if not _main.cutscene.active:
			break
		await _frames(1)
	_check(not _main.radio_ringing() and WorldState.has_flag("fcall:test") and not get_tree().paused, "field radio: answering plays the call")
	# 剛接完電話：提示類的來電先不響；主線的照響
	_main.queue_radio("fcall:test2", FieldRadio.steps([[FieldRadio.K, "test"]]))
	_check(not _main.radio_ringing(), "field radio: tips stay quiet right after a call")
	WorldState.data.flags.erase("call:__test")
	_main.queue_radio("call:__test", FieldRadio.steps([[FieldRadio.K, "test"]]))
	_check(_main.radio_ringing(), "field radio: story calls still ring")
	_main.radio_queue.clear()
	_main._radio_quiet = 0.0
	_check(_main._radio_call_steps(["KOVAC: \"x\""])[1].text == "x", "field radio: radio call text loses the speaker prefix")
	# 隨機事件：戶外的補給空投（走得到、標在地圖上）
	_player.global_position = (Vector2(snow) + Vector2(0.5, 0.5)) * Level.TILE
	await _frames(5)
	var drop: ItemPickup = _main.spawn_supply_drop()
	_check(drop != null and _main.map_data(_main.level.area_id).stars.has(_main.level.cell_of(drop.global_position)),
		"world event: a supply drop lands outdoors and is starred on the map")
	# 地圖：全島那一頁、箭頭不顯示
	var island: Dictionary = _main.map_data("island")
	_check(island.get("island", false) and island.places.station.here, "island map: you are at the station")
	_main._update_arrows(1.0)
	_check(not _main.objective_arrows.visible, "mission arrows are not drawn on screen")
	Areas.use_layout(LegacyAreas.DATA, LegacyAreas.ROOMS)


## v0.12：舉槍逼降、麻醉、屍體被發現、拖屍體藏進櫃子
func _test_stealth_v12() -> void:
	Areas.use_layout(LegacyAreas.DATA, LegacyAreas.ROOMS)
	WorldState.cutscenes = false
	await _enter("north_harbor", "harbor")
	var guards: Array = _main.enemies.filter(func(e): return is_instance_valid(e) and e.is_human() and not e.is_dead)
	_check(guards.size() >= 2, "stealth: the harbour has guards (%d)" % guards.size())
	if guards.size() < 2:
		return
	var g: Enemy = guards[0]
	# 舉槍逼降：從背後、近距離、拿著槍瞄準
	WorldState.inv_add("pistol", 1)
	WorldState.equipped = "pistol"
	g.state = Enemy.State.UNAWARE
	g.facing = Vector2.RIGHT
	_player.global_position = g.global_position - Vector2(30, 0)
	_player.combat.aiming = true
	_player.combat.target = g
	await _frames(3)
	_check(g.held_up, "hold-up: a guard aimed at from behind raises his hands")
	_player.combat.aiming = false
	_player.combat.target = null
	g.held_up = false
	# 麻醉：睡著、身上有把手可以拖
	g.put_to_sleep(30.0)
	await _frames(2)
	_check(g.is_asleep() and not g.is_dead, "tranquilliser: the guard falls asleep, alive")
	var handle: BodyHandle = null
	for i in _main.level.get_interactables():
		if i is BodyHandle and i.body == g:
			handle = i
	_check(handle != null, "a sleeping guard has a drag handle")
	# 被同伴看到 → 戒備
	var w: Enemy = guards[1]
	g.down_since = Time.get_ticks_msec()
	w.global_position = g.global_position + Vector2(-18, 0)
	w.facing = Vector2.RIGHT
	_main._check_bodies()
	_check(g.body_found and _main.level.alert.phase != AlertNetwork.Phase.NONE, "a guard who sees the body raises the caution")
	# 拖到櫃子旁邊塞進去
	if handle:
		handle.interact(_player)
		_check(_player.dragging == g, "dragging the body")
		_player.dragging = null
	g.stash()
	_check(g.stashed and not g.visible, "a body stashed in a locker disappears")
	_check(PlayerCombat.WEAPONS.has("dart_pistol") and Art.tex("props/dart_pistol") != null and Codex.ENTRIES.has("dart_pistol"), "tranquilliser has data, icon and codex")


## v0.13：用真的按鍵操作一次：舉槍逼降 → 麻醉 → 拖走 → 塞進櫃子
func _test_stealth_by_input() -> void:
	Areas.use_layout(LegacyAreas.DATA, LegacyAreas.ROOMS)
	WorldState.cutscenes = false
	await _enter("north_harbor", "harbor")
	var guards: Array = _main.enemies.filter(func(e): return is_instance_valid(e) and e.is_human() and not e.is_dead)
	if guards.is_empty():
		_check(false, "input stealth: no guards")
		return
	var g: Enemy = guards[0]
	for e in _main.enemies:
		if is_instance_valid(e) and e != g:
			e.global_position += Vector2(2000, 2000)  # 其他敵人先搬遠，自動鎖定才會鎖到他
	var locker: Locker = null
	for i in _main.level.get_interactables():
		if i is Locker and (locker == null or i.global_position.distance_to(g.global_position) < locker.global_position.distance_to(g.global_position)):
			locker = i
	WorldState.inv_add("dart_pistol", 1)
	WorldState.inv_add("darts", 4)
	WorldState.set_loaded("dart_pistol", 4)
	WorldState.equipped = "dart_pistol"
	g.state = Enemy.State.UNAWARE
	g.awareness = 0.0
	# 找一個「他背後、沒被牆擋住」的位置站
	var back := Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var spot: Vector2 = g.global_position - d * 28.0
		if _main.level.char_at(_main.level.cell_of(spot)) == "." and Sight.is_clear(g, g.global_position, spot):
			back = d
			break
	g.facing = back
	g.velocity = Vector2.ZERO
	_player.global_position = g.global_position - back * 28.0
	_player.facing = back
	Input.action_press("aim")
	await _frames(4)
	_check(g.held_up, "input: holding aim behind a guard makes him raise his hands")
	await _press("fire")
	await _frames(12)
	Input.action_release("aim")
	await _frames(2)
	_check(g.is_asleep(), "input: a dart puts him to sleep")
	_player.global_position = g.global_position - Vector2(10, 0)
	await _frames(2)
	await _press("interact")
	_check(_player.dragging == g, "input: interact next to the sleeper starts dragging")
	if locker and _player.dragging == g:
		_player.global_position = locker.global_position + Vector2(0, 14)
		await _frames(4)
		await _press("interact")
		_check(g.stashed and not _player.is_hiding, "input: interact by a locker stashes the body (and you don't hide)")
	WorldState.equipped = "pistol"
