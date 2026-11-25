## 錄音帶：撿起來會顯示一段紀錄（劇情與情報）。
class_name TapePickup
extends Interactable

signal message_shown(text: String)


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Take tape"


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	take()
	message_shown.emit(level.get_message(item_name))
	var freq := learn_frequency()
	if freq != 0:
		message_shown.emit(tr("Frequency %s noted in the radio memo.") % Frequencies.format(freq))


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	draw_rect(Rect2(-5, -3, 10, 6), Color(0.2, 0.2, 0.22))
	draw_rect(Rect2(-3, -1, 2, 2), Color(0.8, 0.8, 0.8))
	draw_rect(Rect2(1, -1, 2, 2), Color(0.8, 0.8, 0.8))
