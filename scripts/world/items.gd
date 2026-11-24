## 物品資料。物品欄、撿取、使用都從這裡查。
##   stack  一格最多疊幾個
##   kind   throwable（投擲；在物品欄「使用」= 準備投擲這種）、ammo（彈藥）、heal（補血）、cure（降低感染）、
##          weapon（武器，在物品欄「使用」= 裝備）、craft（材料，在物品欄「使用」= 組合，見 recipe）
class_name Items
extends RefCounted

const DATA := {
	"bottle": {"name": "Empty bottle", "stack": 3, "kind": "throwable",
		"desc": "Throw it to make noise somewhere else. Loud glass."},
	"stone": {"name": "Stone", "stack": 5, "kind": "throwable",
		"desc": "Clacks off the ice. Quieter than glass - good for a nudge."},
	"molotov": {"name": "Firebomb", "stack": 2, "kind": "throwable",
		"desc": "Bottle, ethanol, a strip of your sleeve. Your lighter does the rest. Burns anything standing in it."},
	"heat_pack": {"name": "Heat pack", "stack": 3, "kind": "warm", "warm": 60,
		"desc": "Crack it and stuff it in your jacket. Buys you time in the cold."},
	"ethanol": {"name": "Lab ethanol", "stack": 3, "kind": "craft", "recipe": {"needs": "bottle", "makes": "molotov"},
		"desc": "Use it with an empty bottle to make a firebomb."},
	"ammo": {"name": "Pistol rounds", "stack": 24, "kind": "ammo",
		"desc": "9mm. Never enough."},
	"med": {"name": "First aid kit", "stack": 2, "kind": "heal", "heal": 45,
		"desc": "Stops the bleeding. Restores health."},
	"antibiotic": {"name": "Antibacterial shot", "stack": 2, "kind": "cure", "cure": 60,
		"desc": "Experimental. Pushes the infection back."},
	"pistol": {"name": "Pistol", "stack": 1, "kind": "weapon",
		"desc": "Station security sidearm. 8-round magazine."},
	"shotgun": {"name": "Shotgun", "stack": 1, "kind": "weapon",
		"desc": "Pump shotgun. Devastating up close, useless at range. 2-shell tube."},
	"shells": {"name": "Shotgun shells", "stack": 8, "kind": "ammo",
		"desc": "12 gauge. Count every one."},
}

## 地圖符號 → [物品, 數量]
const MAP_PICKUPS := {
	"A": ["ammo", 6],
	"M": ["med", 1],
	"V": ["antibiotic", 1],
	"W": ["pistol", 1],
	"S": ["shotgun", 1],
	"L": ["shells", 3],
	"I": ["ethanol", 1],
	"u": ["heat_pack", 1],
}

## 投擲物：落地聲音大小（格）、會不會起火
const THROWABLES := {
	"stone": {"noise_tiles": 4.0, "fire": false, "color": Color(0.55, 0.55, 0.6)},
	"bottle": {"noise_tiles": 6.0, "fire": false, "color": Color(0.6, 0.9, 0.7)},
	"molotov": {"noise_tiles": 5.0, "fire": true, "color": Color(1.0, 0.55, 0.2)},
}
## 物品欄裡投擲物的優先順序（準備的那種用完時，換下一種）
const THROW_ORDER := ["stone", "bottle", "molotov"]


static func get_item(item_id: String) -> Dictionary:
	assert(DATA.has(item_id), "沒有這個物品：%s" % item_id)
	return DATA[item_id]


static func display_name(item_id: String) -> String:
	return TranslationServer.translate(get_item(item_id).name)
