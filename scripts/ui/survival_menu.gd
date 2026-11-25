## 生存模式「長夜」的選單：選地圖、起始武器，用殘響點數解鎖武器／地圖／主線補給。
## 全部是按鈕：滑鼠、觸控、鍵盤、手把都能操作。
extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"

var map := "station_1f"
var weapon := "pistol"

var _points: Label
var _desc: Label
var _map_buttons := {}
var _weapon_button: Button
var _shop_buttons := {}
var _start: Button


func _ready() -> void:
	get_tree().paused = false
	WorldState.start_story()
	Sfx.play_music("title")
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := _label(tr("THE LONG NIGHT"), 24, Color(1.0, 0.85, 0.45))
	title.position = Vector2(16, 6)
	add_child(title)
	_points = _label("", 12, Color(0.55, 0.95, 0.75))
	_points.position = Vector2(300, 14)
	_points.size = Vector2(164, 14)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_points)

	var left := VBoxContainer.new()
	left.position = Vector2(16, 40)
	left.size = Vector2(212, 180)
	left.add_theme_constant_override("separation", 3)
	add_child(left)
	left.add_child(_label(tr("MAP"), 12, Color(0.6, 0.7, 0.75)))
	for id in SurvivalData.MAPS:
		var b := _button(left, "")
		b.pressed.connect(_pick_map.bind(id))
		b.focus_entered.connect(func(): _describe(tr(SurvivalData.MAPS[id].desc)))
		_map_buttons[id] = b
	left.add_child(_label(tr("LOADOUT"), 12, Color(0.6, 0.7, 0.75)))
	_weapon_button = _button(left, "")
	_weapon_button.pressed.connect(_next_weapon)
	_weapon_button.focus_entered.connect(func(): _describe(tr("Your second weapon. The pistol and the knife always come along.")))
	_start = _button(left, tr("Begin the night"))
	_start.pressed.connect(_begin)
	_start.focus_entered.connect(func(): _describe(tr("Survive the waves. Every 5th wave you can extract and keep everything - die, and you keep 30%.")))
	var back := _button(left, tr("Back"))
	back.pressed.connect(func(): get_tree().change_scene_to_file(TITLE_SCENE))

	var right := VBoxContainer.new()
	right.position = Vector2(244, 40)
	right.size = Vector2(220, 180)
	right.add_theme_constant_override("separation", 2)
	add_child(right)
	right.add_child(_label(tr("UNLOCK (echoes)"), 12, Color(0.6, 0.7, 0.75)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	right.add_child(grid)
	for id in SurvivalData.UNLOCKS:
		var b := _button(grid, "")
		b.custom_minimum_size.x = 108
		b.clip_text = true
		b.pressed.connect(_buy.bind(id))
		b.focus_entered.connect(func():
			var u: Dictionary = SurvivalData.UNLOCKS[id]
			_describe("%s（%d）：%s" % [tr(u.name), u.cost, tr(u.desc)]))
		_shop_buttons[id] = b

	_desc = _label("", 12, Color(0.8, 0.85, 0.9))
	_desc.position = Vector2(16, 232)
	_desc.size = Vector2(448, 32)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_desc)
	if WorldState.survival_setup.has("map"):
		map = WorldState.survival_setup.map
		weapon = WorldState.survival_setup.weapon
	_refresh()
	_start.grab_focus()


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(parent: Container, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	return b


func _describe(text: String) -> void:
	_desc.text = text


func _pick_map(id: String) -> void:
	if not SurvivalData.map_unlocked(id):
		Sfx.play("door_locked")
		_describe(tr("Locked. Unlock it on the right."))
		return
	map = id
	Sfx.play("ui_confirm")
	_refresh()


func _next_weapon() -> void:
	var ids := SurvivalData.LOADOUTS.keys()
	var i := ids.find(weapon)
	for step in range(1, ids.size() + 1):
		var w: String = ids[(i + step) % ids.size()]
		if SurvivalData.loadout_unlocked(w):
			weapon = w
			break
	Sfx.play("ui_move")
	_refresh()


func _buy(id: String) -> void:
	var u: Dictionary = SurvivalData.UNLOCKS[id]
	if WorldState.buy_unlock(id, u.cost):
		Sfx.play("mission_complete")
		_describe(tr("Unlocked: %s") % tr(u.name))
	else:
		Sfx.play("door_locked")
		_describe(tr("Already yours.") if WorldState.is_unlocked(id) else tr("Not enough echoes."))
	_refresh()


func _begin() -> void:
	WorldState.start_survival(map, weapon)
	get_tree().change_scene_to_file(GAME_SCENE)


func _refresh() -> void:
	_points.text = tr("Echoes: %d") % WorldState.profile_points()
	for id in _map_buttons:
		var m: Dictionary = SurvivalData.MAPS[id]
		var b: Button = _map_buttons[id]
		var best := WorldState.best_record(id)
		var text := ("> " if id == map else "  ") + tr(m.name)
		if not SurvivalData.map_unlocked(id):
			text += "  " + tr("(locked)")
		elif not best.is_empty():
			text += "  %s %d  W%d" % [best.rank, best.score, best.wave]
		b.text = text
	_weapon_button.text = tr("Weapon: %s") % Items.display_name(weapon)
	for id in _shop_buttons:
		var u: Dictionary = SurvivalData.UNLOCKS[id]
		var b: Button = _shop_buttons[id]
		b.text = (tr("[owned] ") if WorldState.is_unlocked(id) else "%d " % u.cost) + tr(u.name)
		b.disabled = false
