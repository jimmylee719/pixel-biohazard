## 世界狀態：所有需要跨區域、跨重來保存的東西都放這裡。
## 撿過的物品、暖氣開關、任務進度、物品欄、生命值與感染值、死掉的敵人、取得的情報……
## 之後的存檔功能也只要把 data 存起來。
##
## 檢查點：每次進入一個區域時記錄一次。被抓到時回到最近的檢查點（區域入口）。
extends Node

## 遊戲事件（任務系統監聽）：kind = "enter_area" / "interact" / "collect"，id = 物件或區域名稱
signal game_event(kind: String, id: String)
signal changed

const START_SLOTS := 6
const MAX_HEALTH := 100.0
const MAX_INFECTION := 100.0

const SAVE_VERSION := 1

## 存檔位置（測試時可以改成別的檔名）
var save_path := "user://save.dat"
var data := {}
var _checkpoint := {}


func _ready() -> void:
	new_game()


func new_game() -> void:
	data = {
		"area": Areas.START_AREA,
		"entry": Areas.START_ENTRY,
		"inventory": _empty_inventory(START_SLOTS),
		"health": MAX_HEALTH,
		"infection": 0.0,
		"pistol_loaded": 0,
		"storage": {},
		"flags": {},
	}
	_checkpoint = data.duplicate(true)


# ── 通用旗標 ──

func has_flag(key: String) -> bool:
	return data.flags.has(key)


func get_flag(key: String, default: Variant = null) -> Variant:
	return data.flags.get(key, default)


func set_flag(key: String, value: Variant = true) -> void:
	data.flags[key] = value
	changed.emit()


# ── 常用的包裝 ──

var health: float:
	get:
		return data.health
	set(value):
		data.health = clampf(value, 0.0, MAX_HEALTH)
		changed.emit()

var infection: float:
	get:
		return data.infection
	set(value):
		data.infection = clampf(value, 0.0, MAX_INFECTION)
		changed.emit()

var pistol_loaded: int:
	get:
		return data.pistol_loaded
	set(value):
		data.pistol_loaded = value
		changed.emit()

## 空瓶數（相容舊程式：其實是物品欄裡的 bottle 數量）
var bottles: int:
	get:
		return inv_count("bottle")
	set(value):
		var diff := value - inv_count("bottle")
		if diff > 0:
			inv_add("bottle", diff)
		elif diff < 0:
			inv_remove("bottle", -diff)


func is_enemy_dead(enemy_key: String) -> bool:
	return has_flag("dead:" + enemy_key)


## 記住死掉的位置，屍體會留在那裡
func mark_enemy_dead(enemy_key: String, position: Vector2) -> void:
	set_flag("dead:" + enemy_key, position)


func enemy_death_position(enemy_key: String, fallback: Vector2) -> Vector2:
	var p = get_flag("dead:" + enemy_key)
	return p if p is Vector2 else fallback


# ── 物品欄 ──
# 格子是陣列，每格是 {} （空）或 {"id": 物品, "count": 數量}。同種物品可以疊到 stack 上限。

static func _empty_inventory(slots: int) -> Array:
	var inv := []
	for i in slots:
		inv.append({})
	return inv


func inventory() -> Array:
	return data.inventory


func inv_count(item_id: String) -> int:
	var total := 0
	for slot in data.inventory:
		if slot.get("id") == item_id:
			total += slot.count
	return total


## 還能再放幾個這種物品
func inv_space_for(item_id: String) -> int:
	var stack: int = Items.get_item(item_id).stack
	var space := 0
	for slot in data.inventory:
		if slot.is_empty():
			space += stack
		elif slot.id == item_id:
			space += stack - slot.count
	return space


## 放進物品欄，回傳實際放進去幾個
func inv_add(item_id: String, count: int) -> int:
	var stack: int = Items.get_item(item_id).stack
	var left := count
	for slot in data.inventory:  # 先疊到已有的格子
		if left > 0 and slot.get("id") == item_id and slot.count < stack:
			var n := mini(left, stack - slot.count)
			slot.count += n
			left -= n
	for i in data.inventory.size():  # 再放進空格
		if left > 0 and data.inventory[i].is_empty():
			var n := mini(left, stack)
			data.inventory[i] = {"id": item_id, "count": n}
			left -= n
	changed.emit()
	return count - left


## 從物品欄拿掉，回傳實際拿掉幾個
func inv_remove(item_id: String, count: int) -> int:
	var left := count
	for i in range(data.inventory.size() - 1, -1, -1):
		var slot: Dictionary = data.inventory[i]
		if left > 0 and slot.get("id") == item_id:
			var n := mini(left, slot.count)
			slot.count -= n
			left -= n
			if slot.count <= 0:
				data.inventory[i] = {}
	changed.emit()
	return count - left


func is_taken(item_id: String) -> bool:
	return has_flag("taken:" + item_id)


func mark_taken(item_id: String) -> void:
	set_flag("taken:" + item_id)


func is_zone_heated(area_id: String, zone: String, default: bool) -> bool:
	return get_flag("heat:%s:%s" % [area_id, zone], default)


func set_zone_heated(area_id: String, zone: String, heated: bool) -> void:
	set_flag("heat:%s:%s" % [area_id, zone], heated)


func emit_event(kind: String, id: String) -> void:
	if id != "":
		game_event.emit(kind, id)


# ── 儲物箱（所有安全屋共用，不限格數）──

func storage() -> Dictionary:
	return data.storage


## 把物品欄某一格整格放進儲物箱
func store_slot(index: int) -> bool:
	var slot: Dictionary = data.inventory[index]
	if slot.is_empty():
		return false
	data.storage[slot.id] = data.storage.get(slot.id, 0) + slot.count
	data.inventory[index] = {}
	changed.emit()
	return true


## 從儲物箱拿出某種物品，能放多少拿多少，回傳拿了幾個
func retrieve(item_id: String) -> int:
	var have: int = data.storage.get(item_id, 0)
	var got := inv_add(item_id, mini(have, inv_space_for(item_id)))
	if got > 0:
		data.storage[item_id] = have - got
		if data.storage[item_id] <= 0:
			data.storage.erase(item_id)
		changed.emit()
	return got


# ── 存檔 ──

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## 存到硬碟（Vector2 等 Godot 型別用 store_var 保存）
func save_to_disk() -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("存檔失敗：%s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_var({"version": SAVE_VERSION, "data": data})
	return true


func load_from_disk() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var saved = f.get_var()
	if not (saved is Dictionary and saved.has("data")):
		return false
	data = saved.data
	_checkpoint = data.duplicate(true)
	changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ── 檢查點 ──

## 進入區域時呼叫：記住現在的狀態，被抓到時回到這裡。
func save_checkpoint(area_id: String, entry: String) -> void:
	data.area = area_id
	data.entry = entry
	_checkpoint = data.duplicate(true)


func restore_checkpoint() -> void:
	data = _checkpoint.duplicate(true)
	changed.emit()


func checkpoint_area() -> String:
	return _checkpoint.area


func checkpoint_entry() -> String:
	return _checkpoint.entry
