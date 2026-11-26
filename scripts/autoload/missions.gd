## 任務系統：主線（Main Ops）＋支線（Side Ops）。
## 任務用資料定義，每個任務有幾個步驟，每個步驟等待一種遊戲事件（見 WorldState.game_event）。
## 進度存在 WorldState 裡，所以會跟著檢查點和存檔走。
##
## 步驟類型：
##   enter_area  進入某個區域（target = 區域 id）
##   interact    和某個有名字的物件互動（target = 物件名稱，見 Areas 的 names）
##   collect     撿到某個有名字的物件
##   defeat      打倒某個 Boss（target = Boss id）
## requires：前置任務，全部完成後這個任務才會出現。
## reward：完成時給的東西（bottles = 空瓶數、intel = 取得某區域的巡邏情報、items = {物品: 數量}、
##         flag = 設定一個旗標，例如讓隱藏的補給出現）。
## radio：有這個欄位的支線，要先在安全屋用無線電「聽到」才會出現（內容就是無線電訊息）。
extends Node

signal mission_updated(mission_id: String)
signal mission_completed(mission_id: String)

const DATA := [
	{
		"id": "enter_station", "main": true,
		"title": "Get inside the station",
		"desc": "The blizzard will kill you out here. Find a way into the research station.",
		"steps": [{"type": "enter_area", "target": "station_1f"}],
	},
	{
		"id": "find_shelter", "main": true, "requires": ["enter_station"],
		"title": "Find somewhere safe",
		"desc": "There has to be a sealed room somewhere off the corridors. Find it and get on the radio.",
		"steps": [
			{"type": "enter_area", "target": "station_safe"},
			{"type": "interact", "target": "radio_safe"},
		],
	},
	{
		"id": "find_stairs", "main": true, "requires": ["find_shelter"],
		"title": "Reach the upper floor",
		"desc": "Kovac says the antenna controls are upstairs. The stairs are in the lounge.",
		"steps": [{"type": "enter_area", "target": "station_2f"}],
	},
	{
		"id": "director_records", "main": true, "requires": ["find_stairs"],
		"title": "Halvorsen's records",
		"desc": "The director's office is at the east end of the upper floor. The door needs a keycard - someone in the dorms had one.",
		"steps": [
			{"type": "collect", "target": "keycard_2f"},
			{"type": "interact", "target": "director_terminal"},
		],
		"reward": {"access": 2},
	},
	{
		"id": "restore_power", "main": true, "requires": ["director_records"],
		"title": "Restore power",
		"desc": "The B1 generator ran dry. There's diesel at the fuel depot east of the shore. Your level 2 card opens the basement door in the lab.",
		"steps": [
			{"type": "collect", "target": "fuel_can"},
			{"type": "interact", "target": "generator_b1"},
		],
	},
	{
		"id": "hangar_snowcat", "main": true, "requires": ["restore_power"],
		"title": "The hangar",
		"desc": "With power back, the hangar door north of the shore will open. The snowcat inside can reach the antenna. Something big was locked in there.",
		"steps": [
			{"type": "enter_area", "target": "hangar"},
			{"type": "defeat", "target": "tundra_mother"},
			{"type": "interact", "target": "snowcat"},
		],
	},
	{
		"id": "send_signal", "main": true, "requires": ["hangar_snowcat"],
		"title": "The antenna",
		"desc": "Climb to the comms deck at the top of the antenna tower and get a message off the island. What you ask for is up to you.",
		"steps": [
			{"type": "enter_area", "target": "tower_top"},
			{"type": "interact", "target": "uplink"},
		],
		"reward": {"access": 3},
	},
	{
		"id": "the_shaft", "main": true, "requires": ["send_signal"],
		"title": "The drill shaft",
		"desc": "Whatever answered on 126.05 is coming. It all started in the drill shaft under B1 - your card now opens the door at the south end of the basement. End it at the bottom, then take the lift up.",
		"steps": [
			{"type": "enter_area", "target": "shaft_bottom"},
			{"type": "defeat", "target": "deep_well"},
			{"type": "interact", "target": "shaft_lift"},
		],
	},
	{
		"id": "depot_manifest", "main": false, "requires": ["director_records"],
		"radio": "KOVAC: \"Going to the depot? Find the manifest first. Mendez said something nests in that warehouse.\"",
		"title": "Depot manifest",
		"desc": "Read the manifest in the depot warehouse before you go for the fuel.",
		"steps": [{"type": "collect", "target": "manifest_depot"}],
		"reward": {"intel": "fuel_depot"},
	},
	{
		"id": "weather_station", "main": false, "requires": ["find_shelter"],
		"radio": "KOVAC: \"West of the shore there's the old weather camp. Pieter Lund kept the bunk hut heated - if anyone's alive out there, it's him. Dress for it: the wind out there kills.\"",
		"title": "The weather camp",
		"desc": "Cross the snowfield west of the shore. Find the warm bunk hut and find out what happened to Pieter Lund.",
		"steps": [
			{"type": "enter_area", "target": "huts_safe"},
			{"type": "collect", "target": "pieter_note"},
		],
		"reward": {"items": {"heat_pack": 2}},
	},
	{
		"id": "signal_fire", "main": false, "requires": ["weather_station"],
		"title": "Beacon on the ridge",
		"desc": "Pieter's note: light the beacon drum on the north ridge of the weather camp. The supply drone will drop by the south fence.",
		"steps": [{"type": "interact", "target": "beacon_drum"}],
		"reward": {"flag": "reveal:huts_cache"},
	},
	{
		"id": "supply_drop", "main": false,
		"title": "Supply drop",
		"desc": "One of the supply crates is still sitting on the dock where you unloaded it.",
		"steps": [{"type": "collect", "target": "supply_crate_shore"}],
		"reward": {"bottles": 1},
	},
	{
		"id": "lost_tape", "main": false, "requires": ["find_shelter"],
		"radio": "KOVAC: \"Mendez kept a recorder in the lab. If it's still there, it'll tell you how they hunt.\"",
		"title": "The researcher's tape",
		"desc": "Mendez's recorder should still be in the lab. It may reveal the patrol patterns.",
		"steps": [{"type": "collect", "target": "tape_lab"}],
		"reward": {"intel": "station_1f"},
	},
	{
		"id": "cold_lounge", "main": false, "requires": ["find_shelter"],
		"radio": "KOVAC: \"They go sluggish in the cold. The lab breaker controls the lounge heating. Use it.\"",
		"title": "Cut the heat",
		"desc": "The infected slow down in the cold. Shut off the lounge heating from the lab breaker.",
		"steps": [{"type": "interact", "target": "lounge_breaker"}],
	},
	{
		# 1962 年的記憶（燈籠站）：B1 的盤式錄音機 → 走到 1962 年錄音室的最後一捲帶子
		"id": "lantern_1962", "main": false, "requires": ["restore_power"],
		"radio": "KOVAC: \"The basement was a Cold War listening post before it was a station. LANTERN. If any of their reels survived, play one. I need to know what they heard in 1962.\"",
		"title": "LANTERN, 1962",
		"desc": "A reel-to-reel recorder sits in the B1 maintenance office. Play it, and find the last reel in the 1962 recording room.",
		"steps": [
			{"type": "interact", "target": "reel_b1"},
			{"type": "interact", "target": "reel_1962"},
		],
		"reward": {"items": {"antibiotic": 1}},
	},
	{
		# 郵輪「北極星號」：北港北邊的棧橋上船。甲板、船艙、貨艙，頂層甲板是 Boss 典獄長
		"id": "boreal_star", "main": false, "requires": ["find_shelter"],
		"radio": "KOVAC: \"There's a cruise ship stuck in the ice north of the harbor - the Boreal Star. It vanished eighteen months ago. If the Ark used it, the manifest will say for what. Get it.\"",
		"title": "The Boreal Star",
		"desc": "The cruise ship is frozen in the ice past the North Harbor pier. Find the Ark manifest in the cargo hold - and deal with whoever holds the sun deck.",
		"steps": [
			{"type": "enter_area", "target": "cruise_deck"},
			{"type": "interact", "target": "ark_manifest"},
			{"type": "defeat", "target": "warden"},
		],
		"reward": {"items": {"rifle_rounds": 6, "med": 1}},
	},
]


func _ready() -> void:
	WorldState.game_event.connect(_on_game_event)


func get_mission(mission_id: String) -> Dictionary:
	for m in DATA:
		if m.id == mission_id:
			return m
	return {}


func step_index(mission_id: String) -> int:
	return WorldState.get_flag("mission:" + mission_id, 0)


func is_done(mission_id: String) -> bool:
	return step_index(mission_id) >= get_mission(mission_id).steps.size()


func is_available(mission_id: String) -> bool:
	var m := get_mission(mission_id)
	if not _requirements_met(m):
		return false
	return not m.has("radio") or WorldState.has_flag("radio:" + mission_id)


func _requirements_met(m: Dictionary) -> bool:
	for req in m.get("requires", []):
		if not is_done(req):
			return false
	return true


## 在安全屋用無線電：收到所有「條件已經滿足、還沒聽過」的委託，回傳訊息文字。
func receive_radio() -> Array[String]:
	var messages: Array[String] = []
	for m in DATA:
		if m.has("radio") and _requirements_met(m) and not WorldState.has_flag("radio:" + m.id):
			WorldState.set_flag("radio:" + m.id)
			messages.append(m.radio)
			mission_updated.emit(m.id)
	return messages


func is_active(mission_id: String) -> bool:
	return is_available(mission_id) and not is_done(mission_id)


## 畫面上追蹤的任務：第一個進行中的主線任務。
func tracked_mission() -> Dictionary:
	for m in DATA:
		if m.main and is_active(m.id):
			return m
	return {}


## 任務指引的顏色：主線永遠是黃色；支線依勾選的順序：藍、紫、紅、綠、白
const MAIN_COLOR := Color(1.0, 0.85, 0.25)
const SIDE_COLORS := [Color(0.35, 0.65, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.35, 0.3), Color(0.4, 0.95, 0.5),
	Color(0.95, 0.95, 0.95)]


## 現在有箭頭的任務：[{mission, color}]。主線 = 目前進行中的那一個主線任務
func pinned() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if WorldState.pin_main():
		var m := tracked_mission()
		if not m.is_empty():
			out.append({"mission": m, "color": MAIN_COLOR})
	var i := 0
	for id in WorldState.pinned_sides():
		var m := get_mission(id)
		if not m.is_empty() and is_active(id):
			out.append({"mission": m, "color": SIDE_COLORS[i % SIDE_COLORS.size()]})
			i += 1
	return out


func is_pinned(mission_id: String) -> bool:
	for p in pinned():
		if p.mission.id == mission_id:
			return true
	return false


func pin_color(mission_id: String) -> Color:
	for p in pinned():
		if p.mission.id == mission_id:
			return p.color
	return Color(0, 0, 0, 0)


func list_visible() -> Array:
	return DATA.filter(func(m): return is_available(m.id))


func _on_game_event(kind: String, id: String) -> void:
	for m in DATA:
		if not is_active(m.id):
			continue
		var idx := step_index(m.id)
		var step: Dictionary = m.steps[idx]
		if step.type == kind and step.target == id:
			WorldState.set_flag("mission:" + m.id, idx + 1)
			mission_updated.emit(m.id)
			if is_done(m.id):
				_give_reward(m.get("reward", {}))
				mission_completed.emit(m.id)


func _give_reward(reward: Dictionary) -> void:
	if reward.has("bottles"):
		WorldState.bottles = WorldState.bottles + int(reward.bottles)
	if reward.has("access"):
		WorldState.access_level = int(reward.access)
	if reward.has("items"):
		for item_id in reward.items:
			WorldState.inv_add(item_id, int(reward.items[item_id]))
	if reward.has("flag"):
		WorldState.set_flag(String(reward.flag))
	if reward.has("intel"):
		WorldState.set_flag("intel:" + String(reward.intel))
