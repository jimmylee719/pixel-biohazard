## 地上的一般物品：彈藥、急救包、抗菌藥劑、手槍。物品欄滿了就拿不起來。
class_name ItemPickup
extends Interactable

const COLORS := {
	"ammo": Color(0.85, 0.7, 0.3),
	"med": Color(0.9, 0.3, 0.3),
	"antibiotic": Color(0.4, 0.9, 0.95),
	"pistol": Color(0.55, 0.58, 0.62),
}
## 撿到手槍時彈匣裡已經有的子彈
const PISTOL_START_LOADED := 6

var pickup_item := ""
var pickup_count := 1


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	if WorldState.inv_space_for(pickup_item) < pickup_count:
		return "No room (%s)" % Items.display_name(pickup_item)
	var name := Items.display_name(pickup_item)
	return "Take %s" % name if pickup_count == 1 else "Take %s x%d" % [name, pickup_count]


func interact(_player: Player) -> void:
	if WorldState.inv_space_for(pickup_item) < pickup_count:
		return
	WorldState.inv_add(pickup_item, pickup_count)
	if pickup_item == "pistol":
		WorldState.pistol_loaded = PISTOL_START_LOADED
	take()


func sync_from_state() -> void:
	_sync_taken()


func _draw() -> void:
	var c: Color = COLORS.get(pickup_item, Color.WHITE)
	match pickup_item:
		"pistol":
			draw_rect(Rect2(-5, -2, 9, 3), c)
			draw_rect(Rect2(-5, 0, 3, 4), c)
		"ammo":
			draw_rect(Rect2(-4, -3, 8, 6), Color(0.3, 0.28, 0.2))
			draw_rect(Rect2(-3, -2, 6, 2), c)
		_:
			draw_rect(Rect2(-4, -3, 8, 6), c)
			draw_rect(Rect2(-1, -2, 2, 4), Color.WHITE)
			draw_rect(Rect2(-2, -1, 4, 2), Color.WHITE)
