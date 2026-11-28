## 裝備（紙娃娃）：頭部、身體、腳部三個欄位，穿上去外型會跟著變（tools/gen_pixel_art.py 的服裝圖組），也會影響能力。
## 一整套（同一個 set 的三件）有額外效果。特殊區域不是「沒穿不能去」，而是負面效果大很多：
##   孢子區（hazard）沒穿防護裝備會一直感染；暴風雪（warmth）沒穿保暖裝備體溫掉很快。
## 能力倍率（相乘；1 = 沒影響）：
##   warmth  失溫速度    hazard  孢子感染速度   armor  受到的傷害   speed  移動速度
##   noise   腳步聲大小  detect  被發現的速度   kick   踢的傷害
class_name Gear
extends RefCounted

const SLOTS := ["head", "body", "feet"]

const DATA := {
	# ── 身體 ──
	"parka": {"slot": "body", "name": "Expedition parka", "sprite": "player",
		"desc": "Your own orange parka. Warm enough, bright enough to be seen.", "stats": {}},
	"hazmat_suit": {"slot": "body", "name": "Hazmat suit", "sprite": "player_hazmat", "set": "hazmat",
		"desc": "Sealed biohazard suit. Keeps the spores out. Crinkles when you move.",
		"stats": {"hazard": 0.35, "warmth": 1.1, "speed": 0.95, "noise": 1.15}},
	"eod_armor": {"slot": "body", "name": "EOD armor", "sprite": "player_eod", "set": "eod",
		"desc": "Bomb disposal armor from the Gatekeeper stores. Shrugs off claws and bullets. Heavy.",
		"stats": {"armor": 0.55, "speed": 0.78, "noise": 1.4, "warmth": 0.85}},
	"sneaking_suit": {"slot": "body", "name": "Sneaking suit", "sprite": "player_sneak", "set": "sneak",
		"desc": "Dark, close-fitting, quiet. Not made for the Arctic.",
		"stats": {"noise": 0.75, "detect": 0.85, "warmth": 1.5}},
	"arctic_suit": {"slot": "body", "name": "Arctic suit", "sprite": "player_arctic", "set": "arctic",
		"desc": "Insulated white over-suit. The wind barely gets in.",
		"stats": {"warmth": 0.45, "speed": 0.97}},
	# ── 頭部 ──
	"wool_hat": {"slot": "head", "name": "Knit helmet cover", "sprite": "player_head_wool_hat",
		"desc": "Hand-knitted to stretch over a helmet. Smells of diesel.", "stats": {"warmth": 0.85}},
	"gas_mask": {"slot": "head", "name": "Filter hood", "sprite": "player_head_gas_mask", "set": "hazmat",
		"desc": "Seals over the helmet with twin filters. Your breathing gets loud in your own ears.", "stats": {"hazard": 0.5}},
	"eod_helmet": {"slot": "head", "name": "EOD outer shell", "sprite": "player_head_eod_helmet", "set": "eod",
		"desc": "Armored shell and blast visor that lock over your helmet.", "stats": {"armor": 0.85, "speed": 0.97}},
	"balaclava": {"slot": "head", "name": "Blackout shroud", "sprite": "player_head_balaclava", "set": "sneak",
		"desc": "Black shroud and a matte film for the visor. Hides the helmet's light.", "stats": {"detect": 0.9, "warmth": 0.9}},
	"snow_goggles": {"slot": "head", "name": "Snow cover", "sprite": "player_head_snow_goggles", "set": "arctic",
		"desc": "White helmet cover with a tinted lens. Keeps the blizzard off your visor.", "stats": {"warmth": 0.9}},
	# ── 腳部 ──
	"snow_boots": {"slot": "feet", "name": "Snow boots", "sprite": "",
		"desc": "Ordinary insulated boots.", "stats": {}},
	"hazmat_boots": {"slot": "feet", "name": "Hazmat boots", "sprite": "player_feet_hazmat_boots", "set": "hazmat",
		"desc": "Sealed rubber overboots.", "stats": {"hazard": 0.85, "speed": 0.97}},
	"eod_boots": {"slot": "feet", "name": "EOD boots", "sprite": "player_feet_eod_boots", "set": "eod",
		"desc": "Steel-shanked. Planted feet put your whole weight behind every cross and hook.", "stats": {"armor": 0.9, "speed": 0.95, "noise": 1.2, "kick": 1.6}},
	"soft_soles": {"slot": "feet", "name": "Soft soles", "sprite": "player_feet_soft_soles", "set": "sneak",
		"desc": "Felt-soled slippers over your socks. Silent - and cold.", "stats": {"noise": 0.6, "warmth": 1.15}},
	"crampons": {"slot": "feet", "name": "Crampon boots", "sprite": "player_feet_crampons", "set": "arctic",
		"desc": "Spiked boots for ice. Sure footing on the snow.", "stats": {"warmth": 0.9}},
}

## 一整套的額外效果
const SETS := {
	"hazmat": {"name": "Hazmat set", "desc": "Full seal: spores can't touch you.", "stats": {"hazard": 0.0}},
	"eod": {"name": "EOD set", "desc": "Full armor: knockback barely moves you.", "stats": {"armor": 0.75}},
	"sneak": {"name": "Sneaking set", "desc": "Full set: quieter still, harder to spot.", "stats": {"noise": 0.8, "detect": 0.85}},
	"arctic": {"name": "Arctic set", "desc": "Full set: the cold barely reaches you.", "stats": {"warmth": 0.6}},
}

## 開新遊戲時身上穿的、擁有的
const START_EQUIPPED := {"head": "", "body": "parka", "feet": "snow_boots"}
const START_OWNED := ["parka", "snow_boots"]
## 能力在畫面上的名稱
const STAT_NAMES := {"warmth": "Cold", "hazard": "Spores", "armor": "Damage", "speed": "Speed", "noise": "Noise",
	"detect": "Visibility", "kick": "Punch power"}


static func equipped() -> Dictionary:
	return WorldState.data.get("gear", START_EQUIPPED)


## 目前穿的裝備（含整套效果）的某項能力倍率
static func stat(key: String) -> float:
	var mult := 1.0
	var sets := {}
	for slot in SLOTS:
		var id: String = equipped().get(slot, "")
		if id == "" or not DATA.has(id):
			continue
		mult *= DATA[id].stats.get(key, 1.0)
		if DATA[id].has("set"):
			sets[DATA[id].set] = sets.get(DATA[id].set, 0) + 1
	for set_id in sets:
		if sets[set_id] >= 3:
			mult *= SETS[set_id].stats.get(key, 1.0)
	return mult


## 穿齊的套裝（沒有 = ""）
static func full_set() -> String:
	var first := ""
	for slot in SLOTS:
		var id: String = equipped().get(slot, "")
		if id == "" or not DATA.has(id) or not DATA[id].has("set"):
			return ""
		if first == "":
			first = DATA[id].set
		elif DATA[id].set != first:
			return ""
	return first


## 角色圖：本體（身體欄位決定）＋頭、腳的圖層
static func sprite_sets() -> Array[String]:
	var e := equipped()
	var body: String = DATA.get(e.get("body", "parka"), DATA.parka).sprite
	var out: Array[String] = [body if body != "" else "player"]
	for slot in ["feet", "head"]:
		var id: String = e.get(slot, "")
		if id != "" and DATA.has(id) and DATA[id].sprite != "":
			out.append(DATA[id].sprite)
	return out


## 能力的簡短說明（例：Cold -55%  Speed -22%）
static func describe(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for key in stats:
		var v: float = stats[key]
		var pct := roundi((v - 1.0) * 100.0)
		parts.append("%s %s%d%%" % [TranslationServer.translate(STAT_NAMES.get(key, key)), "+" if pct > 0 else "", pct])
	return "  ".join(parts)
