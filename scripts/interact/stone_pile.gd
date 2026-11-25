## 碎石堆（戶外）：撿石頭，撿不完。石頭丟出去的聲音比空瓶小，適合輕輕引開一隻敵人。
class_name StonePile
extends Interactable


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and WorldState.inv_space_for("stone") > 0


func get_prompt(_player: Player) -> String:
	return "Pick up stones"


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	var stack: int = Items.get_item("stone").stack
	var want := stack - WorldState.inv_count("stone") % stack if WorldState.inv_count("stone") % stack != 0 else stack
	WorldState.inv_add("stone", mini(want, WorldState.inv_space_for("stone")))


func _draw() -> void:
	for p in [Vector2(-4, 2), Vector2(2, 3), Vector2(-1, -2), Vector2(4, -1)]:
		draw_rect(Rect2(p - Vector2(2, 1.5), Vector2(4, 3)), Color(0.45, 0.46, 0.5))
