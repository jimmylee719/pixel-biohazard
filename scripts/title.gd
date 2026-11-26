## 標題畫面（潛龍諜影式）：衛星定位的開場字 → 暴風雪夜景＋大標題＋「PRESS ANY BUTTON」→ 按下去（槍聲）選單才出現。
## 選單：新遊戲／繼續（讀取無線電存檔）／生存模式／選項／語言／離開。
## 用按鈕做，滑鼠、觸控、鍵盤（ui_up/ui_down/ui_accept）、手把都能操作。畫面本身見 TitleBackdrop。
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _new_game: Button = $Center/Box/NewGame
@onready var _continue: Button = $Center/Box/Continue
@onready var _quit: Button = $Center/Box/Quit
var _language: Button


var _options: OptionsPanel
var backdrop: TitleBackdrop


func _ready() -> void:
	get_tree().paused = false
	DisplayServer.window_set_title("AFTERSIGNAL")
	# 電影感的標題畫面（開場字、夜景、標題、按任意鍵）
	backdrop = TitleBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, $Background.get_index() + 1)
	for n in ["Name", "Subtitle", "Tagline", "Spacer"]:
		$Center/Box.get_node(n).visible = false
	# 選單放在標題下面、畫面下半部；按下任意鍵之前看不到
	$Center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Center.offset_top = 116
	$Center.offset_bottom = -20
	$Center.visible = false
	$Center/Box.add_theme_constant_override("separation", 1)
	Sfx.play_music("title")
	Sfx.play_ambience("amb_blizzard")
	_continue.disabled = not WorldState.has_save()
	# 網頁版和 iOS 不需要「離開」
	_quit.visible = not (OS.has_feature("web") or OS.has_feature("ios"))
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_quit.pressed.connect(func(): get_tree().quit())
	# 語言切換（中文／English），記在 user://settings.cfg
	_language = Button.new()
	_language.add_theme_font_size_override("font_size", 12)
	_language.pressed.connect(_toggle_language)
	$Center/Box.add_child(_language)
	$Center/Box.move_child(_language, _quit.get_index())
	_refresh_language()
	# 生存模式「長夜」
	var survival := Button.new()
	survival.text = tr("Survival: The Long Night")
	survival.add_theme_font_size_override("font_size", 12)
	survival.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/survival_menu.tscn"))
	$Center/Box.add_child(survival)
	$Center/Box.move_child(survival, _continue.get_index() + 1)
	# 選項（音量、觸控、聲音提示、輔助模式、省電）
	var options := Button.new()
	options.text = tr("Options")
	options.add_theme_font_size_override("font_size", 12)
	$Center/Box.add_child(options)
	$Center/Box.move_child(options, _language.get_index())
	_options = OptionsPanel.new()
	add_child(_options)
	options.pressed.connect(func():
		$Center.visible = false
		_options.open())
	_options.visible = false
	_options.closed.connect(func():
		$Center.visible = true
		options.grab_focus())
	for b in $Center/Box.get_children():
		if b is Button:
			_style_menu_button(b)


## 選單按鈕：沒有底框的白字，選到的那一個左邊有紅色的線、字變亮（簡潔的軍事風）
func _style_menu_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", _focus_box())
	b.add_theme_stylebox_override("focus", _focus_box())
	b.add_theme_stylebox_override("pressed", _focus_box())
	b.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.62, 0.65, 0.7))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.3, 0.32, 0.35))
	b.custom_minimum_size = Vector2(170, 0)


func _focus_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.12, 0.1, 0.22)
	sb.border_color = Color(0.85, 0.15, 0.12)
	sb.border_width_left = 2
	return sb


## 按任意鍵：開場字還在跑 = 直接跳到標題；標題 = 槍聲、閃光，選單出現
func _unhandled_input(event: InputEvent) -> void:
	if $Center.visible or _options.visible:
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton \
		or event is InputEventScreenTouch) and event.is_pressed() and not event.is_echo()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if backdrop.phase == "intro":
		backdrop.set_phase("press")
		backdrop._phase_t = 1.6
	else:
		press_start()


func press_start() -> void:
	if $Center.visible:
		return
	Sfx.play("pistol_shot")
	backdrop.set_phase("menu")
	$Center.visible = true
	(_new_game if _continue.disabled else _continue).grab_focus()


func _toggle_language() -> void:
	WorldState.set_language("en" if WorldState.language() == "zh_TW" else "zh_TW")
	_refresh_language()


func _refresh_language() -> void:
	_language.text = "Language: 中文" if WorldState.language() == "zh_TW" else "Language: English"
	$Center/Box/Subtitle.visible = false  # 標題由 TitleBackdrop 畫


func _on_new_game() -> void:
	WorldState.start_story()
	WorldState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	WorldState.start_story()
	if WorldState.load_from_disk():
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_continue.disabled = true
