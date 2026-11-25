## 區域地圖（惡靈古堡式）：撿到之後，手機地圖會顯示這個區域的全部格局（包含還沒去過、隱藏的房間）。
## 地圖符號 l。地圖記在旗標 map:<主地圖 id>。
class_name AreaMapPickup
extends Interactable

signal message_shown(text: String)


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return tr("Take the floor map")


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	WorldState.set_flag("map:" + level.area_id)
	take()
	message_shown.emit(tr("Map of %s added to your phone.") % tr(level.title))


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	if draw_art("area_map"):
		return
	draw_rect(Rect2(-5, -4, 10, 8), Color(0.85, 0.8, 0.6))
