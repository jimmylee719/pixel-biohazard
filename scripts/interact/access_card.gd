## 權限卡：撿到後權限等級提高（不佔物品欄）。門的 access 欄位決定需要幾級。
class_name AccessCard
extends Interactable

@export var level_granted := 1


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Take keycard (Level %d)" % level_granted


func interact(_player: Player) -> void:
	WorldState.access_level = level_granted
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	draw_rect(Rect2(-4, -3, 8, 6), Color(0.85, 0.85, 0.9))
	draw_rect(Rect2(-4, -3, 8, 2), Color(0.3, 0.6, 0.95))
