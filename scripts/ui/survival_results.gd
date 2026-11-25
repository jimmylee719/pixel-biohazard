## 生存模式的結算畫面：撤離／陣亡、分數、波數、擊倒、評價、帶回的殘響點數。
## 再玩一次（同一張地圖、同樣的裝備）／生存選單／標題。遊戲暫停中也能操作。
class_name SurvivalResults
extends PanelContainer

signal retry
signal to_menu
signal to_title

var _text: Label
var _retry: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.07, 0.94)
	style.border_color = Color(0.45, 0.55, 0.6)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 12)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	_retry = _button(box, tr("Run it again"), func(): retry.emit())
	_button(box, tr("Survival menu"), func(): to_menu.emit())
	_button(box, tr("Title screen"), func(): to_title.emit())
	visible = false


func _button(box: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func show_result(r: Dictionary) -> void:
	var lines: Array[String] = []
	lines.append(tr("EXTRACTED") if r.extracted else tr("LOST IN THE NIGHT"))
	lines.append(tr(SurvivalData.MAPS[r.map].name))
	lines.append(tr("Rank  %s") % r.rank + ("   " + tr("NEW RECORD") if r.record else ""))
	lines.append(tr("Score  %d") % r.score)
	lines.append(tr("Waves survived  %d") % r.wave)
	lines.append(tr("Kills  %d   (silent %d)") % [r.kills, r.stealth])
	lines.append(tr("Best combo  %d") % r.combo)
	lines.append(tr("Echoes earned  +%d%s") % [r.points, "" if r.extracted else "  " + tr("(30% - you did not make it out)")])
	lines.append(tr("Echoes total  %d") % WorldState.profile_points())
	_text.text = "\n".join(lines)
	visible = true
	position = (Vector2(480, 270) - get_combined_minimum_size()) * 0.5
	_retry.grab_focus()
