## 生存模式「長夜」：在主線的地圖上一波一波撐下去（設計見 docs/SURVIVAL_MODE.md、資料見 SurvivalData）。
## main 在 WorldState.mode == "survival" 時建立這個節點：
##   波次刷怪（門口、玩家看不到的遠處）→ 敵人每隔幾秒「聽到」最近的玩家位置追過來
##   → 清完一波：過波獎勵、休息、身邊空投補給 → 每 5 波出現撤離點（撤離 = 獎勵全拿；死掉只帶回 30%）
## 多人預留：所有判斷都用 players() 這個清單（現在只有一個主角），之後加入其他玩家只要擴充它。
class_name SurvivalMode
extends Node

signal finished(result: Dictionary)

## 敵人每隔幾秒重新「聽到」玩家位置
const HUNT_INTERVAL := 5.0
## 刷怪點離玩家至少多遠
const SPAWN_MIN_DIST := 150.0

var main: Node
var map_id := ""
var wave := 0
## "break"（波間休息）、"fight"、"over"
var phase := "break"
var timer := 0.0
var score := 0
var kills := 0
var stealth_kills := 0
var combo := 0
var combo_timer := 0.0
var best_combo := 0
var extract_open := false
var result := {}

var _alive: Array[Enemy] = []
var _hunt := 0.0
var _hurt_this_wave := false
var _drop_count := 0
var _extract: SurvivalExtraction
var _hud: Label
var _banner: Label
var _rng := RandomNumberGenerator.new()


func setup(main_node: Node, map: String) -> void:
	main = main_node
	map_id = map
	_rng.seed = hash(map) + Time.get_ticks_msec()
	_hud = _label(Vector2(0, 4), 12, Color(0.92, 0.94, 0.96))
	_banner = _label(Vector2(0, 104), 24, Color(1.0, 0.85, 0.45))
	_banner.visible = false
	main.get_node("HUD").add_child(_hud)
	main.get_node("HUD").add_child(_banner)
	main._player.hurt.connect(func(_d): _hurt_this_wave = true)
	phase = "break"
	timer = 4.0
	_show_banner(tr("THE LONG NIGHT"), 3.0)


func _label(pos: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(480, font_size + 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 現在的玩家（多人模式時會有好幾個）
func players() -> Array[Player]:
	var out: Array[Player] = [main._player]
	return out


func nearest_player(pos: Vector2) -> Player:
	var best: Player = null
	for p in players():
		if p.is_dead:
			continue
		if best == null or p.global_position.distance_to(pos) < best.global_position.distance_to(pos):
			best = p
	return best


func _process(delta: float) -> void:
	if phase == "over" or main.level == null:
		return
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo = 0
	_check_kills()
	match phase:
		"break":
			timer -= delta
			if timer <= 0.0:
				_start_wave()
		"fight":
			_hunt -= delta
			if _hunt <= 0.0:
				_hunt = HUNT_INTERVAL
				for e in _alive:
					var p := nearest_player(e.global_position)
					if p and not p.is_hiding:
						e.answer_call(p.global_position)
			if _alive.is_empty():
				_wave_cleared()
	_update_hud()


# ── 波次 ──────────────────────────────────────────────

func _start_wave() -> void:
	wave += 1
	phase = "fight"
	_hunt = 1.0
	_hurt_this_wave = false
	_close_extraction()
	var types := wave_types(wave)
	for t in types:
		var e: Enemy = main.spawn_enemy(t, _spawn_point())
		_alive.append(e)
	_show_banner(tr("WAVE %d") % wave, 2.0)
	Sfx.play("alert_sting")


## 第 n 波要刷哪些敵人（權重隨機；深夜潮一定有膨脹者、詠者；北港混武裝人員）
func wave_types(n: int) -> Array[String]:
	var out: Array[String] = []
	var pool := []
	var total := 0
	for s in SurvivalData.SPAWNS:
		if n >= s.from:
			pool.append(s)
			total += s.weight
	if n % SurvivalData.EXTRACT_EVERY == 0:
		out.append_array(SurvivalData.SURGE)
	var humans := map_id in SurvivalData.HUMAN_MAPS
	while out.size() < SurvivalData.wave_size(n):
		if humans and _rng.randf() < 0.3:
			out.append("guard")
			continue
		var r := _rng.randi_range(1, total)
		for s in pool:
			r -= s.weight
			if r <= 0:
				out.append(s.type)
				break
	return out


## 刷怪點：門口、或離玩家夠遠而且看不到的地板
func _spawn_point() -> Vector2:
	var level: Level = main.level
	var candidates: Array[Vector2] = []
	for door in level._data.doors:
		candidates.append(level.get_entry_position(door))
	for i in 40:
		var c: Vector2i = level._floor_cells[_rng.randi_range(0, level._floor_cells.size() - 1)]
		var ch := level.char_at(c)
		if ch != "." or level.is_safe_cell(c):
			continue
		candidates.append((Vector2(c) + Vector2(0.5, 0.5)) * Level.TILE)
	candidates.shuffle()
	for pos in candidates:
		var ok := true
		for p in players():
			if p.global_position.distance_to(pos) < SPAWN_MIN_DIST or p.can_see_point(pos):
				ok = false
		if ok:
			return pos
	return candidates[0] if not candidates.is_empty() else level.get_entry_position(level._data.doors.keys()[0])


func _wave_cleared() -> void:
	var bonus := SurvivalData.WAVE_BONUS * wave
	if not _hurt_this_wave:
		bonus += SurvivalData.NO_DAMAGE_BONUS
	score += bonus
	Sfx.play("mission_complete")
	_drop_supplies()
	if wave % SurvivalData.EXTRACT_EVERY == 0:
		phase = "break"
		timer = SurvivalData.EXTRACT_BREAK_TIME
		_open_extraction()
		_show_banner(tr("WAVE %d CLEAR - EXTRACTION OPEN") % wave, 3.0)
	else:
		phase = "break"
		timer = SurvivalData.BREAK_TIME
		_show_banner(tr("WAVE %d CLEAR  +%d") % [wave, bonus], 2.0)


# ── 擊倒、分數 ─────────────────────────────────────────

func _check_kills() -> void:
	for e in _alive.duplicate():
		if not is_instance_valid(e):
			_alive.erase(e)
			continue
		if not e.is_dead:
			continue
		_alive.erase(e)
		_on_kill(e)


func _on_kill(e: Enemy) -> void:
	kills += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_timer = SurvivalData.COMBO_WINDOW
	var base: float = SurvivalData.KILL_SCORE.get(e.get_species(), 100)
	var mult := multiplier()
	var swing: Dictionary = main._player.combat.last_melee
	if not swing.is_empty() and swing.t < 0.5 and swing.takedown:
		mult *= SurvivalData.STEALTH_MULT
		stealth_kills += 1
	score += int(base * mult)


func multiplier() -> float:
	return minf(1.0 + SurvivalData.COMBO_STEP * maxi(combo - 1, 0), SurvivalData.COMBO_MAX)


# ── 補給、撤離 ─────────────────────────────────────────

func _drop_supplies() -> void:
	var level: Level = main.level
	var choices := []
	for s in SurvivalData.SUPPLIES:
		if wave >= s[2]:
			choices.append(s)
	var n := 2 + wave / 4
	var around: Vector2 = main._player.global_position
	for i in n:
		var s: Array = choices[_rng.randi_range(0, choices.size() - 1)]
		var pickup := ItemPickup.new()
		pickup.pickup_item = s[0]
		pickup.pickup_count = s[1]
		_drop_count += 1
		pickup.item_id = "survival:drop:%d" % _drop_count
		pickup.position = _free_spot_near(around)
		level.add_interactable(pickup)
	Sfx.play("pickup_item")


func _free_spot_near(pos: Vector2) -> Vector2:
	var level: Level = main.level
	var c := level.cell_of(pos)
	for r in range(1, 5):
		var cells: Array[Vector2i] = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if level.char_at(cc) == "." and cc != c:
					cells.append(cc)
		if not cells.is_empty():
			return (Vector2(cells[_rng.randi_range(0, cells.size() - 1)]) + Vector2(0.5, 0.5)) * Level.TILE
	return pos


func _open_extraction() -> void:
	extract_open = true
	var level: Level = main.level
	_extract = SurvivalExtraction.new()
	_extract.position = level.get_entry_position(SurvivalData.MAPS[map_id].entry)
	_extract.item_id = "survival:extract"
	_extract.extracted.connect(func(): finish(true))
	level.add_interactable(_extract)


func _close_extraction() -> void:
	extract_open = false
	if _extract and is_instance_valid(_extract):
		if main._player.focus == _extract:
			main._player.focus = null
		main.level._interactables.erase(_extract)
		_extract.queue_free()
	_extract = null


# ── 結束 ──────────────────────────────────────────────

## 撤離成功（extracted）或死掉：算殘響點數、記錄、顯示結算
func finish(extracted: bool) -> void:
	if phase == "over":
		return
	phase = "over"
	_close_extraction()
	var keep := 1.0 if extracted else SurvivalData.DEATH_KEEP
	var points := int(score * SurvivalData.POINTS_PER_SCORE * keep)
	var waves_done := wave if extracted else maxi(wave - 1, 0)
	var rank := SurvivalData.rank_for(score)
	WorldState.add_points(points)
	var record := WorldState.record_best(map_id, score, waves_done, rank)
	result = {"extracted": extracted, "score": score, "wave": waves_done, "kills": kills, "stealth": stealth_kills,
		"combo": best_combo, "rank": rank, "points": points, "record": record, "map": map_id}
	_hud.visible = false
	_banner.visible = false
	finished.emit(result)


func _update_hud() -> void:
	var line := tr("WAVE %d") % wave if wave > 0 else tr("GET READY")
	line += "   " + tr("SCORE %d") % score
	if combo > 1:
		line += "   x%.2f" % multiplier()
	if phase == "break" and timer > 0.0:
		line += "   " + tr("NEXT %d") % ceili(timer)
	elif phase == "fight":
		line += "   " + tr("LEFT %d") % _alive.size()
	if extract_open:
		line += "   " + tr("[EXTRACT]")
	_hud.text = line


func _show_banner(text: String, time: float) -> void:
	_banner.text = text
	_banner.visible = true
	var shown := text
	get_tree().create_timer(time).timeout.connect(func():
		if _banner.text == shown:
			_banner.visible = false)
