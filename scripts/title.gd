## 標題畫面：新遊戲／繼續（讀取無線電存檔）／離開。
## 用按鈕做，滑鼠、觸控、鍵盤（ui_up/ui_down/ui_accept）、手把都能操作。
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _new_game: Button = $Center/Box/NewGame
@onready var _continue: Button = $Center/Box/Continue
@onready var _quit: Button = $Center/Box/Quit
var _language: Button


var _options: OptionsPanel


func _ready() -> void:
	get_tree().paused = false
	DisplayServer.window_set_title("AFTERSIGNAL")
	# 80 年代合成波風格的背景（霓虹網格、條紋太陽、天線塔）
	var backdrop := NeonBackdrop.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, $Background.get_index() + 1)
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
	_options.closed.connect(func():
		$Center.visible = true
		options.grab_focus())
	(_new_game if _continue.disabled else _continue).grab_focus()


func _toggle_language() -> void:
	WorldState.set_language("en" if WorldState.language() == "zh_TW" else "zh_TW")
	_refresh_language()


func _refresh_language() -> void:
	_language.text = "Language: 中文" if WorldState.language() == "zh_TW" else "Language: English"
	$Center/Box/Subtitle.visible = WorldState.language() == "zh_TW"


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
