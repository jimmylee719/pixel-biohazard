## 保險箱：打開會找到一份情報，解鎖某個隱藏要素（旗標）。手機地圖上那個位置會出現藍色星號，但還是要自己過去拿。
## 地圖符號 s，內容見區域資料 safes：{"x,y": {"reveal": 旗標, "text": 情報}}。
class_name SafeBox
extends Interactable

signal message_shown(text: String)

var reveal := ""
var text := ""


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and not is_open()


func get_prompt(_player: Player) -> String:
	return tr("Open the safe")


func is_open() -> bool:
	return WorldState.has_flag("opened:" + item_id)


func interact(_player: Player) -> void:
	Sfx.play("locker_open", global_position)
	WorldState.set_flag("opened:" + item_id)
	if reveal != "":
		WorldState.set_flag(reveal)
	if level:
		level.sync_from_state()  # 藏起來的東西出現
	message_shown.emit(tr(text))
	message_shown.emit(tr("A blue star marks the spot on your phone map."))
	queue_redraw()


func sync_from_state() -> void:
	queue_redraw()


func _draw() -> void:
	if draw_art("safe_open" if is_open() else "safe"):
		return
	draw_rect(Rect2(-6, -6, 12, 12), Color(0.3, 0.32, 0.36))
