## 所有可以按 interact 互動的東西的基底：置物櫃、物品、配電箱、出口。
## 主角會找範圍內最近、可以互動的那一個，顯示提示並在按下 interact 時呼叫 interact()。
class_name Interactable
extends Node2D

## 主角中心離這個物件中心多近才能互動（像素）
@export var interact_range := 20.0

var enabled := true


func can_interact(_player: Player) -> bool:
	return enabled


## 顯示在畫面下方的提示（不含按鍵名稱）
func get_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


## 關卡重來時恢復初始狀態
func reset() -> void:
	enabled = true
	visible = true
