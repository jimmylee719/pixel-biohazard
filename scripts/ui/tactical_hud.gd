## 戰術 HUD（參考潛龍諜影的配置，畫面風格原創）：左上角 LIFE（生命）＋ TEMP（體溫，冷的地方才出現），
## 左下角＝道具框（道具鍵會用的東西），右下角＝武器框（圖示＋彈匣／備彈）。
## 觸控版下面有按鈕：兩個框移到右上角。手機打開、過場、結局時不顯示（main 控制 visible）。
class_name TacticalHud
extends Control

const BOX := Vector2(58, 30)
const FRAME := Color(0.55, 0.62, 0.66, 0.85)
const BG := Color(0.02, 0.03, 0.04, 0.72)
const TEXT := Color(0.85, 0.9, 0.92)

var main: Node
var touch := false
var _font: Font
var _hurt_flash := 0.0
var _last_hp := 100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_font = load("res://assets/fonts/Cubic_11.ttf")


func _process(delta: float) -> void:
	if main:
		visible = not main.phone.visible and not (main.cutscene and main.cutscene.active) \
			and not main._ending_panel.visible and not main.backpack.visible and not main.map_panel.visible \
			and not main._radio_panel.visible and not main._storage_panel.visible and not main._inventory_panel.visible \
			and not main._signal_panel.visible and not main._pause_panel.visible \
			and not (main.options_panel and main.options_panel.visible)
	var hp: float = WorldState.health
	if hp < _last_hp - 0.5:
		_hurt_flash = 0.6
	_last_hp = hp
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if main == null or main._player == null:
		return
	# 用畫面實際的大小（不是這個節點的 size：掛在 CanvasLayer 底下時，視窗改大小不一定會跟著更新，
	# 兩個框就會跑到畫面外面或中間）
	var view := get_viewport_rect().size
	var w := view.x
	var h := view.y
	# ── 左上：LIFE ──
	var hp := clampf(WorldState.health / 100.0, 0.0, 1.0)
	var top := 24.0 if not touch else 54.0
	_text(Vector2(6, top + 9), "LIFE", Color(0.7, 0.78, 0.8))
	var bar := Rect2(38, top + 3, 72, 5)
	draw_rect(bar.grow(1), Color(0, 0, 0, 0.8))
	var col := Color(0.35, 0.85, 0.55).lerp(Color(0.95, 0.25, 0.2), 1.0 - hp)
	if _hurt_flash > 0.0 and int(_hurt_flash * 20.0) % 2 == 0:
		col = Color(1, 1, 1)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)), col)
	draw_rect(bar.grow(1), FRAME, false, 1.0)
	# 感染（細的紫色線，在 LIFE 下面）
	var inf := clampf(WorldState.infection / WorldState.MAX_INFECTION, 0.0, 1.0)
	if inf > 0.01:
		draw_rect(Rect2(38, top + 10, 72 * inf, 1), Color(0.75, 0.45, 0.95))
	# 體溫（冷的地方才出現）
	var lv: Level = main.level
	if lv and Climates.has_exposure(lv.climate_at(main._player.global_position)):
		var t := clampf(WorldState.body_temp / 100.0, 0.0, 1.0)
		_text(Vector2(6, top + 21), "TEMP", Color(0.6, 0.75, 0.85))
		var tb := Rect2(38, top + 15, 72, 3)
		draw_rect(tb.grow(1), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(tb.position, Vector2(tb.size.x * t, tb.size.y)), Color(0.4, 0.75, 1.0).lerp(Color(0.85, 0.95, 1.0), 1.0 - t))
	# ── 道具框、武器框 ──
	var item_at := Vector2(6, h - BOX.y - 6) if not touch else Vector2(w - BOX.x * 2 - 12, 6)
	var weap_at := Vector2(w - BOX.x - 6, h - BOX.y - 6) if not touch else Vector2(w - BOX.x - 6, 6)
	_draw_item_box(item_at)
	_draw_weapon_box(weap_at)


func _draw_item_box(at: Vector2) -> void:
	var id: String = WorldState.data.get("quick_item", "light")
	var icon: Texture2D = Art.tex("props/flashlight") if id == "light" else Art.tex("props/" + id)
	var label := tr("LIGHT") if id == "light" else Items.display_name(id)
	var count := -1 if id == "light" else WorldState.inv_count(id)
	_box(at, icon, label, "" if count < 0 else "x%d" % count)


func _draw_weapon_box(at: Vector2) -> void:
	var combat: PlayerCombat = main._player.combat
	var weapon := combat.current_weapon()
	var melee := WorldState.melee()
	var melee_name := tr("Bare hands") if melee == "fists" else Items.display_name(melee)
	if weapon == "":
		_box(at, Art.tex("props/" + melee), melee_name, "")
		return
	var ammo := "%d / %d" % [WorldState.get_loaded(weapon), WorldState.inv_count(combat.stats().ammo)]
	if combat.reloading:
		ammo = tr("RELOAD")
	_box(at, Art.tex("props/" + weapon), Items.display_name(weapon), ammo)
	# 近戰用什麼：武器框上面一個小圖（小刀／拳頭／斧頭／鐵撬）
	var mi := Art.tex("props/" + melee)
	if mi:
		var k := minf(1.0, minf(14.0 / mi.get_width(), 10.0 / mi.get_height()))
		var r := Rect2(at + Vector2(BOX.x - 18, -13), Vector2(18, 12))
		draw_rect(r, BG)
		draw_rect(r, Color(FRAME, 0.5), false, 1.0)
		var sz := (mi.get_size() * k).floor()
		draw_texture_rect(mi, Rect2((r.get_center() - sz * 0.5).floor(), sz), false)
	if weapon == "pistol" and WorldState.suppressor_on():
		# 消音器：武器框右上角標 SUP
		draw_rect(Rect2(at + Vector2(BOX.x - 24, 2), Vector2(22, 9)), Color(0.1, 0.12, 0.14, 0.9))
		draw_string(_font, at + Vector2(BOX.x - 23, 10), "SUP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.9, 0.75))


func _box(at: Vector2, icon: Texture2D, label: String, sub: String) -> void:
	var r := Rect2(at, BOX)
	draw_rect(r, BG)
	draw_rect(r, FRAME, false, 1.0)
	# 左上角的小切角（軍用儀器的感覺）
	draw_rect(Rect2(at, Vector2(5, 1)), TEXT)
	draw_rect(Rect2(at, Vector2(1, 5)), TEXT)
	if icon:
		var s := icon.get_size()
		var k := minf(1.0, minf(22.0 / s.x, 16.0 / s.y))
		var isz := (s * k).floor()
		draw_texture_rect(icon, Rect2((at + Vector2(4, 3)).floor(), isz), false)
	_text(at + Vector2(28, 12), sub, TEXT)
	var short := label if label.length() <= 8 else label.substr(0, 8)
	_text(at + Vector2(4, BOX.y - 3), short, Color(0.65, 0.72, 0.75))


func _text(at: Vector2, s: String, c: Color) -> void:
	draw_string(_font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
