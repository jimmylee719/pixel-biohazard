## 物品資料。物品欄、撿取、使用都從這裡查。
##   stack  一格最多疊幾個
##   kind   throwable（投擲；在物品欄「使用」= 準備投擲這種）、ammo（彈藥）、heal（補血）、cure（降低感染）、
##          weapon（武器，在物品欄「使用」= 裝備）、craft（材料，在物品欄「使用」= 組合，見 recipe）、
##          melee（近戰武器：裝備後取代小刀）、attach（配件）、kit（隨身裝備：小刀、打火機，一直帶著、不佔格子）、campfire（可燃物：用打火機生一堆火）
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
	"suppressor": {"name": "Suppressor", "stack": 1, "kind": "attach",
		"desc": "Threads onto the pistol. Use it to fit or remove. A fitted pistol is far quieter - only things close by will hear it."},
	"shotgun": {"name": "Shotgun", "stack": 1, "kind": "weapon",
		"desc": "Pump shotgun. Devastating up close, useless at range. 2-shell tube."},
	"shells": {"name": "Shotgun shells", "stack": 8, "kind": "ammo",
		"desc": "12 gauge. Count every one."},
	"rifle": {"name": "Hunting rifle", "stack": 1, "kind": "weapon",
		"desc": "Bolt-action, scoped. For the bears, the station manual said. Hits like a truck; the whole island hears it."},
	"rifle_rounds": {"name": "Rifle rounds", "stack": 10, "kind": "ammo",
		"desc": ".308. Heavy brass in a cardboard box."},
	"nailgun": {"name": "Nail gun", "stack": 1, "kind": "weapon",
		"desc": "Pneumatic, from the workshop. Weak, but barely a whisper. Nobody comes running."},
	"nails": {"name": "Nail strip", "stack": 36, "kind": "ammo",
		"desc": "Collated framing nails. Twelve to a strip."},
	"flare_gun": {"name": "Flare gun", "stack": 1, "kind": "weapon",
		"desc": "Single shot. Wherever the flare lands, it burns and lights up the dark."},
	"flares": {"name": "Flares", "stack": 4, "kind": "ammo",
		"desc": "Signal flares. Red, hot, and very bright."},
	"fire_axe": {"name": "Fire axe", "stack": 1, "kind": "melee",
		"desc": "Heavy and slow. Equip it in place of the knife. Splits crates and barricades in one blow."},
	"crowbar": {"name": "Crowbar", "stack": 1, "kind": "melee",
		"desc": "A metre of hooked steel. Equip it in place of the knife. Long reach, floors most things, pries crates open."},
	"revolver": {"name": "Revolver", "stack": 1, "kind": "weapon",
		"desc": "Six-shot .357 from an officer's desk. Stops almost anything in one round. Slow to reload and very loud."},
	"magnum_rounds": {"name": ".357 rounds", "stack": 12, "kind": "ammo",
		"desc": "Fat brass for the revolver. Rare."},
	"smg": {"name": "Submachine gun", "stack": 1, "kind": "weapon",
		"desc": "Compact 9mm, folding stock. Hold the trigger to keep firing. Eats pistol rounds fast."},
	"crossbow": {"name": "Crossbow", "stack": 1, "kind": "weapon",
		"desc": "A hunter's crossbow. Silent, hits hard, one bolt at a time. Bolts that hit can be pulled back out."},
	"bolts": {"name": "Crossbow bolts", "stack": 8, "kind": "ammo",
		"desc": "Carbon shafts, broadhead tips. Reusable if you can reach the body."},
	"dart_pistol": {"name": "Tranquilliser pistol", "stack": 1, "kind": "weapon",
		"desc": "A vet's dart pistol from the station kennel. Puts a person to sleep for most of a minute; slows the infected for a while. Nobody dies."},
	"darts": {"name": "Sedative darts", "stack": 12, "kind": "ammo",
		"desc": "Veterinary sedative. Four to a clip."},
	"carbine": {"name": "LANTERN carbine", "stack": 1, "kind": "weapon",
		"desc": "A 1962 listening-post carbine with a factory suppressor. Rifle rounds, eight to a magazine, and barely louder than a cough."},
	"harpoon": {"name": "Harpoon gun", "stack": 1, "kind": "weapon",
		"desc": "A whaler's shoulder gun, older than the station. Fires crossbow bolts with a charge behind them. One shot; it goes through almost anything."},
	"knife": {"name": "Combat knife", "stack": 1, "kind": "kit",
		"desc": "Fixed blade, always on your vest. Slash, slash, thrust. Sheathe it to fight bare-handed instead: jab, hook, kick."},
	"lighter": {"name": "Lighter", "stack": 1, "kind": "kit",
		"desc": "Brass petrol lighter. Lights oil drums, firebombs and kindling. It never leaves your pocket."},
	"kindling": {"name": "Kindling", "stack": 4, "kind": "campfire",
		"desc": "Split pallet wood and oily rags. Use it to light a small fire at your feet: warmth for a while - and light anyone can see."},
}

## 武器改裝件（Extras 的 mod）：拿了就一直生效、不佔格子（旗標 mod:<id>），效果在 PlayerCombat.weapon_stats()
const MODS := {
	"ext_mag": {"name": "Extended magazine", "desc": "Pistol and SMG hold half again as many rounds."},
	"red_dot": {"name": "Reflex sight", "desc": "Your aim settles much faster."},
	"foregrip": {"name": "Foregrip", "desc": "Less kick: your aim recovers quicker between shots."},
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
	"j": ["rifle", 1],
	"k": ["rifle_rounds", 4],
	"n": ["nailgun", 1],
	"m": ["nails", 12],
	"v": ["flare_gun", 1],
	"y": ["flares", 2],
	"z": ["fire_axe", 1],
	"^": ["suppressor", 1],
	"!": ["revolver", 1],
	":": ["magnum_rounds", 4],
	"$": ["smg", 1],
	"*": ["crossbow", 1],
	"|": ["bolts", 3],
	"?": ["crowbar", 1],
	";": ["kindling", 1],
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
