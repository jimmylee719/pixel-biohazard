## 所有可以按 interact 互動的東西的基底：置物櫃、物品、配電箱、樓梯。
## 主角會找範圍內最近、可以互動的那一個，顯示提示並在按下 interact 時呼叫 use()。
class_name Interactable
extends Node2D

## 主角中心離這個物件中心多近才能互動（像素）
@export var interact_range := 20.0

var enabled := true
## 這個物件在世界中唯一的 id（區域:x,y），用來記錄「已經撿過」
var item_id := ""
## 任務系統用的名稱（Areas 的 names），沒有名字就是空字串
var item_name := ""
var level: Level


func can_interact(_player: Player) -> bool:
	return enabled


## 顯示在畫面下方的提示（不含按鍵名稱）
func get_prompt(_player: Player) -> String:
	return ""


## 主角按下 interact 時呼叫：執行互動，並通知任務系統。
func use(player: Player) -> void:
	interact(player)
	WorldState.emit_event("interact", item_name)


func interact(_player: Player) -> void:
	pass


## 世界狀態被還原（回到檢查點）或區域載入時，依狀態更新外觀。
func sync_from_state() -> void:
	pass


## 一次性的物品：撿走後記錄在世界狀態，重新進入區域也不會再出現。
func take() -> void:
	WorldState.mark_taken(item_id)
	WorldState.emit_event("collect", item_name)
	sync_from_state()


func _sync_taken() -> void:
	enabled = not WorldState.is_taken(item_id)
	visible = enabled
