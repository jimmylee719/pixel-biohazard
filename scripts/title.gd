## 標題畫面：新遊戲／繼續（讀取無線電存檔）／離開。
## 用按鈕做，滑鼠、觸控、鍵盤（ui_up/ui_down/ui_accept）、手把都能操作。
extends Control

const GAME_SCENE := "res://scenes/main.tscn"

@onready var _new_game: Button = $Center/Box/NewGame
@onready var _continue: Button = $Center/Box/Continue
@onready var _quit: Button = $Center/Box/Quit


func _ready() -> void:
	get_tree().paused = false
	_continue.disabled = not WorldState.has_save()
	# 網頁版和 iOS 不需要「離開」
	_quit.visible = not (OS.has_feature("web") or OS.has_feature("ios"))
	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_quit.pressed.connect(func(): get_tree().quit())
	(_new_game if _continue.disabled else _continue).grab_focus()


func _on_new_game() -> void:
	WorldState.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	if WorldState.load_from_disk():
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_continue.disabled = true
