## 角色站在牆、櫃子「前面」（南邊）時，頭會伸進上面那排牆的格子裡；
## 牆畫在角色上面的圖層（Structure，不受黑暗影響），所以頭會被牆蓋掉、前後關係看起來是反的。
## 這裡用「上面那排的牆格子」當遮罩，把角色在那些格子裡的部分再畫一次，蓋在牆上面。
## 站在牆後面（北邊）的角色不畫：那時候牆本來就該擋住他。
class_name OverWall
extends Node2D

## 櫃子、置物櫃的像素圖比格子高（往上突出），遮罩也往上加這麼多
const PROP_RISE := 10.0
## 補畫的部分稍微暗一點（原本的角色有被黑暗壓暗）
const SHADE := Color(0.85, 0.85, 0.9)

var level: Level
## 角色的 instance id → {mask, spr}
var _slots := {}


class _Mask:
	extends Node2D
	var rects: Array[Rect2] = []

	func _draw() -> void:
		for r in rects:
			draw_rect(r, Color.WHITE)


func _process(_delta: float) -> void:
	if level == null:
		return
	var used := {}
	for node in get_tree().get_nodes_in_group("door_users"):
		var body := node as Node2D
		if body == null:
			continue
		var cs := body.get("_sprite") as CharacterSprite
		if cs == null or cs.sprite_frames == null or not cs.is_visible_in_tree():
			continue
		var rects := mask_rects(body.global_position + Vector2(0, CharacterSprite.FEET))
		if rects.is_empty():
			continue
		var id := body.get_instance_id()
		used[id] = true
		if not _slots.has(id):
			_slots[id] = _make_slot()
		var slot: Dictionary = _slots[id]
		var mask: _Mask = slot.mask
		mask.rects = rects
		mask.visible = true
		mask.queue_redraw()
		var spr: Sprite2D = slot.spr
		spr.texture = cs.sprite_frames.get_frame_texture(cs.animation, cs.frame)
		spr.flip_h = cs.flip_h
		spr.offset = cs.offset
		spr.global_transform = cs.global_transform
		spr.modulate = cs.modulate * body.modulate * SHADE
	for id in _slots:
		if not used.has(id):
			_slots[id].mask.visible = false
	# 角色被刪掉了（換區域、死亡移除）：清掉
	for id in _slots.keys():
		if not is_instance_id_valid(id):
			_slots[id].mask.queue_free()
			_slots.erase(id)


## 腳在 feet 的角色：上面三排（牆比人高，v0.14）、左右各一格裡，會擋住它的東西（牆、櫃子、窗戶）的畫面範圍
func mask_rects(feet: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var t := float(Level.TILE)
	var f := Vector2i(floori(feet.x / t), floori(feet.y / t))
	for dy in [1, 2, 3]:
		for dx in [-1, 0, 1]:
			var c := f + Vector2i(dx, -dy)
			var ch := level.char_at(c)
			if ch == "#" or ch == "=":
				var r := Level.WALL_RAISE if ch == "#" else Level.WINDOW_RAISE
				out.append(Rect2(Vector2(c) * t - Vector2(0, r), Vector2(t, t + r)))
			elif ch == "C" or ch == "H":
				out.append(Rect2(Vector2(c) * t - Vector2(0, PROP_RISE), Vector2(t, t + PROP_RISE)))
	return out


func _make_slot() -> Dictionary:
	var mask := _Mask.new()
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(mask)
	var spr := Sprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mask.add_child(spr)
	return {"mask": mask, "spr": spr}
