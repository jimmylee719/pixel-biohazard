## 地上的一般物品：彈藥、急救包、抗菌藥劑、手槍。物品欄滿了就拿不起來。
class_name ItemPickup
extends Interactable

const COLORS := {
	"ammo": Color(0.85, 0.7, 0.3),
	"med": Color(0.9, 0.3, 0.3),
	"antibiotic": Color(0.4, 0.9, 0.95),
	"pistol": Color(0.55, 0.58, 0.62),
	"shotgun": Color(0.5, 0.4, 0.3),
	"shells": Color(0.85, 0.3, 0.25),
	"ethanol": Color(0.75, 0.85, 1.0),
	"stone": Color(0.55, 0.55, 0.6),
	"bottle": Color(0.6, 0.9, 0.7),
	"molotov": Color(1.0, 0.55, 0.2),
	"heat_pack": Color(1.0, 0.6, 0.25),
}
## 撿到武器時彈匣裡已經有的子彈
const START_LOADED := {"pistol": 6, "shotgun": 2}

var pickup_item := ""
var pickup_count := 1


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	if WorldState.inv_space_for(pickup_item) < pickup_count:
		return tr("No room (%s)") % Items.display_name(pickup_item)
	var name := Items.display_name(pickup_item)
	return tr("Take %s") % name if pickup_count == 1 else tr("Take %s x%d") % [name, pickup_count]


func interact(_player: Player) -> void:
	Sfx.play("pickup_item", global_position)
	if WorldState.inv_space_for(pickup_item) < pickup_count:
		return
	WorldState.inv_add(pickup_item, pickup_count)
	if START_LOADED.has(pickup_item):
		WorldState.set_loaded(pickup_item, START_LOADED[pickup_item])
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	var tex := Art.tex("props/" + pickup_item)
	if tex:
		# 地上的小影子＋物品圖（tools/gen_pixel_art.py）
		draw_rect(Rect2(-tex.get_width() * 0.4, tex.get_height() * 0.5 - 2, tex.get_width() * 0.8, 2), Color(0, 0, 0, 0.35))
		draw_texture(tex, (-tex.get_size() * 0.5).floor())
		return
	var c: Color = COLORS.get(pickup_item, Color.WHITE)
	match pickup_item:
		"pistol":
			draw_rect(Rect2(-5, -2, 9, 3), c)
			draw_rect(Rect2(-5, 0, 3, 4), c)
		"shotgun":
			draw_rect(Rect2(-7, -1, 14, 2), c)
			draw_rect(Rect2(-7, 0, 4, 3), c)
		"ethanol", "bottle", "molotov":
			draw_rect(Rect2(-2, -5, 4, 9), c)
			draw_rect(Rect2(-1, -7, 2, 2), c.darkened(0.3))
		"stone":
			draw_rect(Rect2(-3, -2, 6, 4), c)
		"ammo", "shells":
			draw_rect(Rect2(-4, -3, 8, 6), Color(0.3, 0.28, 0.2))
			draw_rect(Rect2(-3, -2, 6, 2), c)
		_:
			draw_rect(Rect2(-4, -3, 8, 6), c)
			draw_rect(Rect2(-1, -2, 2, 4), Color.WHITE)
			draw_rect(Rect2(-2, -1, 4, 2), Color.WHITE)
