## 可以破壞的東西：木箱（裡面可能有東西）、封住通道的木板（打開就是一條捷徑）。
## 踢開：一下就開，但很大聲。小刀割：要割好幾下，但很安靜（揮刀聲而已）。
## 沒壞之前擋路也擋視線。壞掉的狀態記在世界狀態（和撿過的物品一樣）。
## 箱子裡的東西寫在區域資料的 loot，壞掉後掉在原地。
class_name Breakable
extends Interactable

const KICK_NOISE := {"crate": 7.0, "barricade": 9.0}
const CUT_HITS := {"crate": 2, "barricade": 4}

## "crate" 或 "barricade"
var kind := "crate"
## [物品, 數量]，沒有就是空陣列
var loot: Array = []

var _hits := 0
var _body: StaticBody2D
var _occluder: LightOccluder2D
var _loot_item: ItemPickup


func _ready() -> void:
	interact_range = 24.0


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding and not player.is_carrying()


func get_prompt(_player: Player) -> String:
	return tr("Kick %s (loud)  - or knife it quietly") % tr("it open" if kind == "crate" else "the boards down")


func interact(_player: Player) -> void:
	smash(KICK_NOISE[kind])


## 小刀割一下
func cut() -> void:
	if not enabled:
		return
	_hits += 1
	queue_redraw()
	if _hits >= CUT_HITS[kind]:
		smash(0.0)


func smash(noise_tiles: float) -> void:
	if not enabled:
		return
	if noise_tiles > 0.0:
		NoiseBus.emit_noise(global_position, noise_tiles * Player.TILE, self)
	Sfx.play("wood_break", global_position, 0.06, 0.0 if noise_tiles > 0.0 else -6.0)
	take()
	level.rebake_navigation()


func is_broken() -> bool:
	return WorldState.is_taken(item_id)


func sync_from_state() -> void:
	if not is_broken():
		_hits = 0
		enabled = true
		visible = true
		if _body == null:
			_body = level.add_nav_obstacle(position, Vector2(14, 14))
			_occluder = LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)])
			_occluder.occluder = poly
			add_child(_occluder)
		return
	enabled = false
	visible = false
	if _body:
		# 立刻從場景移除（不能等 queue_free），重新烘焙導航時才不會還被當成障礙物
		_body.get_parent().remove_child(_body)
		_body.queue_free()
		_body = null
		remove_child(_occluder)
		_occluder.queue_free()
		_occluder = null
	if not loot.is_empty() and _loot_item == null:
		_loot_item = ItemPickup.new()
		_loot_item.pickup_item = loot[0]
		_loot_item.pickup_count = loot[1]
		_loot_item.item_id = item_id + ":loot"
		_loot_item.position = position
		level.add_interactable(_loot_item)


func _draw() -> void:
	if draw_art("crate" if kind == "crate" else "boards"):
		for i in _hits:
			draw_line(Vector2(-4 + i * 3, -9), Vector2(-1 + i * 3, 1), Color(0.95, 0.9, 0.75), 1.0)
		return
	if kind == "crate":
		draw_rect(Rect2(-7, -7, 14, 14), Color(0.5, 0.36, 0.2))
		draw_rect(Rect2(-7, -7, 14, 14), Color(0.68, 0.5, 0.3), false, 1.0)
		draw_line(Vector2(-7, -7), Vector2(7, 7), Color(0.68, 0.5, 0.3), 1.0)
	else:
		for i in 3:
			draw_rect(Rect2(-8, -6 + i * 5, 16, 3), Color(0.55, 0.4, 0.22))
		draw_line(Vector2(-6, -7), Vector2(-6, 7), Color(0.35, 0.25, 0.15), 1.0)
		draw_line(Vector2(6, -7), Vector2(6, 7), Color(0.35, 0.25, 0.15), 1.0)
	# 割過的痕跡
	for i in _hits:
		draw_line(Vector2(-4 + i * 3, -5), Vector2(-1 + i * 3, 5), Color(0.9, 0.85, 0.7), 1.0)
