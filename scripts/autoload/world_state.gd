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
const MAX_BODY_TEMP := 100.0

const SAVE_VERSION := 1

## 存檔位置（測試時可以改成別的檔名）
var save_path := "user://save.dat"
var data := {}
var _checkpoint := {}


## 玩家設定（不跟存檔走）：語言
const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["zh_TW", "en"]
## 預設語言（第一次開遊戲）
const DEFAULT_LANGUAGE := "zh_TW"


func _ready() -> void:
	new_game()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	TranslationServer.set_locale(cfg.get_value("game", "language", DEFAULT_LANGUAGE))


func language() -> String:
	return "en" if TranslationServer.get_locale().begins_with("en") else "zh_TW"


## 切換語言並記住（下次開遊戲也是這個語言）
func set_language(code: String) -> void:
	TranslationServer.set_locale(code)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("game", "language", code)
	cfg.save(SETTINGS_PATH)


func new_game() -> void:
	data = {
		"area": Areas.START_AREA,
		"entry": Areas.START_ENTRY,
		"inventory": _empty_inventory(START_SLOTS),
		"health": MAX_HEALTH,
		"infection": 0.0,
		"loaded": {"pistol": 0, "shotgun": 0},
		"equipped": "pistol",
		"access_level": 0,
		"carrying": "",
		"storage": {},
		"flags": {},
		"ready_throw": "bottle",
		"extinguisher": 0,
		"body_temp": MAX_BODY_TEMP,
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
		return get_loaded("pistol")
	set(value):
		set_loaded("pistol", value)


## 每把武器彈匣裡的子彈數
func get_loaded(weapon: String) -> int:
	return data.loaded.get(weapon, 0)


func set_loaded(weapon: String, value: int) -> void:
	data.loaded[weapon] = value
	changed.emit()


## 權限卡等級（取代一堆彩色鑰匙，見 GDD 8.3）
var access_level: int:
	get:
		return data.access_level
	set(value):
		data.access_level = maxi(data.access_level, value)
		changed.emit()


## 雙手搬運中的東西（例如 "fuel"），空字串 = 沒有
var carrying: String:
	get:
		return data.carrying
	set(value):
		data.carrying = value
		changed.emit()


## 準備投擲的東西（物品 id）
var ready_throw: String:
	get:
		return data.ready_throw
	set(value):
		data.ready_throw = value
		changed.emit()


## 手上滅火器剩下的噴射次數（carrying == "extinguisher" 時有意義）
var extinguisher_charge: int:
	get:
		return data.extinguisher
	set(value):
		data.extinguisher = maxi(value, 0)
		changed.emit()


## 體溫（0～100）。只有會失溫的氣候才會下降，見 Climates。
var body_temp: float:
	get:
		return data.body_temp
	set(value):
		data.body_temp = clampf(value, 0.0, MAX_BODY_TEMP)


## 研究站的電力（發電機）
var power_on: bool:
	get:
		return has_flag("power_on")


## 天線塔發出的訊號（結局方向）："rescue"、"quarantine"、"destroy"，還沒發就是空字串
const SIGNAL_CHOICES := ["rescue", "quarantine", "destroy"]


func signal_choice() -> String:
	return get_flag("signal", "")


var equipped: String:
	get:
		return data.equipped
	set(value):
		data.equipped = value
		changed.emit()


# ── 無線電頻率 ──

func is_freq_known(freq: int) -> bool:
	return has_flag("freq_known:%d" % freq) or Frequencies.by_freq(freq).get("known", false)


func learn_freq(freq: int) -> bool:
	if is_freq_known(freq):
		return false
	set_flag("freq_known:%d" % freq)
	return true


## 備忘錄：知道的頻率，由小到大
func known_freqs() -> Array[int]:
	var result: Array[int] = []
	for f in Frequencies.DATA:
		if is_freq_known(f.freq):
			result.append(f.freq)
	result.sort()
	return result

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
	data = _migrate(saved.data)
	_checkpoint = data.duplicate(true)
	changed.emit()
	return true


## 舊版存檔缺少的欄位補上預設值（之後加新欄位時在這裡處理）
func _migrate(old: Dictionary) -> Dictionary:
	var fresh := {
		"inventory": _empty_inventory(START_SLOTS),
		"health": MAX_HEALTH,
		"infection": 0.0,
		"loaded": {"pistol": 0, "shotgun": 0},
		"equipped": "pistol",
		"access_level": 0,
		"carrying": "",
		"storage": {},
		"flags": {},
		"ready_throw": "bottle",
		"extinguisher": 0,
		"body_temp": MAX_BODY_TEMP,
	}
	if old.has("pistol_loaded") and not old.has("loaded"):
		old["loaded"] = {"pistol": old.pistol_loaded, "shotgun": 0}
		old.erase("pistol_loaded")
	for key in fresh:
		if not old.has(key):
			old[key] = fresh[key]
	return old


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
