## 倒下的人類（死了或被麻醉睡著）身上的把手（v0.12）：互動 = 拖著走／放下；拖到置物櫃旁邊放下 = 塞進櫃子藏起來（不會再被發現）。
## 屍體被別的守衛看到 = 他會通報、整區進入戒備（main._check_bodies）。
class_name BodyHandle
extends Interactable

var body: Enemy


func _init() -> void:
	interact_range = 16.0


func _process(_delta: float) -> void:
	if body == null or not is_instance_valid(body) or body.stashed or (not body.is_dead and not body.is_asleep()):
		queue_free()
		return
	global_position = body.global_position


func can_interact(player: Player) -> bool:
	if player.dragging == body:
		return true
	return enabled and not player.is_hiding and player.dragging == null


func get_prompt(player: Player) -> String:
	if player.dragging == body:
		return tr("Hide the body in the locker") if _locker_near(player) else tr("Drop the body")
	return tr("Drag the body")


func interact(player: Player) -> void:
	if player.dragging == body:
		var locker := _locker_near(player)
		player.dragging = null
		if locker:
			body.stash()
			Sfx.play("locker_open", global_position)
		return
	player.dragging = body
	Sfx.play("pickup_item", global_position, 0.1, -8.0)


func _locker_near(player: Player) -> Locker:
	if level == null:
		return null
	for item in level.get_interactables():
		if item is Locker and item.global_position.distance_to(player.global_position) < 24.0:
			return item
	return null
