## 雪地車：打倒機庫裡的 Boss 之後才能使用，可以開往天線塔（下一章）。
class_name Snowcat
extends Interactable

const BOSS_ID := "tundra_mother"


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Start the snowcat" if _ready_to_go() else "Snowcat (not safe yet)"


func counts_as_interaction(_player: Player) -> bool:
	return _ready_to_go()


func _ready_to_go() -> bool:
	return WorldState.has_flag("defeated:" + BOSS_ID)


func _draw() -> void:
	draw_rect(Rect2(-12, -7, 24, 12), Color(0.85, 0.55, 0.15))
	draw_rect(Rect2(-12, 5, 24, 3), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-4, -10, 12, 5), Color(0.6, 0.8, 0.9))
