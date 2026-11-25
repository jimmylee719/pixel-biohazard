## 選項畫面（標題畫面、暫停選單都能開）。全部用按鈕（點一下切換／循環），觸控、滑鼠、鍵盤、手把都能操作。
## 設定值存在 WorldState.options（settings.cfg）。
class_name OptionsPanel
extends PanelContainer

signal closed

const STEPS := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
const OPACITY_STEPS := [0.12, 0.22, 0.35, 0.5]

var _box: VBoxContainer
var _buttons := {}
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.07, 0.97)
	style.border_color = Color(0.24, 0.96, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	set_anchors_preset(Control.PRESET_CENTER)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 3)
	add_child(_box)
	var title := Label.new()
	title.text = tr("OPTIONS")
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	for key in ["music", "sfx", "sound_cues", "assist", "touch_opacity", "left_handed", "battery_saver"]:
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_cycle.bind(key))
		_box.add_child(b)
		_buttons[key] = b
	_back = Button.new()
	_back.add_theme_font_size_override("font_size", 12)
	_back.text = tr("Back")
	_back.pressed.connect(close)
	_box.add_child(_back)
	_refresh()
	visible = false


func open() -> void:
	_refresh()
	visible = true
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5
	_buttons.music.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _cycle(key: String) -> void:
	var v: Variant = WorldState.option(key)
	match key:
		"music", "sfx":
			WorldState.set_option(key, _next(STEPS, float(v)))
		"touch_opacity":
			WorldState.set_option(key, _next(OPACITY_STEPS, float(v)))
		_:
			WorldState.set_option(key, not bool(v))
	Sfx.play("ui_move")
	_refresh()


static func _next(steps: Array, v: float) -> float:
	for s in steps:
		if s > v + 0.001:
			return s
	return steps[0]


func _refresh() -> void:
	var on := tr("On")
	var off := tr("Off")
	_buttons.music.text = tr("Music: %d%%") % roundi(float(WorldState.option("music")) * 100.0)
	_buttons.sfx.text = tr("Sound effects: %d%%") % roundi(float(WorldState.option("sfx")) * 100.0)
	_buttons.sound_cues.text = tr("Sound cues on screen: %s") % (on if WorldState.option("sound_cues") else off)
	_buttons.assist.text = tr("Assist mode (half damage): %s") % (on if WorldState.option("assist") else off)
	_buttons.touch_opacity.text = tr("Touch buttons: %d%%") % roundi(float(WorldState.option("touch_opacity")) * 100.0)
	_buttons.left_handed.text = tr("Left-handed touch: %s") % (on if WorldState.option("left_handed") else off)
	_buttons.battery_saver.text = tr("Battery saver (30 FPS): %s") % (on if WorldState.option("battery_saver") else off)
