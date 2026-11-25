## 過場的內容（用遊戲畫面演出，見 CutscenePlayer、main.play_cutscene）。
## 區域資料的 "cutscene" 欄位 = 第一次進入這個區域（或房間）時播放哪一段，看過就不再播（旗標 scene:<id>）。
## 步驟：
##   {"caption": 文字, "time": 秒}      畫面上方的地點字幕
##   {"say": 說話的人, "text": 對白}    下方黑邊的對白（按鍵下一句）。說話的人用 [ ] 括起來 = 無線電
##   {"pan": Vector2i(格子), "time": 秒, "light": 半徑}  鏡頭移過去（light = 在那裡放一盞燈，看得清楚）
##   {"pan_enemy": 第幾隻, "time": 秒}  鏡頭移到這個區域的某隻敵人（並讓它顯示出來；合併進來的區域從自己的第一隻算）
##   {"back": 秒}                       鏡頭回到主角
##   {"wait": 秒}、{"sfx": 音效 id}
##   {"era": "1962"／"2099"／""}  換時代的畫面色調（過場結束後回到區域本來的時代）
## 文字一律英文原文，中文在 tools/locale/zh_TW.py。
class_name Cutscenes
extends RefCounted

const SHEN := "Shen"

const DATA := {
	"opening": [
		# 冷開場：1962 年的監聽站收到冰層底下的訊號，再跳到現在
		{"era": "1962"},
		{"caption": "LANTERN Listening Post - March 1962", "time": 2.2},
		{"sfx": "radio_static"},
		{"say": "[SATO]", "text": "Carrier on one-two-six-oh-five. Again. It's coming from under the ice."},
		{"say": "[SATO]", "text": "It isn't Morse, Major. It's music. And under the music... a city."},
		{"era": "2099"},
		{"say": "[THE CHOIR]", "text": "...hold position. we will come to you. we always come to you..."},
		{"era": "1962"},
		{"say": "[SATO]", "text": "It just said my name."},
		{"era": ""},
		{"caption": "Sixty-four years later", "time": 1.6},
		{"caption": "Greycrow Island, Arctic Ocean - November 2026", "time": 2.0},
		{"say": SHEN, "text": "Supply run seventeen. Drop the crates, refuel, home before dark."},
		{"say": SHEN, "text": "Nobody answered the landing call. Nobody came out for the crates."},
		{"pan": Vector2i(11, 9), "time": 2.2, "light": 90.0},
		{"say": SHEN, "text": "North Latitude Station. Thirty-one people work there. Not one light on."},
		{"say": SHEN, "text": "The rotor iced up on the way in. I'm not flying anywhere tonight."},
		{"back": 1.2},
		{"say": SHEN, "text": "Somebody in there has a radio. Find it."},
	],
	"station_first": [
		{"say": SHEN, "text": "Hello? It's the supply pilot. Your landing pad is buried..."},
		{"pan_enemy": 0, "time": 1.6},
		{"wait": 0.8},
		{"say": SHEN, "text": "...That was a person. The eyes are glass. Something under the skin is clicking, like a radio between stations."},
		{"say": SHEN, "text": "It turned toward my voice - not toward my light."},
		{"back": 1.0},
		{"say": SHEN, "text": "Quiet, then. Stay out of its way."},
	],
	"clean_room": [
		{"say": SHEN, "text": "A clean room. Sealed door, its own air. Nothing followed me in."},
		{"say": SHEN, "text": "And a radio. I can save what I know here - and listen. Somebody might be talking."},
		{"sfx": "radio_static"},
		{"say": "[KOVAC]", "text": "...anyone at North Latitude? This is Ana Kovac, on the mainland relay. Is anyone still alive up there?"},
		{"say": SHEN, "text": "Supply pilot. Shen Ruoning. Your station is full of people who aren't people anymore."},
		{"say": "[KOVAC]", "text": "Then listen carefully. They aren't sick - they're tuned. They hear everything. Stay quiet, stay cold - and stay away from the drill shaft."},
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
		{"say": SHEN, "text": "The east wing. Signal labs. The doors were sealed from this side."},
		{"pan_enemy": 1, "time": 1.6},
		{"say": SHEN, "text": "...Something in there is singing."},
		{"back": 1.0},
		{"say": SHEN, "text": "If it sees me, everything on this floor will hear it."},
	],
	"gate_one": [
		{"caption": "Gate One - Gatekeeper forward base", "time": 2.0},
		{"sfx": "radio_static"},
		{"say": "[GATE-1]", "text": "All posts, Gate One. Ice tunnel is unwatched since the dogs went bad. Double the yard."},
		{"pan_enemy": 0, "time": 1.6},
		{"say": SHEN, "text": "Their headquarters. Fences, trucks, a gatehouse - and somewhere inside, whoever gives the orders."},
		{"back": 1.0},
		{"say": SHEN, "text": "If anyone on this island knows what's really going on, it's in there."},
	],
	"reel_b1": [
		{"say": SHEN, "text": "A reel-to-reel recorder. Older than the station. The label says LANTERN, 15-III-1962."},
		{"say": SHEN, "text": "The tape is warm. It shouldn't be warm."},
		{"sfx": "radio_static"},
		{"era": "1962"},
		{"say": SHEN, "text": "The hiss fills the room - and the room changes around it."},
	],
	"lantern_enter": [
		{"caption": "LANTERN Listening Post - 15 March 1962, 02:40", "time": 2.2},
		{"say": SHEN, "text": "This is the basement. Sixty-four years ago. I can smell the cigarettes."},
		{"say": SHEN, "text": "The signal kept everything that ever listened to it. Including this night."},
		{"pan_enemy": 0, "time": 1.6},
		{"say": SHEN, "text": "Soldiers. If they see me, the memory starts over. The recording room is at the far end - ON AIR."},
		{"back": 1.0},
	],
	"lantern_signal": [
		{"caption": "Recording room - 03:12", "time": 1.8},
		{"sfx": "radio_static"},
		{"say": "[SATO]", "text": "Last reel. If the Major finds this one, it goes to Geneva with the rest."},
		{"say": "[SATO]", "text": "Whoever is playing this: it isn't a disease. It's a broadcast. It changes whoever listens long enough."},
		{"era": "2099"},
		{"caption": "126.05 MHz - origin: 2099", "time": 2.0},
		{"say": "[THE CHOIR]", "text": "we are the city at the end of your century. one voice. no cold, no dark, no alone."},
		{"say": "[THE CHOIR]", "text": "we are sending ourselves back so that you will build us. thank you for listening."},
		{"era": "1962"},
		{"say": "[SATO]", "text": "The Accord is meeting on the twentieth. They'll bury it under the ice and call it a weather station."},
		{"say": "[SATO]", "text": "I hid supplies in the maintenance room. For whoever comes next. It said someone would."},
		{"era": ""},
		{"say": SHEN, "text": "The reel runs out. Sixty-four years, and it's the same voice on the same frequency."},
	],
	"gate_base": [
		{"say": SHEN, "text": "Barracks, an armory, holding cells. They built a whole base in a month."},
		{"pan_enemy": 4, "time": 1.8},
		{"say": SHEN, "text": "...and a lab. Antennas, speakers, people strapped to chairs. Same frequency as the station."},
		{"back": 1.0},
		{"say": SHEN, "text": "They weren't jamming it. They were recording it."},
	],
}
