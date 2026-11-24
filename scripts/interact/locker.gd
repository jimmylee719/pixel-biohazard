## 置物櫃：躲進去後敵人看不到也摸不到你。
## 但如果躲進去的那一刻被敵人看見，敵人會直接把你拖出來。
class_name Locker
extends Interactable


func _init() -> void:
	interact_range = 21.0


func can_interact(player: Player) -> bool:
	return enabled and (not player.is_hiding or player.hiding_in == self)


func get_prompt(player: Player) -> String:
	return "Leave" if player.hiding_in == self else "Hide"


func interact(player: Player) -> void:
	if player.hiding_in == self:
		player.exit_hiding()
	else:
		player.enter_hiding(self)
