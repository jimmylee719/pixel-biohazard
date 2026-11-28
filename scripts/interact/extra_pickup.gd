## 改裝件、藏寶圖（Extras 的 mod／chart）。放在桌上的補給盒／一張圖；拿了之後桌子留著。
class_name ExtraPickup
extends ItemPickup

signal message_shown(text: String)

var info := {}


func is_mod() -> bool:
	return info.get("kind", "") == "mod"


func get_prompt(_player: Player) -> String:
	if is_mod():
		return tr("Take %s") % tr(Items.MODS[info.id].name)
	return tr("Study the sketch")


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	if is_mod():
		WorldState.set_flag("mod:" + info.id)
		message_shown.emit(tr("%s fitted. %s") % [tr(Items.MODS[info.id].name), tr(Items.MODS[info.id].desc)])
	else:
		WorldState.set_flag(info.reveal)
		message_shown.emit(tr(info.text))
		message_shown.emit(tr("Weapon cache marked on your map (M)."))
		if info.has("mission") and not WorldState.data.get("pins", []).has(info.mission):
			WorldState.toggle_pin(info.mission, false)
		if level:
			level.sync_from_state()  # 藏起來的武器出現
	take()


func stash_art() -> String:
	return "supply_box" if is_mod() else ""


func icon_art() -> String:
	return "props/" + info.id if is_mod() else "props/chart"
