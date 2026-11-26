## 窗戶：擋路、不擋視線。站到窗戶旁邊就看得到另一邊的房間（Player.peek_cells()，維持俯視，不切換視角）。
## 這個物件只是佔位（不能互動）。
class_name WindowPane
extends Interactable


func can_interact(_player: Player) -> bool:
	return false


func _draw() -> void:
	pass
