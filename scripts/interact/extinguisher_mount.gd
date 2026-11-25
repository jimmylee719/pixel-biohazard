## 牆上的滅火器：拿起來雙手拿著（不能用槍）。
## 噴：撲滅火、噴到的敵人看不見一陣子並失去你的位置、留下擋視線的白霧。丟：很大聲的誘餌。
class_name ExtinguisherMount
extends Interactable


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and WorldState.carrying == ""


func get_prompt(_player: Player) -> String:
	return "Take the fire extinguisher (both hands)"


func interact(player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	WorldState.carrying = "extinguisher"
	WorldState.extinguisher_charge = player.extinguisher_charges
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	if draw_art("extinguisher"):
		return
	draw_rect(Rect2(-3, -6, 6, 11), Color(0.8, 0.12, 0.1))
	draw_rect(Rect2(-2, -8, 4, 2), Color(0.25, 0.25, 0.25))
	draw_line(Vector2(2, -7), Vector2(5, -4), Color(0.25, 0.25, 0.25), 1.0)
