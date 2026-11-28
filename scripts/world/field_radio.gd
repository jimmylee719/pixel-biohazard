## 野戰無線電（v0.11）：隨時可以打（呼叫鍵 V／手把十字左／觸控 RADIO），有人找你時會響（右下角閃「來電」）。
## 參考經典潛行遊戲「隨時能用無線電找後方支援」的節奏，但外觀維持本作原創的野戰無線電（不做兩個頭像中間一個頻率）。
## 來電的時機：第一次進入某個區域、第一次看到某種敵人、第一次被發現、第一次遇到暴風雪、完成主線任務（RadioCalls）。
## 自己打過去：柯瓦奇依「現在追蹤的任務」告訴你該往哪走；1962 年的記憶裡打不通。
## 每一通只響一次（旗標 fcall:<種類>:<id>）。說話的人用 [ ] 括起來（同過場）；文字是英文原文，中文在 tools/locale/zh_TW.py。
class_name FieldRadio
extends RefCounted

const K := "[KOVAC]"

## 第一次進入這個區域（region id = 區域 id）
const AREA := {
	"station_1f": [[K, "That's the main hall. Everything on the ground floor opens onto it - mess, labs, the garage. Use the loop: never get cornered in a dead end."],
		[K, "If a calm voice tells you to 'please remain indoors', that's the station's home assistant. It started saying it the night the drill came up. Nobody programmed that."]],
	"station_2f": [[K, "Dormitories and offices. The floor is carpet up there - your boots are quieter, but so are theirs."],
		[K, "Halvorsen told the board the drill was a geological survey for an Arctic data centre. Nobody builds a data centre on Greycrow. Somebody wanted what was under the ice."]],
	"fuel_depot": [[K, "You're outside. Watch the cold bar. And Shen - snow keeps footprints. Anyone with eyes can follow them straight to you."],
		[K, "Weather changes fast out there. A blizzard hides you, but it eats your body heat."]],
	"station_b1": [[K, "The basement. Generator hall in the middle, the old listening post around it. The drill shaft door is at the south end."]],
	"weather_huts": [[K, "The weather camp. Three huts and an instrument field. Pieter kept one hut heated - find it before the wind finds you."]],
	"north_harbor": [[K, "The old whaling harbour. Those are Accord soldiers, not infected. They see in the dark well enough, and they carry radios."],
		[K, "If one of them gets a call off, the whole harbour comes looking. Take the radio man first, or don't be seen at all."]],
	"ice_caves": [[K, "Ice caves. Crawlers live under the floor down there. They feel your steps - walk soft, or walk on the far bank."]],
	"station_east_wing": [[K, "The isolation atrium. If one of the singers sees you, every infected on that floor will hear it. Kill it quietly or not at all."]],
	"gate_one_yard": [[K, "Gate One. A fenced yard, trucks, a gatehouse. Their headquarters is the building behind it."]],
	"gate_one_base": [[K, "Inside their base. Barracks, armoury, cells. Whatever they really came here for, the paperwork is in this building."]],
	"cruise_deck": [[K, "The Boreal Star. Ten decks and every window dark. Somebody is up on the sun deck with a rifle - stay under the overhangs."]],
	"cruise_interior": [[K, "The atrium. Hear that through the walls? That's not a recording."]],
	"tower_yard": [[K, "The antenna tower. If the dish is iced over, find the de-icer before you climb."]],
	"drill_shaft": [[K, "The shaft. Four hundred metres of it. Whatever is at the bottom has been waiting a very long time."]],
}

## 第一次看到這種敵人（Codex id）
const ENEMY := {
	"watcher": [[K, "Watchers. Station staff, still walking their rounds. Blind - they hunt by sound. Sneak, and you can pass within a metre."]],
	"listener": [[K, "A chimer. Hear the clicking? It's listening to the echo. Stand still when it clicks and it loses you."]],
	"sleeper": [[K, "Some of the bodies aren't dead, only cold. If the heating comes on, they wake. Give every body a wide berth."]],
	"crawler": [[K, "A crawler. It feels footsteps through the floor. Walking isn't quiet enough near one - sneak."]],
	"husk": [[K, "A husk. Slow, but one grab is a heavy dose of spores. Don't let it corner you."]],
	"chorister": [[K, "A singer. If it sees you, it calls everything nearby. Kill it first, or don't be seen."]],
	"runner": [[K, "A runner - freshly turned. Fast. You won't outrun it in the open; break line of sight and hide."]],
	"spitter": [[K, "A spitter. It throws spore clots from a distance. Close the gap or stay behind cover."]],
	"brute": [[K, "The front of that one is armour. Get behind it. Throw something, let it turn, then shoot its back."]],
	"hound": [[K, "The dogs. Their noses still work - they'll follow your tracks in the snow, and they're faster than you."]],
	"guard": [[K, "Soldiers. Unlike the infected, they see. Stay out of their cone of view, and stay out of the light."]],
}

## 其他第一次
const EVENT := {
	"alert": [[K, "They've seen you. Break line of sight and keep moving. When they lose you they'll search - wait it out somewhere dark."]],
	"blizzard": [[K, "Blizzard. Nobody out there can see or hear much - including you. Move now if you need to, but you'll freeze twice as fast."]],
	"clear": [[K, "The sky's cleared. Aurora. Pretty - and every sentry can see three times as far. Stay off the open snow."]],
	"tracks": [[K, "Someone's following your footprints. Lead them into a loop - or wait for the snow to cover them."]],
	"resonance": [[K, "Did you hear that ring when it went down? The crystal in their bones shatters and sings. Every one of them nearby heard it too - and anything asleep is awake now."],
		[K, "Kill them only when you have to. Knock them down and walk away, or go around."]],
	"lure": [[K, "You threw the song at them. They'll stand there and listen like it's a sermon. Don't throw it near the sleepers unless you want them up."]],
	"tide_warning": [[K, "Hear that static climbing? The song under the ice comes in tides. Every few minutes it swells - and the old LANTERN horn goes off with it."],
		[K, "You've got about thirty seconds. Get indoors, get in a locker, get somewhere they won't stumble into you."]],
	"tide": [[K, "That's the horn. They wired it to the receiver in 1962 so the night shift could put their earmuffs on. Nobody ever unplugged it."],
		[K, "While it sings, every infected thing on this island is up and walking - even the ones that look dead. They hear better, too. Stay still. It passes in a minute."],
		[K, "When it fades, the sleepers lie down wherever they are. So the room you crossed before won't be the same room."]],
}


## 一句一步的過場資料（main.play_radio 用）
static func steps(lines: Array) -> Array:
	var out: Array = [{"sfx": "radio_static"}]
	for l in lines:
		out.append({"say": l[0], "text": l[1]})
	return out


## RadioCalls 的「KOVAC: "..."」轉成 [說話的人, 文字]（中文翻的是整句，所以原句照用，說話的人另外標）
static func from_radio_calls(texts: Array) -> Array:
	var out: Array = []
	for t in texts:
		out.append(["", t])
	return out
