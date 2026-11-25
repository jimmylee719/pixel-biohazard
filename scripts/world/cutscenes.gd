## 過場的內容（用遊戲畫面演出，見 CutscenePlayer、main.play_cutscene）。
## 區域資料的 "cutscene" 欄位 = 第一次進入這個區域（或房間）時播放哪一段，看過就不再播（旗標 scene:<id>）。
## 步驟：
##   {"caption": 文字, "time": 秒}      畫面上方的地點字幕
##   {"say": 說話的人, "text": 對白}    下方黑邊的對白（按鍵下一句）。說話的人用 [ ] 括起來 = 無線電
##   {"pan": Vector2i(格子), "time": 秒, "light": 半徑}  鏡頭移過去（light = 在那裡放一盞燈，看得清楚）
##   {"pan_enemy": 第幾隻, "time": 秒}  鏡頭移到這個區域的某隻敵人（並讓它顯示出來）
##   {"back": 秒}                       鏡頭回到主角
##   {"wait": 秒}、{"sfx": 音效 id}
## 文字一律英文原文，中文在 tools/locale/zh_TW.py。
class_name Cutscenes
extends RefCounted

const SHEN := "Shen"

const DATA := {
	"opening": [
		{"caption": "Greycrow Island, Arctic Ocean - November 2031", "time": 2.0},
		{"say": SHEN, "text": "Supply run seventeen. Drop the crates, refuel, home before dark."},
		{"say": SHEN, "text": "Nobody answered the landing call. Nobody came out for the crates."},
		{"pan": Vector2i(14, 9), "time": 2.2, "light": 90.0},
		{"say": SHEN, "text": "North Latitude Station. Thirty-one people work there. Not one light on."},
		{"say": SHEN, "text": "The rotor iced up on the way in. I'm not flying anywhere tonight."},
		{"back": 1.2},
		{"say": SHEN, "text": "Somebody in there has a radio. Find it."},
	],
	"station_first": [
		{"say": SHEN, "text": "Hello? It's the supply pilot. Your landing pad is buried..."},
		{"pan_enemy": 0, "time": 1.6},
		{"wait": 0.8},
		{"say": SHEN, "text": "...That was a person. The eyes are gone. Frost is growing out of the skin."},
		{"say": SHEN, "text": "It turned toward my voice - not toward my light."},
		{"back": 1.0},
		{"say": SHEN, "text": "Quiet, then. Stay out of its way."},
	],
	"clean_room": [
		{"say": SHEN, "text": "A clean room. Sealed door, its own air. Nothing followed me in."},
		{"say": SHEN, "text": "And a radio. I can save what I know here - and listen. Somebody might be talking."},
	],
	"hangar": [
		{"pan_enemy": 0, "time": 1.8},
		{"say": SHEN, "text": "Something big is breathing in there."},
		{"say": SHEN, "text": "The hangar isn't empty. It's hers."},
		{"back": 1.0},
	],
	"tower": [
		{"say": SHEN, "text": "The antenna tower. If the battery holds, one message reaches the mainland."},
		{"say": SHEN, "text": "One message. I'd better be sure who I'm calling."},
	],
	"shaft": [
		{"say": SHEN, "text": "Four hundred meters, straight down."},
		{"say": SHEN, "text": "The director's last note said only three words. 'It sings back.'"},
	],
	"harbor": [
		{"sfx": "radio_static"},
		{"say": "[GATE-2]", "text": "Gate One, Gate Two. Harbor perimeter is set. Nothing leaves this island."},
		{"pan_enemy": 0, "time": 1.6},
		{"say": "[GATE-1]", "text": "Copy. Survivors are to be held, not evacuated. Anything that runs, you stop."},
		{"say": SHEN, "text": "Soldiers. That isn't a rescue."},
		{"say": SHEN, "text": "Whoever sent them knew exactly what was on this island."},
		{"back": 1.0},
		{"say": SHEN, "text": "They carry radios. If one of them calls it in, the whole harbor comes down on me."},
	],
	"caves": [
		{"say": SHEN, "text": "The ice is glowing. The whole cave is full of it."},
		{"say": SHEN, "text": "And something down here is moving across the floor. On its hands."},
	],
	"east_wing": [
		{"say": SHEN, "text": "The east wing. Biology labs. The doors were sealed from this side."},
		{"pan_enemy": 1, "time": 1.6},
		{"say": SHEN, "text": "...Something in there is singing."},
		{"back": 1.0},
		{"say": SHEN, "text": "If it sees me, everything on this floor will hear it."},
	],
}
