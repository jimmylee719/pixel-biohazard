## 物品資料。物品欄、撿取、使用都從這裡查。
##   stack  一格最多疊幾個
##   kind   throwable（投擲）、ammo（彈藥）、heal（補血）、cure（降低感染）、weapon（武器，在物品欄「使用」= 裝備）
class_name Items
extends RefCounted

const DATA := {
	"bottle": {"name": "Empty bottle", "stack": 3, "kind": "throwable",
		"desc": "Throw it to make noise somewhere else."},
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
}


static func get_item(item_id: String) -> Dictionary:
	assert(DATA.has(item_id), "沒有這個物品：%s" % item_id)
	return DATA[item_id]


static func display_name(item_id: String) -> String:
	return get_item(item_id).name
