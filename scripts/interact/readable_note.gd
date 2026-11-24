## 筆記、白板：可以重複閱讀。上面寫著頻率的話，會記進無線電備忘錄。
class_name ReadableNote
extends Interactable

signal message_shown(text: String)


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return "Read"


func interact(_player: Player) -> void:
	message_shown.emit(level.get_message(item_name))
	var freq := learn_frequency()
	if freq != 0:
		message_shown.emit("Frequency %s noted in the radio memo." % Frequencies.format(freq))
	WorldState.emit_event("collect", item_name)


func sync_from_state() -> void:
	enabled = is_revealed()
	visible = enabled


func _draw() -> void:
	draw_rect(Rect2(-6, -5, 12, 9), Color(0.85, 0.87, 0.82))
	for i in 3:
		draw_line(Vector2(-4, -3 + i * 2.5), Vector2(3, -3 + i * 2.5), Color(0.3, 0.35, 0.5), 1.0)
