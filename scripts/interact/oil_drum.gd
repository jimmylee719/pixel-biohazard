## 油桶：用打火機點燃（打火機永遠在身上）。燒起來之後一直燒：
## 照亮附近、是熱源（失溫）、會把附近的凍眠體熱醒；點火的聲音不大。滅火器可以撲滅。
## 點燃的狀態記在世界狀態（lit:物件 id）。
class_name OilDrum
extends Interactable

var _fire: Fire


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and not is_lit()


func get_prompt(_player: Player) -> String:
	return "Light the drum (lighter)"


func interact(_player: Player) -> void:
	WorldState.set_flag("lit:" + item_id)
	_refresh()


func is_lit() -> bool:
	return WorldState.has_flag("lit:" + item_id)


func put_out() -> void:
	WorldState.data.flags.erase("lit:" + item_id)
	_refresh()


func sync_from_state() -> void:
	_refresh()


func _refresh() -> void:
	if is_lit() and (_fire == null or not is_instance_valid(_fire)):
		_fire = Fire.new()
		_fire.duration = 0.0
		_fire.harmful = false
		_fire.radius = 8.0
		_fire.light_radius = 110.0
		_fire.warm_radius = 60.0
		add_child(_fire)
		_fire.extinguished.connect(func(): WorldState.data.flags.erase("lit:" + item_id))
	elif not is_lit() and _fire and is_instance_valid(_fire):
		_fire.put_out()
		_fire = null
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-6, -7, 12, 13), Color(0.3, 0.32, 0.28))
	draw_rect(Rect2(-6, -3, 12, 2), Color(0.45, 0.47, 0.4))
	draw_rect(Rect2(-6, 2, 12, 2), Color(0.45, 0.47, 0.4))
