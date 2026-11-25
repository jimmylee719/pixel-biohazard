## 裝備（紙娃娃）：撿起來不佔物品欄，到手機的「裝備」App 換穿。地圖符號 t，哪一件見區域資料 gear。
class_name GearPickup
extends Interactable

signal message_shown(text: String)

var gear_id := ""


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and Gear.DATA.has(gear_id)


func get_prompt(_player: Player) -> String:
	return tr("Take %s") % tr(Gear.DATA[gear_id].name)


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	WorldState.add_gear(gear_id)
	take()
	message_shown.emit(tr("Got %s. Wear it from the phone (GEAR).") % tr(Gear.DATA[gear_id].name))


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	if draw_art("gear_case"):
		return
	draw_rect(Rect2(-6, -4, 12, 8), Color(0.3, 0.35, 0.3))
