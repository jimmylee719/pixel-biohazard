## 鑽探井底的升降機：打倒最終 Boss 之後才會動。搭上去 = 主線最後一步（結局）。
class_name ShaftLift
extends Interactable

signal message_shown(text: String)

const BOSS_ID := "deep_well"


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Ride the lift up" if _ready_to_go() else "Lift (jammed)"


func counts_as_interaction(_player: Player) -> bool:
	return _ready_to_go()


func interact(_player: Player) -> void:
	Sfx.play("lift_machinery" if _ready_to_go() else "door_locked", global_position)
	if not _ready_to_go():
		message_shown.emit("The lift cage is wrapped in crystal. It won't move while that thing is still singing.")


func _ready_to_go() -> bool:
	return WorldState.has_flag("defeated:" + BOSS_ID)


func _draw() -> void:
	if draw_art("lift"):
		return
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.25, 0.27, 0.3))
	draw_rect(Rect2(-8, -8, 16, 16), Color(0.75, 0.65, 0.3), false, 1.0)
	draw_line(Vector2(-8, -8), Vector2(8, 8), Color(0.75, 0.65, 0.3), 1.0)
	draw_line(Vector2(8, -8), Vector2(-8, 8), Color(0.75, 0.65, 0.3), 1.0)
