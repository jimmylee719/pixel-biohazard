## 追加的調查點（v0.10）：不改地圖文字就能在某一格放東西。Areas 在讀正式地圖時把它們寫進地圖（符號 %），
## 所以 names、hidden、存檔 key、合併地圖的位移都照舊運作。座標是「那個區域自己的格子」，那一格原本要是地板。
## 改了地圖之後跑測試：位置不是地板會被 _test_extras 抓到。
##   kind = "mod"   武器改裝件（Items.MODS；拿了就永久生效、不佔格子，旗標 mod:<id>）
##   kind = "chart" 藏寶圖：設定 reveal 旗標 → 藏起來的特殊武器出現、任務清單多一條「武器藏匿點」可以開箭頭導航、地圖上出現藍色星號
##   kind = "item"  一般物品（item、count）；hidden = 要有這個旗標才會出現；name = 任務用的名字
class_name Extras
extends RefCounted

const SYMBOL := "%"

const DATA := {
	"station_1f": {
		"42,11": {"kind": "mod", "id": "ext_mag"},
	},
	"station_2f": {
		"34,1": {"kind": "chart", "id": "harpoon", "reveal": "reveal:harpoon", "mission": "cache_harpoon",
			"text": "WHALER'S SKETCH: \"Old harbour, west shed, behind the lockers. Grandfather's harpoon gun still hangs there. Oiled it myself in the spring. - Ivo\""},
	},
	"north_harbor": {
		"10,12": {"kind": "item", "item": "harpoon", "count": 1, "hidden": "reveal:harpoon", "name": "cache_harpoon"},
	},
	"gate_one_base": {
		"31,2": {"kind": "chart", "id": "carbine", "reveal": "reveal:carbine", "mission": "cache_carbine",
			"text": "ACCORD INVENTORY, 1962 (photocopy): \"LANTERN post, recording room: one suppressed carbine, sealed with the reels. Never collected.\""},
		"44,1": {"kind": "mod", "id": "red_dot"},
	},
	"station_b1": {
		"25,13": {"kind": "item", "item": "carbine", "count": 1, "hidden": "reveal:carbine", "name": "cache_carbine"},
	},
	"cruise_hold": {
		"42,10": {"kind": "mod", "id": "foregrip"},
	},
}


## 把追加的調查點寫進一份地圖資料（回傳新的一份，不動原本的）
static func apply(areas: Dictionary) -> Dictionary:
	var out := areas.duplicate(true)
	for id in DATA:
		if not out.has(id):
			continue
		var a: Dictionary = out[id]
		var rows: Array = a.map.duplicate()
		var extras: Dictionary = a.get("extras", {})
		for key in DATA[id]:
			var xy := String(key).split(",")
			var x := int(xy[0])
			var y := int(xy[1])
			if y >= rows.size() or x >= String(rows[y]).length() or String(rows[y])[x] != ".":
				push_warning("Extras：%s %s 不是地板，略過" % [id, key])
				continue
			var row := String(rows[y])
			rows[y] = row.substr(0, x) + SYMBOL + row.substr(x + 1)
			var info: Dictionary = DATA[id][key]
			extras[key] = info
			if info.has("name"):
				if not a.has("names"):
					a["names"] = {}
				a.names[key] = info.name
			if info.has("hidden"):
				if not a.has("hidden"):
					a["hidden"] = {}
				a.hidden[key] = info.hidden
		a.map = rows
		a["extras"] = extras
	return out
