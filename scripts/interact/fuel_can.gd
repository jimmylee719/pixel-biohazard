## 燃料桶：雙手搬運。搬著的時候不能跑、不能用武器，腳步聲也比較大。
## 要一路搬到地下層的發電機。被打倒或回到檢查點時，燃料桶會回到原處。
class_name FuelCan
extends Interactable


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and WorldState.carrying == ""


func get_prompt(_player: Player) -> String:
	return "Carry fuel can (both hands)"


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	WorldState.carrying = "fuel"
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	draw_rect(Rect2(-5, -6, 10, 12), Color(0.7, 0.2, 0.15))
	draw_rect(Rect2(-5, -6, 10, 12), Color(0.9, 0.4, 0.3), false, 1.0)
	draw_rect(Rect2(-2, -8, 4, 2), Color(0.3, 0.3, 0.3))
