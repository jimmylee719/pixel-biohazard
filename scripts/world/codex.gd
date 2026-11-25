## 圖鑑：遇過的感染體、人類敵人，和拿過的武器。手機的「檔案」App 顯示。
## 敵人第一次被主角看到時解鎖（Enemy.species），殺掉會記次數；武器第一次撿到時解鎖。
## 資料片新增敵人／武器：在這裡加一筆就好。sprite = Art.tex 的路徑（"" = 沒有圖，畫剪影）。
class_name Codex
extends RefCounted

const ENTRIES := {
	# ── 感染體 ──
	"watcher": {"group": "infected", "name": "Watcher", "sprite": "watcher/walk_down_0",
		"desc": "Station staff, still in their coveralls. Blind - the frost took the eyes first - but they hear everything, and they still walk the rounds they walked alive.",
		"tip": "Sneak behind it. Cold slows it down."},
	"sleeper": {"group": "infected", "name": "Sleeper", "sprite": "watcher/walk_down_0",
		"desc": "A host gone dormant. It lies among the real dead and looks exactly like them - except for the faint glint of crystal, now and then.",
		"tip": "Watch the bodies before you walk past. Heat or noise wakes it."},
	"listener": {"group": "infected", "name": "Chimer", "sprite": "listener/walk_down_0",
		"desc": "The bone has grown into a resonator. It clicks and listens to the echo, like a bat. Light means nothing to it.",
		"tip": "Stand still while the click passes over you. It shrieks for help when it finds you."},
	"crawler": {"group": "infected", "name": "Crawler", "sprite": "crawler/walk_right_0",
		"desc": "Bent so far forward it walks on its hands. It lives in the ducts and under the floors, and it feels footsteps through the ground.",
		"tip": "No eyes at all. Walk, don't run, and it never knows you were there."},
	"husk": {"group": "infected", "name": "Husk", "sprite": "husk/walk_down_0",
		"desc": "The colony has filled this one up like a balloon. Slow, enormous, and one grab carries a frightening dose of spores.",
		"tip": "Don't trade blows. Burn it, or just walk away."},
	"chorister": {"group": "infected", "name": "Chorister", "sprite": "chorister/walk_down_0",
		"desc": "The crystals ring its throat like a collar. When it sees you, it sings - and everything nearby comes to listen.",
		"tip": "Kill it first, and quietly, or the whole floor comes."},
	"hound": {"group": "infected", "name": "Hound", "sprite": "hound/walk_right_0",
		"desc": "One of the station's sled dogs. Fast, and its nose still works. It hunts in the open snow.",
		"tip": "You can't outrun it. Get indoors and shut a door between you."},
	"tundra_mother": {"group": "infected", "name": "Tundra Mother", "sprite": "bear/walk_right_0",
		"desc": "A polar bear the colony has made its home. The hangar was hers long before you arrived.",
		"tip": "Its back is soft where the crystals split."},
	"deep_well": {"group": "infected", "name": "The Deep Well", "sprite": "well/exposed_0",
		"desc": "What was waiting at the bottom of the drill shaft. Forty thousand years asleep. Awake now.",
		"tip": "It has to breathe in before it sings."},
	# ── 人類 ──
	"guard": {"group": "human", "name": "Operative", "sprite": "guard/walk_down_0",
		"desc": "Gatekeeper troops, landed to contain the island - and everyone on it. Armed, trained, and they carry radios.",
		"tip": "Hit one mid-call to cut the radio. If the alert goes up, hide and wait it out."},
	# ── 武器 ──
	"knife": {"group": "weapon", "name": "Survival knife", "sprite": "props/knife",
		"desc": "Your own. Quiet, always there. From behind, one cut is enough.", "tip": "Slash, punch, kick - chain them."},
	"pistol": {"group": "weapon", "name": "Pistol", "sprite": "props/pistol",
		"desc": "Station security sidearm. Eight rounds.", "tip": "Hold aim to steady it before you fire."},
	"shotgun": {"group": "weapon", "name": "Shotgun", "sprite": "props/shotgun",
		"desc": "Pump action. Two shells. Ends arguments at close range.", "tip": "Useless past a few steps."},
	"rifle": {"group": "weapon", "name": "Hunting rifle", "sprite": "props/rifle",
		"desc": "Scoped, bolt-action. The loudest thing on the island.", "tip": "One shot, then move."},
	"nailgun": {"group": "weapon", "name": "Nail gun", "sprite": "props/nailgun",
		"desc": "Pneumatic, almost silent. Weak, but nothing comes running.", "tip": "For picking off strays without an alert."},
	"flare_gun": {"group": "weapon", "name": "Flare gun", "sprite": "props/flare_gun",
		"desc": "Sets the landing spot burning and lights the dark.", "tip": "Fire it past them to pull them away - or into them."},
	"fire_axe": {"group": "weapon", "name": "Fire axe", "sprite": "props/fire_axe",
		"desc": "Heavy, red, reliable. Replaces the knife's first swing.", "tip": "Barricades come down in one blow."},
}

const GROUP_TITLES := {"infected": "INFECTED", "human": "HUMAN", "weapon": "WEAPONS"}


## 圖鑑的順序（顯示用）
static func ids() -> Array:
	return ENTRIES.keys()


static func unlocked(id: String) -> bool:
	return id == "knife" or WorldState.codex_has(id)


static func count_unlocked() -> int:
	var n := 0
	for id in ENTRIES:
		if unlocked(id):
			n += 1
	return n
