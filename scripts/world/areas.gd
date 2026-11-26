## 灰鴉島各區域的資料。每個區域是一張文字地圖＋設定，由 Level 讀取建立。
##
## 地圖符號：
##   #  牆壁／岩壁          C  櫃子、實驗桌、岩石、殘骸（擋路、擋視線）
##   H  置物櫃（可躲藏）     .  地板／雪地
##   D  門（走上去就切換區域，見 doors）
##   P  遊戲開始的位置（只有起點區域有）
##   B  空瓶   K  補給箱   T  錄音帶   X  配電箱   G  樓梯（原型終點）
##   A  彈藥   M  急救包   V  抗菌藥劑   W  手槍（數量見 Items.MAP_PICKUPS）
##   R  無線電（存檔、接收支線、調頻）   Y  儲物箱（所有安全屋共用）
##   N  筆記／白板（可重複閱讀）   S  散彈槍   L  散彈
##   Q  權限卡（提升權限等級，不佔物品欄）   O  終端機   x  屍體（裝飾；和凍眠體很像）
##   F  燃料桶（雙手搬運）   E  發電機   Z  雪地車（開往 snowcat_to）
##   U  上行終端機（天線塔：發出訊號、選擇結局方向）
##   J  升降機（鑽探井底：打倒最終 Boss 後搭上去 = 結局）
##   I  實驗室酒精（＋空瓶 = 汽油彈）
##   環境互動（小寫）：o 油桶（打火機點燃）  w 木箱（踢開／刀割，內容見 loot）
##                     p 封住通道的木板（同上，拆掉 = 捷徑）  q 滅火器  r 碎石堆（撿石頭）
##   t 裝備（紙娃娃；哪一件見區域資料 gear）  l 區域地圖（撿到 = 整張地圖顯示）  s 保險箱（打開 = 解鎖隱藏要素的情報）
##   武器（小寫）：j 獵槍  k 獵槍子彈  n 釘槍  m 釘條  v 信號槍  y 信號彈  z 消防斧
##   新武器：! 左輪  : .357 子彈  $ 衝鋒槍  * 十字弓  | 弩箭  ? 鐵撬  ; 可燃物（木柴，用打火機生火取暖）
##   &  盤式錄音機（播放 = 走進 1962 年的記憶，見 reels）
##   +  室內自動門（有人靠近就開；關著時看不到門後面。整排 + 是一道寬門）
##   =  窗戶（走不過去、看得穿；靠過去看 = 第一人稱視角）
##   1～9、a～i  敵人巡邏點，哪些點屬於哪隻敵人見 enemies
##
## 每個區域的欄位：
##   title      顯示名稱
##   outdoor    戶外區域（地板顏色不同；之後會有失溫）
##   map        文字地圖
##   enemies    [{type, route}]，route 是巡邏點字元，依序來回巡邏
##   zones      溫度區域 {名稱: {rect（格子座標）, heated（初始有沒有暖氣）}}
##   breakers   配電箱控制的區域，依地圖上 X 出現的順序
##   doors      {門的 id: {cell, to（目標區域）, spawn_dir（進入這個區域時往哪個方向站一格）}}
##              兩個區域裡 id 相同的門互相連通
##   safe       安全屋：沒有敵人、燈光溫暖、有無線電（存檔＋接支線）和儲物箱
##   entries    其他入口 {id: 格子}（例如無線電旁邊，存檔後從這裡重來）
##   stairs     {"x,y": 目標區域}，G 樓梯通往哪裡（到達後站在目標區域的 entries.stairs）
##   access     門的欄位：需要的權限等級（WorldState.access_level）
##   power      門的欄位：true = 電動門，要先恢復電力
##   camera     "fixed" = 鏡頭固定看整個區域（Boss 戰），預設跟隨主角
##   boss       Boss 的顯示名稱（有的話畫面上方顯示血條）
##   powered_area  恢復電力後這個區域的燈會亮
##   indoor_rects  戶外區域裡的室內空間（地板畫成室內）
##   zones 的 powered：恢復電力後這個溫度區域會有暖氣（zone 依字典順序比對，先寫的優先）
##   names      {"x,y": 名稱}，給任務系統辨認特定物件用
##   hidden     {"x,y": 旗標}，這格的物品要等旗標設定後才會出現（例如聽了某個頻率）
##   learn      {名稱: 頻率}，讀到／撿到這個物件時，把頻率記進無線電備忘錄
##   messages   {名稱: 文字}，撿到錄音帶等物件時顯示
##   floor      樓層（預設 1），決定樓梯提示是上樓還是下樓
##   loot       {"x,y": [物品, 數量]}，木箱裡的東西
##   climate    氣候（預設 DEFAULT_CLIMATE），決定會不會失溫
##   theme      室內的主題（家具、地板痕跡、牆上細節）：lab、office、dorm、industrial、military、hut、cave、outdoor
##   snowcat_to 雪地車開往的區域（到達後站在對方的 entries.snowcat）
##   zones 的 label：配電箱提示上顯示的名稱（預設是區域名）
##   reels      {"x,y": {to, entry, scene, flag, prompt}}：盤式錄音機 &（走進／走出一段記憶，見 MemoryReel）
##   lit        true = 這個區域一直有燈（不管電力）
##   camera_zones  [{rect, zoom}]：主角在 rect 裡時鏡頭推近（zoom）。斜角（tilt）、固定機位（frame）使用者不喜歡，已經全部拿掉
##   sets       [{rect, set}]：這個範圍是哪種房間（餐廳 mess、醫務室 medical、機房 utility……見 SetDresser.SETS），
##              決定家具、地板、牆上的東西。沒寫的地方用 set（整區）或主題的預設
##   outdoor_set  戶外的樣子：yard（雪地廠區，預設）、dock（水泥碼頭）、deck（甲板）、wild（荒野：只有這種有岩石）
##   props      {"x,y": 圖檔}：指定某一塊家具就是這樣東西（x,y = 那一塊的左上角；大型物件不用寫大小）
##   era        時代的畫面色調："1962"（過去的記憶）、"2099"（未來的訊號）；不寫 = 現在
class_name Areas
extends RefCounted

const START_AREA := "south_shore"
## 沒有設定 climate 的區域用這個氣候（見 Climates）
const DEFAULT_CLIMATE := "arctic"
const START_ENTRY := "start"

const DATA := {
	# 南岸：直升機降落的海岸。北邊是研究站（station_1f，正門＋貨物門）、東邊是燃料庫（fuel_depot），
	# 三個合成一張無縫地圖（Areas.ROOMS）：走到門口自動門打開就進去了，不切換畫面。
	"south_shore": {
		"theme": "industrial",
		"cutscene": "opening",
		"title": "Sea Gate",
		"outdoor": false,
		"set": "dock",
		"climate": "temperate",
		"lit": true,
		"sets": [{"rect": Rect2i(1, 22, 8, 4), "set": "office"}],
		"props": {"31,21": "set/truck", "16,28": "set/boat", "11,27": "set/bollard", "24,27": "set/bollard", "34,27": "set/bollard", "43,27": "set/bollard", "11,22": "set/lamp_post", "29,23": "set/lamp_post", "47,20": "set/lamp_post", "12,26": "set/barrier", "27,26": "set/barrier", "38,26": "set/barrier", "19,17": "set/pipe_run"},
		"map": [
			"##D#################################################",
			"#...################################################",
			"#...################################################",
			"#..C################################################",
			"#...################################################",
			"#...################################################",
			"#...################################################",
			"#C..################################################",
			"#C..################################################",
			"#...################################################",
			"#.1.################################################",
			"#...################################################",
			"#..C################################################",
			"#...################################################",
			"#...################################################",
			"#...################################################",
			"#...######D##############################D##########",
			"#....CC............CCC........CC.............CC....#",
			"#..........................B...................K.A.#",
			"#......2.....CCCC.......CCCC.........CCC...........#",
			"#............CCCC.......CCCC.........CCC..4....C...#",
			"##########..........CC.........CCCCC...............#",
			"#..CC..C.=.C........CC.........CCCCC...............D",
			"D........#...................C..............CC.....#",
			"#...l....+...................3...........o..CC.....#",
			"#H.A...x.#.........................................#",
			"##########..CCC...P.t......CCCC.......CC..x......r.#",
			"#..........C............C.........C........C.......#",
			"#~~~~~~~~~~~~~~~CCC~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#",
			"#~~~~~~~~~~~~~~~CCC~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#",
			"#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#",
			"####################################################",
		],
		"gear": {"20,26": "wool_hat"},
		"enemies": [
			{"type": "patroller", "route": "1234"},
		],
		# 戶外整區都是冷的：感染者在外面行動遲緩
		"zones": {},
		"breakers": [],
		"doors": {
			"front": {"cell": Vector2i(10, 16), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"huts": {"cell": Vector2i(0, 23), "to": "weather_huts", "spawn_dir": Vector2i(1, 0)},
			"cargo": {"cell": Vector2i(41, 16), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"depot": {"cell": Vector2i(51, 22), "to": "fuel_depot", "spawn_dir": Vector2i(-1, 0)},
			# 機庫的捲門是電動的：要先恢復電力（機庫是 Boss 戰場，維持獨立區域）
			"hangar": {"cell": Vector2i(2, 0), "to": "hangar", "spawn_dir": Vector2i(0, 1), "power": true},
		},
		"names": {
			"47,18": "supply_crate_shore",
		},
		# 聽過 127.80 的作業日誌之後才會出現
		"hidden": {
			"49,18": "reveal:cache_shore",
		},
		"messages": {},
	},

	"station_1f": {
		"theme": "lab",
		"cutscene": "station_first",
		"title": "Station 1F",
		"powered_area": true,
		"outdoor": false,
		"climate": "arctic",
		"sets": [
			{"rect": Rect2i(1, 1, 4, 5), "set": "lounge"}, {"rect": Rect2i(6, 1, 8, 5), "set": "mess"},
			{"rect": Rect2i(15, 1, 7, 5), "set": "mess"}, {"rect": Rect2i(23, 1, 7, 5), "set": "medical"},
			{"rect": Rect2i(31, 1, 12, 5), "set": "lab"}, {"rect": Rect2i(1, 10, 11, 6), "set": "lounge"},
			{"rect": Rect2i(13, 10, 9, 6), "set": "comms"}, {"rect": Rect2i(23, 10, 7, 6), "set": "storage"},
			{"rect": Rect2i(31, 10, 12, 6), "set": "garage"},
		],
		"props": {"15,1": "set/counter", "20,1": "set/fridge", "21,1": "set/stove", "6,1": "set/vending", "7,1": "set/water_cooler", "1,10": "set/sofa", "6,10": "set/desk_wide", "13,10": "set/gun_cabinet", "14,10": "props/cabinet", "16,10": "set/desk_wide", "10,15": "set/plant", "11,15": "set/vending"},
		"map": [
			"#########################D##################",
			"#G..l#CC.CC.CC#CCCC.CC#.......#CCCC.N.CCCCC#",
			"#....#........#......H#.......#............#",
			"#....+..CC.CC.+..CC...+...q...+..CC..CC..T.#",
			"#H...#..CC.CC.#..CC.B.#.......#..CC..CC....#",
			"#....#1.......#M......#C..X..C#.a.....I..bV#",
			"###+######+#######+######+######+####+######",
			"#..........2.....................c.........D",
			"#.................3........................#",
			"####+##########+###########+###+####+#######",
			"#CC...CCCC..#CC.CCCC..#CCCC.CC#........A...#",
			"#...........#.........#.......#.CC..CC..CC.#",
			"#..CCC......+...CC....#.......#.CC..CC..CC.#",
			"#......4....#...CC..A.#..CC...#.......d....#",
			"#H..........#^.....B..#..CC.A.#CC.....5.LS.#",
			"#....6....CC#H.....CC.#.......#CC..B.......#",
			"#####D##############################D#######",
		],
		"enemies": [
			{"type": "patroller", "route": "123456"},
			{"type": "listener", "route": "abcd"},
		],
		"zones": {
			"lounge": {"rect": Rect2i(0, 0, 23, 17), "heated": true},
			"lab": {"rect": Rect2i(23, 0, 21, 17), "heated": true},
		},
		"breakers": ["lounge"],
		"doors": {
			"front": {"cell": Vector2i(5, 16), "to": "south_shore", "spawn_dir": Vector2i(0, -1)},
			"cargo": {"cell": Vector2i(36, 16), "to": "south_shore", "spawn_dir": Vector2i(0, -1)},
			"safe": {"cell": Vector2i(25, 0), "to": "station_safe", "spawn_dir": Vector2i(0, 1)},
			"basement": {"cell": Vector2i(43, 7), "to": "station_b1", "spawn_dir": Vector2i(-1, 0), "access": 2},
		},
		"stairs": {"1,1": "station_2f"},
		"entries": {"stairs": Vector2i(2, 2)},
		"names": {
			"26,5": "lounge_breaker",
			"1,1": "stairs_up",
			"41,3": "tape_lab",
			"36,1": "note_lab",
		},
		# 聽過 124.35 Mendez 的錄音之後才會出現
		"hidden": {
			"40,14": "reveal:shotgun_1f",
			"41,14": "reveal:shotgun_1f",
		},
		# 讀了／撿了之後，把頻率記進無線電備忘錄
		"learn": {
			"tape_lab": 12435,
			"note_lab": 12780,
		},
		"messages": {
			"tape_lab": "TAPE (Mendez): \"...the clicking started on day four. They follow the sound of our boots. If anything happens, I'll keep a loop running on 124.35.\"",
			"note_lab": "WHITEBOARD: \"OPS LOG / drop schedule -> 127.80 (automated). Don't use the ops channel for chatter! - H.\"",
		},
	},

	"station_safe": {
		"theme": "lab",
		"cutscene": "clean_room",
		"title": "Clean Room (Safe)",
		"outdoor": false,
		"safe": true,
		"camera_zones": [{"rect": Rect2i(1, 1, 11, 6), "zoom": 1.25}],
		"climate": "arctic",
		"map": [
			"#############",
			"#CC.R..CCC.Y#",
			"#...........#",
			"#C.........M#",
			"#C...CC.....#",
			"#....CC...CC#",
			"#...........#",
			"######D######",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"safe": {"cell": Vector2i(6, 7), "to": "station_1f", "spawn_dir": Vector2i(0, -1)},
		},
		"entries": {
			"radio": Vector2i(4, 2),
		},
		"names": {
			"4,1": "radio_safe",
		},
		"messages": {},
	},

	# 二樓：辦公室（station_2f_office）和東翼（station_east_wing，走廊盡頭）合成一張無縫地圖
	"station_2f": {
		"theme": "dorm",
		"title": "Station 2F",
		"floor": 2,
		"powered_area": true,
		"outdoor": false,
		"sets": [
			{"rect": Rect2i(1, 1, 4, 4), "set": "lounge"}, {"rect": Rect2i(6, 1, 15, 4), "set": "dorm"},
			{"rect": Rect2i(22, 1, 7, 4), "set": "medical"}, {"rect": Rect2i(30, 1, 9, 4), "set": "barracks"},
			{"rect": Rect2i(1, 9, 8, 5), "set": "lounge"}, {"rect": Rect2i(10, 9, 10, 5), "set": "medical"},
			{"rect": Rect2i(21, 9, 8, 5), "set": "storage"}, {"rect": Rect2i(30, 9, 9, 5), "set": "office"},
		],
		"set": "dorm",
		"props": {"22,1": "set/sink", "24,1": "set/shelf_linen", "35,1": "set/locker_gear", "37,1": "set/locker_gear", "30,4": "set/footlocker", "38,4": "set/footlocker", "30,9": "set/sofa", "36,13": "set/plant"},
		"map": [
			"########################################",
			"#G...#CC..CC.#CC..CC.#C.CCC..#ttt..C.CC#",
			"#....#.......#.......#.......#........H#",
			"#....+.a.....+....b..+..x....+.....Q...#",
			"#H..l#CC..CC.#CC..x..#CC....M#C.......C#",
			"###+####+#######+#######+#######+#######",
			"#....1...............c.............2...D",
			"#......................................#",
			"####+#########+###########+########+####",
			"#CC..CCC.#CC...CCC..#CCCC..CC#CC.......#",
			"#........#..........#........#..x......#",
			"#..CC....#...CC..d..#........#.........#",
			"#..CC..x.#...CC.....#..CC..L.#.........#",
			"#........#H.........#........#......CC.#",
			"#################################D######",
		],
		"gear": {"30,1": "sneaking_suit", "31,1": "balaclava", "32,1": "soft_soles"},
		"enemies": [
			{"type": "patroller", "route": "12"},
			{"type": "sleeper", "route": "a"},
			{"type": "sleeper", "route": "b"},
			{"type": "sleeper", "route": "c"},
			{"type": "sleeper", "route": "d"},
		],
		# 二樓的暖氣壞了：整層都是冷的，凍眠體才會一直睡著
		"zones": {
			"upper": {"rect": Rect2i(0, 0, 40, 15), "heated": false, "powered": true},
		},
		"breakers": [],
		"doors": {
			"office": {"cell": Vector2i(33, 14), "to": "station_2f_office", "spawn_dir": Vector2i(0, -1), "access": 1},
			"east_wing": {"cell": Vector2i(39, 6), "to": "station_east_wing", "spawn_dir": Vector2i(-1, 0)},
		},
		"stairs": {"1,1": "station_1f"},
		"entries": {"stairs": Vector2i(2, 2)},
		"names": {
			"35,3": "keycard_2f",
		},
		"messages": {},
	},

	"station_2f_office": {
		"theme": "office",
		"title": "Director's Office",
		"powered_area": true,
		"outdoor": false,
		"props": {"4,4": "set/desk_wide", "1,1": "set/shelf_files", "9,1": "set/sofa", "10,5": "set/plant"},
		"map": [
			"######D#######",
			"#CCC.....CCCC#",
			"#N.........O.#",
			"#............#",
			"#...CCC......#",
			"#H........CC.#",
			"#.x.......V..#",
			"##############",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"office": {"cell": Vector2i(6, 0), "to": "station_2f", "spawn_dir": Vector2i(0, 1)},
		},
		"names": {
			"11,2": "director_terminal",
			"1,2": "note_office",
		},
		"learn": {
			"note_office": 12570,
		},
		"messages": {
			"note_office": "DESK NOTE (Halvorsen): \"Ark line, 125.70, scheduled windows only. They promised a pickup for the samples. Not for us.\"",
			"director_terminal": "HALVORSEN'S RECORDS: \"Day 3: Mendez and Lund show the clicking. Kept off the report - the Ark people paid for this season. Day 6: moved the infected to cold storage. Day 9: power cut. God help us.\"",
		},
	},

	"fuel_depot": {
		"theme": "industrial",
		"title": "Fuel Depot",
		"outdoor": true,
		# 倉庫內部（地板畫成室內；沒有暖氣，一樣是冷的）
		"indoor_rects": [Rect2i(18, 4, 16, 10)],
		"climate": "arctic",
		"sets": [{"rect": Rect2i(18, 4, 16, 10), "set": "storage"}],
		"props": {"3,2": "set/tank", "10,2": "set/tank", "3,5": "set/pipe_run", "10,5": "set/pipe_run", "5,13": "set/truck", "1,12": "set/lamp_post", "15,11": "set/lamp_post", "11,9": "set/signpost"},
		"map": [
			"####################################",
			"#..................................#",
			"#..CCCCC..CCCC.H...................#",
			"#..CCCCC..CCCC...###################",
			"#................#.N..CCC..CC..C..##",
			"#..CCCC...CCC....#.tt.........?.F.##",
			"#................#................##",
			"#............2...#.t...CCCC..CCC..##",
			"#.l......o.......#.........a......##",
			"#..........C.....+...............w##",
			"D...1............#.....CCCC..CCC..##",
			"#..............C.#................##",
			"#C...............#..w.....B....b..##",
			"#....CCCC........#.A.............H##",
			"#....CCCC;.......########p##########",
			"#.....................CC.....#######",
			"#.ML......3.CC;..###################",
			"#...........CC.r.###################",
			"#................###################",
			"####################################",
		],
		"hidden": {"2,16": "reveal:cache_depot", "3,16": "reveal:cache_depot"},
		"gear": {"19,5": "arctic_suit", "20,5": "snow_goggles", "19,7": "crampons"},
		"enemies": [
			{"type": "patroller", "route": "123"},
			{"type": "listener", "route": "ab"},
		],
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 36, 20), "heated": false},
		},
		"breakers": [],
		"doors": {
			"depot": {"cell": Vector2i(0, 10), "to": "south_shore", "spawn_dir": Vector2i(1, 0)},
		},
		"names": {
			"32,5": "fuel_can",
			"19,4": "manifest_depot",
		},
		"loot": {
			"20,12": ["ethanol", 1],
			"33,9": ["bottle", 2],
		},
		"messages": {
			"manifest_depot": "MANIFEST: \"Drum 7 - diesel, generator grade. Moved to the back of the warehouse after the storm. The thing in here hunts by sound. Walk soft.\"",
		},
	},

	"station_b1": {
		"theme": "industrial",
		"title": "Station B1",
		"outdoor": false,
		"floor": -1,
		"powered_area": true,
		"camera_zones": [{"rect": Rect2i(1, 4, 14, 8), "zoom": 1.15}],
		"sets": [{"rect": Rect2i(1, 4, 14, 8), "set": "lab"}, {"rect": Rect2i(16, 4, 7, 5), "set": "comms"}, {"rect": Rect2i(24, 4, 11, 8), "set": "utility"}, {"rect": Rect2i(1, 1, 34, 2), "set": "utility"}],
		"props": {"16,4": "set/tape_drive", "17,4": "set/tape_drive", "18,4": "set/server", "19,4": "set/radio_rack", "21,4": "set/shelf_files", "22,4": "set/shelf_files", "16,8": "set/oscilloscope", "17,8": "set/console"},
		"map": [
			"##D#################################",
			"#...l............1................2#",
			"#..................................#",
			"####+#########+#####+####+##########",
			"#CC..CC..CC....#CCCC.CC#C..CCCC..CC#",
			"#..............#.......#.........;H#",
			"#..a.....x.....#.&..M..#..CC.......#",
			"#CC..........V.#....s..#..CCE......#",
			"#CC....b.......#CC.....#........3..#",
			"#........x.....###+#####.CCCC....M.#",
			"#..CC......CCc.#.......#.CCCC......#",
			"#H.CC......CC..#..L....+...........#",
			"################.......#############",
			"################.......#############",
			"###################D################",
		],
		"safes": {"20,7": {"reveal": "reveal:cache_caves", "text": "SAFE (maintenance office): a hunter's ledger. \"Left spare .308 and two flares in the ice caves, east end, below the glowing wall. In case.\""}},
		"enemies": [
			{"type": "patroller", "route": "123"},
			{"type": "sleeper", "route": "a"},
			{"type": "sleeper", "route": "b"},
			{"type": "sleeper", "route": "c"},
		],
		# 樣本冷凍庫一直是冷的（電力恢復後冷凍櫃更冷）；其他地方恢復電力後有暖氣
		"zones": {
			"freezer": {"rect": Rect2i(1, 4, 14, 8), "heated": false},
			"b1": {"rect": Rect2i(0, 0, 36, 15), "heated": false, "powered": true},
		},
		"breakers": [],
		"doors": {
			"basement": {"cell": Vector2i(2, 0), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"shaft": {"cell": Vector2i(19, 14), "to": "drill_shaft", "spawn_dir": Vector2i(0, -1), "access": 3},
		},
		"names": {
			"28,7": "generator_b1",
			"17,6": "reel_b1",
		},
		"entries": {"reel": Vector2i(17, 7)},
		# 盤式錄音機：1962 年燈籠站最後一捲帶子。播放 = 走進那一夜（lantern_1962）
		"reels": {"17,6": {"to": "lantern_1962", "entry": "start", "scene": "reel_b1", "prompt": "Play the 1962 reel"}},
		# 1962 年的佐藤留下的東西（看完記憶才知道在哪）
		"hidden": {"20,6": "memory:lantern"},
		"messages": {},
	},

	"hangar": {
		"theme": "industrial",
		"cutscene": "hangar",
		"title": "Hangar",
		"outdoor": false,
		"powered_area": true,
		"camera": "fixed",
		"boss": "TUNDRA MOTHER",
		"set": "garage",
		"props": {"8,5": "set/crates", "20,5": "set/container0", "8,9": "set/container1", "20,9": "set/crates"},
		"map": [
			"##############################",
			"#.............X..............#",
			"#..CC...................CC.M.#",
			"#..CC...................CC...#",
			"#............................#",
			"#.......CC..........CC.......#",
			"#.......CC..........CC.......#",
			"#..............1.............#",
			"#............................#",
			"#.......CC..........CC.......#",
			"#.......CC..........CC.......#",
			"#............................#",
			"#.H..A........Z.........L..H.#",
			"#............................#",
			"#............................#",
			"##############D###############",
		],
		"enemies": [
			{"type": "bear", "route": "1"},
		],
		# 機庫的暖氣靠電力；配電箱可以關掉，讓 Boss 變慢
		"zones": {
			"hangar": {"rect": Rect2i(0, 0, 30, 16), "heated": false, "powered": true},
		},
		"breakers": ["hangar"],
		"doors": {
			"hangar": {"cell": Vector2i(14, 15), "to": "south_shore", "spawn_dir": Vector2i(0, -1)},
		},
		"names": {
			"14,12": "snowcat",
			"14,1": "hangar_breaker",
		},
		"snowcat_to": "tower_yard",
		"entries": {"snowcat": Vector2i(14, 11)},
		"messages": {},
	},

	# ── 天線塔（主線 5：發出訊號）──────────────────────────
	# 從機庫開雪地車過來。塔底的庭院在戶外（冷，值班者行動遲緩）；
	# 塔底的樓梯通往頂層的通訊甲板。
	"tower_yard": {
		"theme": "industrial",
		"cutscene": "tower",
		"title": "Antenna Tower - Yard",
		"outdoor": true,
		"floor": 0,
		"sets": [{"rect": Rect2i(13, 2, 8, 4), "set": "utility"}, {"rect": Rect2i(25, 9, 7, 4), "set": "comms"}],
		"props": {"17,15": "set/tank", "6,12": "set/lamp_post", "15,11": "set/antenna_mast", "21,9": "set/lamp_post", "2,8": "set/signpost"},
		"map": [
			"##################################",
			"##################################",
			"#############.G..CC.H#############",
			"#############........#############",
			"#############.x....B.#############",
			"#############........#############",
			"################+#################",
			"#................................#",
			"#.C.................b...##########",
			"#.......CCCC.........C..#.N.C.M.##",
			"#...1...CCCC............+.......##",
			"#..............C........#.....A.##",
			"#.....C.................#.CC...H##",
			"#..............a........##########",
			"#................................#",
			"#................CCC.........2...#",
			"#...Z......CC....CCC;....CC......#",
			"#.....................3..CC...A..#",
			"#.....4..........................#",
			"##################################",
		],
		"enemies": [
			{"type": "patroller", "route": "1234"},
			{"type": "runner", "route": "ab"},
		],
		"zones": {
			"yard": {"rect": Rect2i(0, 0, 34, 20), "heated": false},
		},
		"indoor_rects": [Rect2i(13, 2, 8, 4), Rect2i(25, 9, 7, 4)],
		"breakers": [],
		"doors": {},
		"stairs": {"14,2": "tower_top"},
		"entries": {"stairs": Vector2i(15, 3), "snowcat": Vector2i(6, 16)},
		"snowcat_to": "hangar",
		"names": {
			"4,16": "snowcat_tower",
			"26,9": "note_relay",
		},
		"messages": {
			"note_relay": "Relay shed log: \"Dish iced over again. The de-icer breaker is out on the dish platform - and don't run it with the comms deck unguarded, Halvorsen says the noise carries.\"",
		},
	},

	# 頂層：通訊室（上行終端機）、天線碟的平台（除冰器配電箱＋凍眠體）。
	# 天線碟結冰時發不出訊號；開除冰器 = 平台變暖 = 平台上的凍眠體醒來。
	"tower_top": {
		"theme": "industrial",
		"step": "metal",
		"title": "Antenna Tower - Comms Deck",
		"outdoor": false,
		"floor": 3,
		"set": "utility",
		"sets": [{"rect": Rect2i(1, 1, 11, 6), "set": "comms"}],
		"props": {"20,4": "set/dish"},
		"map": [
			"##################################",
			"#..U....N...##...................#",
			"#...........##.x.............5.X.#",
			"#.H.........##...................#",
			"#...........##......CCCCCC.......#",
			"#...........##..6...CCCCCC....x..#",
			"#.....A.....##......CCCCCC.......#",
			"######.#######......CCCCCC.......#",
			"#..........................7.....#",
			"######.#######...........x.......#",
			"#...........##.........x.........#",
			"#.G.........##.....8.............#",
			"#.....B...H.##...................#",
			"#...........##........x..........#",
			"##################################",
		],
		"enemies": [
			{"type": "listener", "route": "78"},
			{"type": "sleeper", "route": "5"},
			{"type": "sleeper", "route": "6"},
		],
		# 天線碟的平台：除冰器（配電箱）打開前是冷的
		"zones": {
			"dish": {"rect": Rect2i(14, 1, 19, 13), "heated": false, "label": "dish de-icer"},
			"stairwell": {"rect": Rect2i(1, 8, 12, 6), "heated": false},
		},
		"breakers": ["dish"],
		"doors": {},
		"stairs": {"2,11": "tower_yard"},
		"entries": {"stairs": Vector2i(3, 11)},
		"names": {
			"3,1": "uplink",
			"8,1": "note_comms",
			"31,2": "dish_breaker",
		},
		"learn": {"note_comms": 12605},
		"messages": {
			"note_comms": "Uplink log, last entry: \"Outbound blocked by order of the director. Inbound only. Something keeps answering on 126.05 - not our people.\"",
		},
	},

	# ── 鑽探井（主線最後：最終 Boss）──────────────────────
	# B1 南側的門（權限卡等級 3）進入。沿著井壁的維修走道一層層往下（GDD 10.4 的垂直剖面）。
	# 整口井都是冷的：凍眠體睡著、感染者行動遲緩。
	"drill_shaft": {
		"theme": "industrial",
		"cutscene": "shaft",
		"step": "metal",
		"ambience": "amb_shaft",
		"title": "Drill Shaft",
		"outdoor": false,
		"floor": -2,
		"set": "utility",
		"map": [
			"##########D###############",
			"#...........l............#",
			"#..1..............H....2.#",
			"#........................#",
			"###################....###",
			"#........................#",
			"#.a....x..........B......#",
			"#........................#",
			"###....###################",
			"#........................#",
			"#...CC.......b.......A...#",
			"#...CC...........x.......#",
			"##################.....###",
			"#........................#",
			"#.c.......M...........H..#",
			"#........................#",
			"###.....##################",
			"#........................#",
			"#......x.......3......L..#",
			"#.....................G..#",
			"##########################",
		],
		"enemies": [
			{"type": "listener", "route": "12"},
			{"type": "sleeper", "route": "a"},
			{"type": "sleeper", "route": "b"},
			{"type": "sleeper", "route": "c"},
			{"type": "patroller", "route": "3"},
		],
		"zones": {
			"shaft": {"rect": Rect2i(0, 0, 26, 21), "heated": false},
		},
		"breakers": [],
		"doors": {
			"shaft": {"cell": Vector2i(10, 0), "to": "station_b1", "spawn_dir": Vector2i(0, 1)},
		},
		"stairs": {"22,19": "shaft_bottom"},
		"entries": {"stairs": Vector2i(21, 19)},
		"names": {},
		"messages": {},
	},

	# 井底：最終 Boss「深井」。固定鏡頭（一個畫面）。四根柱子可以擋共鳴脈衝。
	# 井底的鑽頭加熱器（配電箱）關掉之後，深井蓄力變慢；打倒後搭升降機離開 = 結局。
	"shaft_bottom": {
		"theme": "industrial",
		"step": "metal",
		"ambience": "amb_shaft",
		"cutscene": "deep_well",
		"title": "Shaft Bottom",
		"outdoor": false,
		"floor": -3,
		"camera": "fixed",
		"boss": "THE DEEP WELL",
		"set": "utility",
		"map": [
			"##############################",
			"#.G.......................J..#",
			"#............................#",
			"#....CC..............CC......#",
			"#....CC..............CC......#",
			"#............................#",
			"#.........x.........x........#",
			"#..............1.............#",
			"#............................#",
			"#.........x.........x........#",
			"#............................#",
			"#....CC..............CC......#",
			"#....CC..............CC......#",
			"#.H..A.......X.......L....H..#",
			"#..........M.................#",
			"##############################",
		],
		"enemies": [
			{"type": "well", "route": "1"},
		],
		"zones": {
			"pit": {"rect": Rect2i(0, 0, 30, 16), "heated": true, "label": "drill heaters"},
		},
		"breakers": ["pit"],
		"doors": {},
		"stairs": {"2,1": "drill_shaft"},
		"entries": {"stairs": Vector2i(3, 1)},
		"names": {
			"26,1": "shaft_lift",
			"13,13": "pit_breaker",
		},
		"messages": {},
	},

	# ── 氣象小屋群（南岸西邊的雪原，支線集中地）──────────────
	# 大片戶外：暴風雪中失溫很快，小屋裡擋風（沒暖氣，失溫比較慢），油桶的火可以取暖。
	# 北邊稜線上的信標油桶（支線）、氣象辦公室（酒精、滅火器、被木板封住的後門）、
	# Pieter 的小屋、通往暖和的「床鋪小屋」（第二間安全屋）的門。
	"weather_huts": {
		"theme": "hut",
		"title": "Weather Huts",
		"outdoor": true,
		"floor": 0,
		"sets": [{"rect": Rect2i(1, 1, 9, 5), "set": "wild"}],
		"props": {"17,12": "set/antenna_mast", "26,17": "set/lamp_post", "14,21": "set/barrier", "34,23": "set/crates_long", "44,10": "set/wood_pile", "2,14": "set/sled", "30,2": "set/snow_mound", "42,25": "set/lamp_post", "10,5": "set/signpost", "45,16": "set/snow_mound", "22,14": "set/pipe_run", "24,25": "set/barrier"},
		"map": [
			"############D###################################",
			"#.....CC.......................................#",
			"#.CC..........................C................#",
			"#.C...............############.................#",
			"#....o............############........CCCC.....#",
			"#.......C.C.......############........CCCC.....#",
			"#.................############...u.............#",
			"#.......1.........############.................#",
			"#.................############.................#",
			"#.................######D#####.................#",
			"#...#############..............CC...5.......C;.#",
			"#...#.N.CCC.CC..#..........x...CC..............#",
			"#...#.........I.#C....4..................x.....#",
			"#...p...a.......=............7.................#",
			"#.C.#........b..#.....CC..........#########....#",
			"#...#...B.....w.#.................#.N.CC.u#....#",
			"#...#q.......;.H#.................#.....*.#..C.#",
			"#...######+######.........C.......#..x....#....#",
			"#.................................#.|.....#..8.#",
			"#.....................o...........#H.....M#....#",
			"#..r............d.................####+####....#",
			"#.............CCC..............c............u..#",
			"#...2...............r......ww..................D",
			"#...........x.....................CC;.......l..#",
			"#.....ALu...........3...................6......#",
			"#.......................CC....r...........C....#",
			"#..............................................#",
			"################################################",
		],
		"enemies": [
			{"type": "patroller", "route": "1234"},
			{"type": "runner", "route": "56"},
			{"type": "patroller", "route": "78"},
			{"type": "listener", "route": "ab"},
			{"type": "sleeper", "route": "c"},
			{"type": "sleeper", "route": "d"},
		],
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 48, 28), "heated": false},
		},
		"indoor_rects": [Rect2i(5, 11, 11, 6), Rect2i(35, 15, 7, 5)],
		"breakers": [],
		"doors": {
			"huts": {"cell": Vector2i(47, 22), "to": "south_shore", "spawn_dir": Vector2i(-1, 0)},
			"bunk": {"cell": Vector2i(24, 9), "to": "huts_safe", "spawn_dir": Vector2i(0, 1)},
			"harbor": {"cell": Vector2i(12, 0), "to": "north_harbor", "spawn_dir": Vector2i(0, 1)},
		},
		"names": {
			"5,4": "beacon_drum",
			"6,11": "met_log",
			"36,15": "pieter_note",
		},
		# 點燃稜線上的信標之後，補給無人機投下的東西
		"hidden": {
			"6,24": "reveal:huts_cache",
			"7,24": "reveal:huts_cache",
			"8,24": "reveal:huts_cache",
		},
		"loot": {
			"14,15": ["heat_pack", 1],
			"27,22": ["stone", 3],
			"28,22": ["ethanol", 1],
		},
		"messages": {
			"met_log": "MET LOG, day 12: \"Wind ninety knots. Anyone caught between huts won't make it. The ridge beacon still has kerosene - the supply drone homes on it.\"",
			"pieter_note": "PIETER (scrawled): \"Kept the bunk hut warm for whoever makes it. Radio's on the shelf. Light the beacon on the ridge - the drone drops by the south fence. Too cold to walk back. Sorry.\"",
		},
	},

	# 床鋪小屋：第二間安全屋（暖氣、無線電、儲物箱）。
	"huts_safe": {
		"theme": "hut",
		"title": "Bunk Hut (Safe)",
		"outdoor": false,
		"safe": true,
		"map": [
			"############",
			"#CC.R...Y.H#",
			"#..........#",
			"#C......u..#",
			"#C...CC....#",
			"#..........#",
			"######D#####",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"bunk": {"cell": Vector2i(6, 6), "to": "weather_huts", "spawn_dir": Vector2i(0, -1)},
		},
		"entries": {"radio": Vector2i(4, 2)},
		"names": {"4,1": "radio_huts"},
		"messages": {},
	},

	# ── 擴張區域 ──
	# 北港：守門派登陸的碼頭。武裝人員巡邏、倉庫（無縫室內）、獵犬。被無線電通報 = 增援從兩個入口進來。
	"north_harbor": {
		"theme": "military",
		"title": "North Harbor",
		"outdoor": true,
		"floor": 0,
		"cutscene": "harbor",
		"sets": [{"rect": Rect2i(37, 9, 3, 6), "set": "barracks"}, {"rect": Rect2i(27, 9, 9, 6), "set": "comms"}],
		"props": {"13,16": "set/truck", "15,5": "set/barrier", "23,5": "set/barrier", "2,10": "set/lamp_post", "21,14": "set/lamp_post", "42,12": "set/lamp_post", "5,4": "set/bollard", "12,4": "set/bollard", "28,4": "set/bollard", "36,4": "set/bollard", "29,9": "set/desk_wide", "30,12": "set/map_table", "27,14": "set/radio_rack", "35,9": "set/gun_cabinet"},
		"map": [
			"####################D#######################",
			"#~~~~~~~~~~~~~~~~~~...~~~~~~~~~~~~~~~~~~~~~#",
			"#~~~~~~~~~~~~~~~~~~...~~~~~~~~~~~~~~~~~~~~~#",
			"#~~~~~~~~~~~~~~~~~~...~~~~~~~~~~~~~~~~~~~~~#",
			"#....C......C...............C.......C......#",
			"#..1...........CCC.....CCC..............2..#",
			"#...........y..............................#",
			"#...CCCC...........3.......................#",
			"#...CCCC..................####=###=######..#",
			"#.........................#..CCC...C#t.t#..#",
			"#.C.......CCCC........CC..#.v....N..#...#..#",
			"#.........CCCC........CC..=....a....+t..#..#",
			"#.............r...........#...CC....#.|.#.C#",
			"#...CC.............4......#.s.....b.#.H.#..#",
			"#...CC;..............C....#C........#..M#..#",
			"#.........................#####++########..#",
			"#............CCCCC.........................#",
			"#....5.......CCCCC..x..........6...........#",
			"#.............................k.....CCC....D",
			"#.......w...........................CCC....#",
			"#.................o.....CCCC;..............#",
			"#........u......7.......CCCC............8..#",
			"#..........l...............................#",
			"########D###################################",
		],
		"safes": {"28,13": {"reveal": "reveal:cache_depot", "text": "SAFE (harbor office): Gatekeeper supply note. \"Medical cache stashed at the fuel depot, northwest corner of the yard, under the tarp.\""}},
		# 港口的暴風雪：沒穿保暖裝備體溫掉很快
		"climate": "blizzard",
		"gear": {"37,9": "eod_armor", "39,9": "eod_helmet", "37,11": "eod_boots"},
		"enemies": [
			{"type": "guard", "route": "12"},
			{"type": "guard", "route": "34"},
			{"type": "guard", "route": "ab"},
			{"type": "guard", "route": "78"},
			{"type": "hound", "route": "56"},
		],
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 44, 24), "heated": false},
		},
		"indoor_rects": [Rect2i(27, 9, 13, 6)],
		"breakers": [],
		"reinforcements": {"type": "guard", "count": 2, "doors": ["harbor"]},
		"doors": {
			"harbor": {"cell": Vector2i(8, 23), "to": "weather_huts", "spawn_dir": Vector2i(0, -1)},
			"caves": {"cell": Vector2i(43, 18), "to": "ice_caves", "spawn_dir": Vector2i(-1, 0)},
			"gangway": {"cell": Vector2i(20, 0), "to": "cruise_deck", "spawn_dir": Vector2i(0, 1)},
		},
		"names": {"33,10": "gate_orders"},
		"loot": {"8,19": ["shells", 2]},
		"messages": {
			"gate_orders": "GATE ORDERS (printed, stamped): \"Island is under Accord quarantine. Survivors are to be detained, not evacuated. Specimens take priority over personnel. No aircraft leaves Greycrow without Gate One's word.\"",
		},
	},

	# 冰洞：港口後面的冰河洞窟。很暗、很冷，爬行者和膨脹者，盡頭有獵人留下的獵槍。
	"ice_caves": {
		"theme": "cave",
		"title": "Ice Caves",
		"outdoor": false,
		"floor": 0,
		"cutscene": "caves",
		"step": "snow",
		"map": [
			"############################################",
			"#####.........######.............###########",
			"####...........####......C........#####...##",
			"###.....1.......##.......C..........##..j..#",
			"###..............#..........2.......##.....#",
			"##.......####...............###.....#....N.#",
			"#.......######..............####....#..|...#",
			"#......########......x......####.........u.#",
			"#.......######.............................D",
			"##.......####........CC.........b...########",
			"##...................CC.......####...#######",
			"D..l..u........###............#####...######",
			"##.............####..3....c.......#....#####",
			"###..;..a......####...............#.....####",
			"####...........###...........##...........##",
			"#####.....##..............x..###....d.....##",
			"######...####.....4.........####.......yk###",
			"#######..####.........;.##.........M....####",
			"########.......####.....##.......##....#####",
			"#########.....######...........####...######",
			"############################################",
		],
		"hidden": {"40,16": "reveal:cache_caves", "39,16": "reveal:cache_caves"},
		"climate": "blizzard",
		"hazards": [{"rect": Rect2i(26, 7, 12, 7), "kind": "spores"}],
		"enemies": [
			{"type": "crawler", "route": "12"},
			{"type": "spitter", "route": "34"},
			{"type": "husk", "route": "ab"},
			{"type": "sleeper", "route": "d"},
		],
		"zones": {
			"cave": {"rect": Rect2i(0, 0, 44, 21), "heated": false},
		},
		"breakers": [],
		"doors": {
			"caves": {"cell": Vector2i(0, 11), "to": "north_harbor", "spawn_dir": Vector2i(1, 0)},
			"gate_tunnel": {"cell": Vector2i(43, 8), "to": "gate_one_yard", "spawn_dir": Vector2i(-1, 0)},
		},
		"names": {"41,5": "hunter_note"},
		"messages": {
			"hunter_note": "NOTE, pinned under the rifle: \"Came down here after the dogs. They weren't dogs anymore. Took the rifle off the rack for bears. Doesn't matter what you shoot - it hears the shot from everywhere. - Ivo\"",
		},
	},

	# 北緯站 東翼：生物實驗區。一條走廊，北邊是辦公室、實驗室 A、樣本室（詠者）、低溫保存室、病房，
	# 南邊是除汙更衣室（防護裝備）、實驗室 B、解剖室、樣本倉庫、維修機房（自動門、觀察窗）。地圖規格在 tools/map_specs/batch4.py。
	"station_east_wing": {
		"theme": "lab",
		"title": "East Wing",
		"floor": 2,
		"powered_area": true,
		"outdoor": false,
		"cutscene": "east_wing",
		"sets": [
			{"rect": Rect2i(1, 1, 7, 6), "set": "office"},
			{"rect": Rect2i(35, 1, 8, 6), "set": "medical"},
			{"rect": Rect2i(1, 11, 7, 6), "set": "dorm"},
			{"rect": Rect2i(18, 11, 8, 6), "set": "medical"},
			{"rect": Rect2i(27, 11, 7, 6), "set": "storage"},
			{"rect": Rect2i(35, 11, 8, 6), "set": "utility"},
		],
		"props": {"1,11": "set/locker_gear", "3,11": "set/locker_gear", "5,11": "set/shelf_linen", "7,11": "set/sink", "36,14": "set/genset"},
		"map": [
			"############################################",
			"#C.C.CC.#CCC..C.C#C.C..C.C#.......#CC.CC.CC#",
			"#.......#........#........#.CC.CC.#........#",
			"#.N.....#........#...CC...#.CC.CC.#.......M#",
			"#..CC:..#..CCC...#.a.CC...#.......#.CC..C..#",
			"#.......#......n.#......V.#C..b...#....x...#",
			"#H......#.x......#........#......H#........#",
			"####+#####=#++#=###==++==#####+#####=#++#=##",
			"D.......C.1...............C................#",
			"#.....................x...........C.....2..#",
			"####+#####=#++#=###=#++#=#####+########+####",
			"#C.C.C.C#CC....CC#CC....CC#CC...CC#CCC....C#",
			"#.......#........#........#CC...CC#.......H#",
			"#.ttt.l.#.d......#...x....#...c...#...N.z..#",
			"#.......#..CCC...#.CC..CC.#.......#.CC.....#",
			"#H......#.......A#........#..CCC..#.CC...m.#",
			"#.......#........#........#..CCC..#........#",
			"############################################",
		],
		# 孢子外洩的實驗室：沒穿防護裝備會一直感染
		"hazards": [{"rect": Rect2i(18, 1, 8, 6), "kind": "spores"}, {"rect": Rect2i(9, 11, 8, 6), "kind": "spores"}, {"rect": Rect2i(27, 11, 7, 6), "kind": "spores"}],
		"gear": {"2,13": "hazmat_suit", "3,13": "gas_mask", "4,13": "hazmat_boots"},
		"enemies": [
			{"type": "brute", "route": "12"},
			{"type": "chorister", "route": "a"},
			{"type": "crawler", "route": "b"},
			{"type": "husk", "route": "c"},
			{"type": "sleeper", "route": "d"},
		],
		"zones": {
			"wing": {"rect": Rect2i(0, 0, 44, 18), "heated": false, "powered": true},
		},
		"breakers": [],
		"doors": {
			"east_wing": {"cell": Vector2i(0, 8), "to": "station_2f", "spawn_dir": Vector2i(1, 0)},
		},
		"names": {"2,3": "wing_log", "38,13": "kovac_memo"},
		"messages": {
			"wing_log": "LAB LOG, East Wing: \"Sealed the wing on the director's order. Twelve still inside. He says the cold will keep them asleep. He says a lot of things.\"",
			"kovac_memo": "MEMO - A. KOVAC (dated before she left): \"It isn't a disease. It's a hibernation strategy that uses us as the burrow. Whoever is paying for this already knows that.\"",
		},
	},

	# 守門一號：守門派在島北端的前進基地（地圖規格在 tools/map_specs/batch4.py）。
	# 廣場是有圍牆的檢查哨：隧道出來先到圍籬外的管制區，穿過大門（門房）才進到裡面的基地正門、車棚、貨櫃區、車輛調度場。
	# 基地：兩條走廊。北排是寢室、更衣室、指揮室、通訊室、指揮官辦公室、軍械庫；中排是餐廳、廚房、醫務室、簡報室、
	# 拘留區（牢房、觀察窗）、發電機房；南排是樣本實驗室、冷藏室（孢子外洩）、大廳、工具間、車庫，還有安全屋（房間 gate_one_safe）。
	# 地圖上方 32 列空白＝基地（房間 gate_one_base）貼進來的位置：廣場和基地是同一張無縫地圖。
	"gate_one_yard": {
		"theme": "military",
		"title": "Gate One - Yard",
		"outdoor": true,
		"floor": 0,
		"cutscene": "gate_one",
		"sets": [
			{"rect": Rect2i(18, 39, 6, 3), "set": "comms"},
			{"rect": Rect2i(37, 40, 3, 2), "set": "comms"},
		],
		"props": {"7,35": "set/truck", "8,42": "set/barrier", "11,46": "set/barrier", "15,33": "set/wood_pile", "16,41": "set/lamp_post", "16,46": "set/lamp_post", "27,36": "set/barrier", "33,36": "set/barrier", "28,33": "set/lamp_post", "34,33": "set/lamp_post", "19,33": "set/tank", "42,33": "set/truck", "48,33": "set/truck", "55,33": "set/crates", "24,46": "set/lamp_post", "35,46": "set/lamp_post", "46,41": "set/truck", "53,41": "set/tank", "50,47": "set/crates", "50,52": "set/truck", "57,53": "set/snow_mound", "19,39": "set/desk_wide", "22,39": "set/radio_rack", "39,40": "set/console"},
		"map": [
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"##############################################################",
			"###############################D##############################",
			"#####.........;C.#.CCCCC....C.....C......#CCCC.#CCCCC#.CCC.###",
			"#####.w..........=.CCCCC.................#CCCC.#CCCCC#.CCC.###",
			"#####..CCCC......=.......................#.....#.....#.....###",
			"#####..CCCC......=.......1.CCC...CCC.....#.....#.....#..oo.###",
			"#####.......CCC..#.......................#.....#.....#...o.###",
			"#####.......CCC..###=####..................................###",
			"#####.....5......#NCC.Cl#...........##=##....2............y###",
			"#####............=......=...........#..C#..................###",
			"#####...........C#x....A#.....a.....+...#.....CCCCC..CCCC..###",
			"#####...CCC......####+###...........##=##.....CCCCC..CCCC..###",
			"#####.............................4........................###",
			"####D...............3......................................###",
			"#####............#.............................b...........###",
			"#####.CC...CCC..C=======C====..====C======#................###",
			"#####.CC.........=.CCCC.CCCC....CCCCCC.CC.=.......CCC.w....###",
			"#####........CC..=.CCCC.CCCC....CCCCCC.CC.=.......CCC;.....###",
			"#####.....6..CC..#..7..................CC.=................###",
			"#####.r......CC..=.........................................###",
			"#####........CC..=.CCCCCC.CCC..CCCC.CCCC...................###",
			"#####...oo.......=.CCCCCC.CCC..CCCC.CCCC..=..CC...CCCC.....###",
			"#####....o.......=........................=..CC...CCCC...C.###",
			"#####............#...................8...u#..CC.........k.M###",
			"##############################################################",
		],
		"climate": "blizzard",
		"hidden": {"56,54": "reveal:cache_gate", "58,54": "reveal:cache_gate"},
		"enemies": [
			{"type": "guard", "route": "12"},
			{"type": "guard", "route": "34"},
			{"type": "guard", "route": "56"},
			{"type": "guard", "route": "78"},
			{"type": "hound", "route": "ab"},
		],
		"zones": {
			"outside": {"rect": Rect2i(4, 32, 56, 24), "heated": false},
		},
		"indoor_rects": [Rect2i(18, 39, 6, 3), Rect2i(37, 40, 3, 2)],
		"breakers": [],
		"reinforcements": {"type": "guard", "count": 2, "doors": ["gate_tunnel"]},
		"doors": {
			"gate_tunnel": {"cell": Vector2i(4, 44), "to": "ice_caves", "spawn_dir": Vector2i(1, 0)},
			"base_gate": {"cell": Vector2i(31, 32), "to": "gate_one_base", "spawn_dir": Vector2i(0, 1)},
		},
		"names": {"18,39": "gate_duty_log"},
		"loot": {"6,34": ["ammo", 4], "54,47": ["shells", 2]},
		"messages": {
			"gate_duty_log": "GATEHOUSE DUTY LOG: \"Day 6. Two more from the station walked up to the wire. Unarmed. Orders were clear. Day 7. Nobody wants the gate shift anymore.\"",
		},
	},

	"gate_one_base": {
		"theme": "military",
		"title": "Gate One",
		"floor": 1,
		"outdoor": false,
		"powered_area": true,
		"cutscene": "gate_base",
		"sets": [
			{"rect": Rect2i(1, 1, 8, 6), "set": "barracks"},
			{"rect": Rect2i(10, 1, 8, 6), "set": "barracks"},
			{"rect": Rect2i(19, 1, 8, 6), "set": "barracks"},
			{"rect": Rect2i(28, 1, 8, 6), "set": "comms"},
			{"rect": Rect2i(37, 1, 8, 6), "set": "comms"},
			{"rect": Rect2i(46, 1, 7, 6), "set": "office"},
			{"rect": Rect2i(1, 11, 9, 6), "set": "mess"},
			{"rect": Rect2i(11, 11, 6, 6), "set": "mess"},
			{"rect": Rect2i(18, 11, 5, 6), "set": "medical"},
			{"rect": Rect2i(24, 11, 5, 6), "set": "office"},
			{"rect": Rect2i(33, 11, 17, 6), "set": "barracks"},
			{"rect": Rect2i(51, 11, 10, 6), "set": "utility"},
			{"rect": Rect2i(14, 21, 8, 5), "set": "lab"},
			{"rect": Rect2i(23, 21, 6, 5), "set": "lab"},
			{"rect": Rect2i(14, 27, 7, 5), "set": "lab"},
			{"rect": Rect2i(33, 21, 8, 5), "set": "storage"},
			{"rect": Rect2i(42, 21, 19, 11), "set": "garage"},
		],
		"props": {"56,4": "set/workbench", "26,29": "set/desk_wide", "35,30": "set/sofa", "44,23": "set/truck", "52,23": "set/truck", "52,13": "set/genset", "57,13": "set/boiler", "34,11": "set/console", "48,3": "set/desk_wide"},
		"map": [
			"##############################################################",
			"#CC.CC.CC#CC.CC.CC#C.H.C.H.#C.CN.C.C#C.C.C.C.#C......#C.C.C.C#",
			"#........#........#........#........#........#......s#.....w.#",
			"#........#........#.......A#........#......N.#.!CCC..#.$....y#",
			"#CC...CC.#CC...CC.#.C...C..#..CCC...#..CC....#...N...#..CC...#",
			"#........#........#........#.3.....l#........#....4..#k...L.A#",
			"#......M.#.B.....H#........#........#........#.....:C#.......#",
			"####+########+########+#######=++=######+#=######+#######+####",
			"#...........C..............C.................C............2..#",
			"#..1.........................................................#",
			"#####+##############+#####=###..################+######+######",
			"#C.......C#CC.C.C#CC.CC#C...C#..#.C.....d.........#C.C....C.C#",
			"#.........#......#.....#.....#..+.................#..........#",
			"#.CCC.CCC.+......#....M#.CCC.+..#=+=##=+=#=+=#=+=##.CC...CC..#",
			"#.........#..CC..#CC...#.CCC.#..#....#...#...#..x.#.CC...CC..#",
			"#.CCC.CCC.#......#.....#.....#..#x...#..N#e..#...V#..........#",
			"#........B#......#.....#.....#..#..CC#CC.#.CC#CC..#.........q#",
			"#####+########+###############..#######################+######",
			"#........C................C.............C.................C..#",
			"#............................................8...............#",
			"######D########=#+#=##########..####+#############+###########",
			"##############C.C..C.C#......#..#CC...CC.#CC............C.C.C#",
			"##############........#.CC.CC#..#........#...................#",
			"##############..CCC...+.CC.CC#..#.CC.....#..CCCCC...CCCC.....#",
			"##############.N....a.#......#..#.CC...m.#..CCCCC...CCCC.....#",
			"##############........#..b..V#..#........#...................#",
			"#################+############..##########.5......6.......ww.#",
			"##############C.....C#C.C.............C.C#...................#",
			"##############.......#...7...............#..CCCC...CCCCCC....#",
			"##############CC.....#....CCC............+..CCCC...CCCCCC....#",
			"##############CC...c.#.............CC....+..................o#",
			"##############.......#.M.................#r................o.#",
			"###############################D##############################",
		],
		# 樣本實驗室的孢子外洩
		"hazards": [{"rect": Rect2i(14, 21, 8, 5), "kind": "spores"}, {"rect": Rect2i(23, 21, 6, 5), "kind": "spores"}, {"rect": Rect2i(14, 27, 7, 5), "kind": "spores"}],
		"enemies": [
			{"type": "guard", "route": "12"},
			{"type": "guard", "route": "34"},
			{"type": "guard", "route": "56"},
			{"type": "guard", "route": "78"},
			{"type": "chorister", "route": "a"},
			{"type": "crawler", "route": "bc"},
			{"type": "brute", "route": "d"},
			{"type": "spitter", "route": "e"},
		],
		"zones": {
			"base": {"rect": Rect2i(0, 0, 62, 33), "heated": true},
		},
		"breakers": [],
		"doors": {
			"base_gate": {"cell": Vector2i(31, 32), "to": "gate_one_yard", "spawn_dir": Vector2i(0, -1)},
			"g1safe": {"cell": Vector2i(6, 20), "to": "gate_one_safe", "spawn_dir": Vector2i(0, -1)},
		},
		"safes": {"52,2": {"reveal": "reveal:cache_gate", "text": "SAFE (commander's office): a quartermaster's chit. \"Two crates held back from the manifest - medical and .308 - buried in the yard by the motor pool, southeast corner. Don't tell Gate Two.\""}},
		"loot": {"59,2": ["shells", 3], "58,26": ["ammo", 6], "59,26": ["med", 1]},
		"names": {"31,1": "g1_orders", "49,4": "commander_letter", "43,3": "comms_log", "40,15": "cell_scratch", "15,24": "specimen_report"},
		"messages": {
			"g1_orders": "OPERATIONS BOARD: \"Priority one: recover the drill core intact. Priority two: recover live specimens. Priority three: personnel. Strike priority three if it slows one or two.\"",
			"commander_letter": "UNSENT LETTER, commander's desk: \"They told us it was a chemical spill. Then they told us to keep the infected alive. Then they told us the infected were the cargo. I have stopped asking what we are guarding.\"",
			"comms_log": "COMMS LOG: \"Mainland asks for a head count every six hours. Station survivors: not counted. Specimens: four live, crated. Aircraft: one, grounded by ice. The supply pilot's helicopter.\"",
			"cell_scratch": "SCRATCHED INTO THE CELL WALL: \"I'm not sick. I told them I'm not sick. They took blood every day and they never told me the results. If you read this - they're afraid of the cold room. Ask why.\"",
			"specimen_report": "SPECIMEN REPORT S-4: \"Subject keeps singing at the same pitch as the core sample. When the two are in the same room, both grow. Recommend they are never shipped together.\"",
		},
	},

	"gate_one_safe": {
		"theme": "military",
		"title": "Gate One - Ready Room (Safe)",
		"outdoor": false,
		"safe": true,
		"set": "barracks",
		"map": [
			"#####D######",
			"#CC.....CCH#",
			"#.R.....Y..#",
			"#..........#",
			"#CC......M.#",
			"############",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"g1safe": {"cell": Vector2i(5, 0), "to": "gate_one_base", "spawn_dir": Vector2i(0, 1)},
		},
		"entries": {"radio": Vector2i(2, 3)},
		"names": {"2,2": "radio_gate"},
		"messages": {},
	},

	# 1962 年的記憶：冷戰時期的監聽站「燈籠」（後來改建成北緯站）。從 B1 的盤式錄音機進來，
	# 走到錄音室播放最後一捲帶子 = 回到現在。被抓到 = 從記憶的開頭重來（檢查點在入口）。
	"lantern_1962": {
		"theme": "military",
		"era": "1962",
		"lit": true,
		"title": "LANTERN Listening Post - 1962",
		"cutscene": "lantern_enter",
		"floor": -1,
		"outdoor": false,
		"powered_area": true,
		"sets": [
			{"rect": Rect2i(1, 1, 6, 6), "set": "barracks"}, {"rect": Rect2i(8, 1, 14, 6), "set": "comms"},
			{"rect": Rect2i(23, 1, 16, 6), "set": "comms"}, {"rect": Rect2i(1, 12, 10, 5), "set": "barracks"},
			{"rect": Rect2i(12, 12, 14, 5), "set": "mess"}, {"rect": Rect2i(27, 12, 12, 5), "set": "office"},
		],
		"props": {"25,2": "set/tape_drive", "25,3": "set/tape_drive", "33,2": "set/radio_rack", "36,3": "set/server", "36,4": "set/tape_drive"},
		"map": [
			"########################################",
			"#......#..............#................#",
			"#......#...N..........#..C.......C..&..#",
			"#......#....1.....2...#..C..........C..#",
			"#..CC..+..............+.....N.......C..#",
			"#..CC..#..............#..CCC....CCC....#",
			"#H.....#....CCCC......#................#",
			"###+####....CCCC......#######++#########",
			"#......................................#",
			"#...3..............................4...#",
			"#......................................#",
			"#######++##############++#######+#######",
			"#..........#..............#............#",
			"#..C..C....#....5.........#..CC..CC....#",
			"#..C..C..x.#..........6...#..........H.#",
			"#..C..C....#..CCC...CCC...#..CC..CC....#",
			"#....M.....#..............#....N.......#",
			"########################################",
		],
		"enemies": [
			{"type": "guard", "route": "12"},
			{"type": "guard", "route": "34"},
			{"type": "guard", "route": "56"},
		],
		"zones": {"lantern": {"rect": Rect2i(0, 0, 40, 18), "heated": true}},
		"breakers": [],
		"doors": {},
		"entries": {"start": Vector2i(3, 2)},
		"names": {"36,2": "reel_1962", "11,2": "lantern_log", "28,4": "major_order", "31,16": "sato_letter"},
		"reels": {"36,2": {"to": "station_b1", "entry": "reel", "scene": "lantern_signal", "flag": "memory:lantern", "prompt": "Play the last reel"}},
		"messages": {
			"lantern_log": "LANTERN LOG, 14 MARCH 1962: \"Carrier on 126.05 again, from under the ice. Tonight it read us tomorrow's weather. It was right. Then it read a list of names. None of them are born yet.\"",
			"major_order": "ORDER, MAJOR IWASE: \"Effective immediately: the 126.05 recordings do not exist. Reels to be sealed and shipped to Geneva. Personnel who listened will be transferred. Do not discuss the music.\"",
			"sato_letter": "LETTER, CORPORAL SATO (unsent): \"Mika - they're burying the reels. I kept one. If this station is still standing when you're grown, there is a med kit in the maintenance room, under the reel table. I don't know why I'm telling a child that. The signal told me to.\"",
		},
	},

	# ── 郵輪「北極星號」（MV Boreal Star）：失蹤的極地探險郵輪，卡在北港外的浮冰裡。典藏派把它當成浮動的隔離病房。
	# 散步甲板（戶外、暴風雪，繞上層建築一圈）＋船艙（客艙走廊、中庭、酒吧、廚房、劇院，無縫合併在甲板中間）
	# ＋貨艙（樓梯往下：船員區、貨櫃、輪機室、冷藏庫）＋頂層甲板（Boss：典獄長）。地圖規格在 tools/map_specs/batch4.py。
	"cruise_deck": {
		"theme": "military",
		"title": "MV Boreal Star - Promenade Deck",
		"outdoor": true,
		"climate": "blizzard",
		"floor": 1,
		"cutscene": "boreal_star",
		"outdoor_set": "deck",
		"sets": [
			{"rect": Rect2i(59, 13, 3, 4), "set": "hold"},
		],
		"props": {"8,1": "set/lifeboat", "16,1": "set/lifeboat", "24,1": "set/lifeboat", "34,1": "set/lifeboat", "42,1": "set/lifeboat", "50,1": "set/lifeboat", "12,30": "set/lifeboat", "20,30": "set/lifeboat", "38,30": "set/lifeboat", "46,30": "set/lifeboat", "9,29": "set/barrier", "2,10": "set/crates", "2,19": "set/crates", "3,6": "set/winch", "59,25": "set/winch", "62,20": "set/crate_tarp", "28,31": "set/bollard", "31,31": "set/bollard"},
		"map": [
			"################################################################",
			"#.......CCCC....CCCC....CCCC......CCCC....CCCC....CCCC.........#",
			"#.......CCCC....CCCC....CCCC......CCCC....CCCC....CCCC.........#",
			"#............3................................4...............C#",
			"#.....##################################################.......#",
			"#.....##################################################.......#",
			"#..C..##################################################....C..#",
			"#.....##################################################.......#",
			"#....o##################################################.5.....#",
			"#.....##################################################.......#",
			"#.CCC.##################################################.......#",
			"#.CCC.##################################################.......#",
			"#.....##################################################..######",
			"#.....##################################################..#G.G##",
			"#.....##################################################..#...##",
			"#C...C##################################################..+...##",
			"#.....##################################################..#...##",
			"#.....##################################################..######",
			"#.....##################################################.......#",
			"#.CC..##################################################.......#",
			"#.CC..##################################################.....|C#",
			"#...;.##################################################.......#",
			"#.....##################################################....C..#",
			"#r....##################################################.......#",
			"#.....##################################################.......#",
			"#.....###########################D######################...C...#",
			"#.........C.......C.....................C.......C..............#",
			"#..............................................................#",
			"#.............1.............................2..................#",
			"#........CC...................................................C#",
			"#..w........CCCC....CCCC..............CCCC....CCCC.............#",
			"#...........CCCC....CCCC....C..C......CCCC....CCCC.............#",
			"######D#########################################################",
		],
		"enemies": [
			{"type": "guard", "route": "12"},
			{"type": "guard", "route": "34"},
			{"type": "runner", "route": "5"},
		],
		"zones": {"deck": {"rect": Rect2i(0, 0, 64, 33), "heated": false}},
		"indoor_rects": [Rect2i(59, 13, 3, 4)],
		"breakers": [],
		"reinforcements": {"type": "guard", "count": 2, "doors": ["gangway"]},
		"doors": {
			"gangway": {"cell": Vector2i(6, 32), "to": "north_harbor", "spawn_dir": Vector2i(0, -1)},
			"atrium": {"cell": Vector2i(33, 25), "to": "cruise_interior", "spawn_dir": Vector2i(0, 1)},
		},
		"stairs": {"59,13": "cruise_sundeck", "61,13": "cruise_hold"},
		"entries": {"stairs": Vector2i(60, 14)},
		"loot": {"3,30": ["flares", 1]},
		"names": {},
		"messages": {},
	},

	"cruise_interior": {
		"theme": "dorm",
		"title": "MV Boreal Star - Grand Atrium",
		"outdoor": false,
		"floor": 1,
		"cutscene": "atrium",
		"set": "cabin",
		"sets": [
			{"rect": Rect2i(1, 12, 8, 9), "set": "mess"},
			{"rect": Rect2i(6, 8, 4, 3), "set": "mess"},
			{"rect": Rect2i(10, 12, 12, 9), "set": "saloon"},
			{"rect": Rect2i(23, 12, 10, 9), "set": "saloon"},
			{"rect": Rect2i(34, 12, 11, 9), "set": "theater"},
			{"rect": Rect2i(21, 8, 5, 3), "set": "office"},
			{"rect": Rect2i(41, 8, 8, 3), "set": "medical"},
		],
		"props": {"45,1": "set/desk_wide", "25,15": "set/piano", "43,13": "set/piano", "23,12": "set/plant", "32,12": "set/plant", "23,20": "set/plant", "32,20": "set/plant", "30,18": "set/sofa", "24,19": "set/sofa", "19,12": "set/slot_machine", "21,12": "set/slot_machine", "12,12": "set/bar_counter", "42,20": "set/plant", "44,20": "set/plant"},
		"map": [
			"##################################################",
			"#C.CC#C.CC#C.CC#C.CC#C.CC#C.CC#C.CC#C.CC#CC..CC.C#",
			"#....#....#....#....#....#....#....#....#.....N..#",
			"#...H#....#.x..#....#...y#....#.x..#...M#.......:#",
			"##+####+####+####+####+####+####+####+######+#####",
			"#.........C..............C.........C.........2...#",
			"#...1...............x...................b........#",
			"##+####+####+####+#####+###..###+####+######+#####",
			"#..CC#...C#..CC#..CC#C..CC#..#...CC#..CC#CC...CC.#",
			"#....#...C#....#....#s....#..#.....#....#........#",
			"#C...#C...#...C#...H#....l#..#H....#...C#.x.....M#",
			"#######+###################..#####################",
			"#CCCC....#..CCCCCC.C.C#C........C#...........#C.C#",
			"#........#............=..........=.........C.#...#",
			"#.....4..#............#..........#.CCCCCC....+...#",
			"#..CCC...#..C..C..C...+..CN......+...........#...#",
			"#C.......+....3.......+......6...+.CCCCCC..a.#C..#",
			"#C.......#............#..........#...........#...#",
			"#..CCC...#..C..C..C...=.......CC.=.CCCCCC....#.A.#",
			"#........#.........5..#.CC.......#...........#...#",
			"#.......C#x...........#C........C#........C.C#..H#",
			"###########################D######################",
		],
		"enemies": [
			{"type": "patroller", "route": "12"},
			{"type": "listener", "route": "35"},
			{"type": "husk", "route": "4"},
			{"type": "chorister", "route": "a"},
			{"type": "runner", "route": "b6"},
		],
		"zones": {"ship": {"rect": Rect2i(0, 0, 50, 22), "heated": false}},
		"breakers": [],
		"doors": {
			"atrium": {"cell": Vector2i(27, 21), "to": "cruise_deck", "spawn_dir": Vector2i(0, -1)},
		},
		"safes": {"21,9": {"reveal": "reveal:cache_ship", "text": "SAFE (purser's office): a purser's note. \"Passengers' valuables moved to the hold, crate row 3, with the Ark cargo. God forgive me, I signed for it.\""}},
		"names": {"46,2": "captain_log", "26,15": "atrium_note"},
		"messages": {
			"captain_log": "CAPTAIN'S LOG, MV BOREAL STAR: \"Day 41 in the ice. The Ark doctors say the 'patients' must not be moved. Passengers confined to cabins. The singing from the theatre started again at midnight.\"",
			"atrium_note": "NOTE ON THE PIANO: \"They held a concert for the sick ones. The sick ones sang back. Nobody clapped.\"",
		},
	},

	"cruise_hold": {
		"theme": "industrial",
		"title": "MV Boreal Star - Cargo Hold",
		"outdoor": false,
		"floor": -1,
		"hidden": {"22,11": "reveal:cache_ship", "23,11": "reveal:cache_ship"},
		"set": "hold",
		"sets": [
			{"rect": Rect2i(1, 1, 7, 4), "set": "storage"},
			{"rect": Rect2i(1, 6, 7, 5), "set": "cabin"},
			{"rect": Rect2i(1, 12, 7, 4), "set": "utility"},
			{"rect": Rect2i(35, 1, 12, 8), "set": "utility"},
			{"rect": Rect2i(35, 10, 12, 6), "set": "lab"},
		],
		"props": {"36,2": "set/boiler", "39,2": "set/boiler", "43,2": "set/genset", "37,6": "set/pipe_run", "3,14": "set/pipe_run"},
		"map": [
			"################################################",
			"#.G...CC#..#.....................x#...........C#",
			"#.......+..+.CCCC.CCCCCC.CCCC.CCC.#.CC.CC..CC..#",
			"#.......#..#.CCCC.CCCCCC.CCCC.CCC.#.CC.CC..CC..#",
			"#....x..#..#........1.............+............#",
			"#########..#......................+.......a....#",
			"#CC.CC.C#..#..CCCCCC..CCCC.CCCCCC.#..CCCC......#",
			"#.......#..+..CCCCCC..CCCC.CCCCCC.#...b.......C#",
			"#.......+..+......................#............#",
			"#CC.....#..#..............2.......######+#######",
			"#....:.H#..#.CCCC.CCCC..CCCCCC.CC.#...........N#",
			"#########..#.CCCC.CCCCAMCCCCCC.CC.#.CC.CC.CC...#",
			"#C.C.C..#..#....c..............CC.+.CC.CC.CC...#",
			"#.......+..#......................#..........d.#",
			"#..CC...#..+.CCCCCC..CCCC..CCCC...#.CC.CC.CC...#",
			"#.......#..#xCCCCCC..CCCC..CCCC...#.CC.CC.CC..k#",
			"################################################",
		],
		"enemies": [
			{"type": "spitter", "route": "1"},
			{"type": "brute", "route": "2"},
			{"type": "crawler", "route": "ab"},
			{"type": "sleeper", "route": "c"},
			{"type": "sleeper", "route": "d"},
		],
		"zones": {"hold": {"rect": Rect2i(0, 0, 48, 17), "heated": false}},
		"breakers": [],
		"doors": {},
		"stairs": {"2,1": "cruise_deck"},
		"entries": {"stairs": Vector2i(2, 2)},
		"names": {"46,10": "ark_manifest"},
		"messages": {
			"ark_manifest": "ARK MANIFEST, BOREAL STAR: \"Cargo: 212 passengers (sedated), 38 crew, 6 crates of core ice. Destination: none. The ship IS the destination. Keep it cold. Keep them listening.\"",
		},
	},

	"cruise_sundeck": {
		"theme": "military",
		"title": "MV Boreal Star - Sun Deck",
		"outdoor": true,
		"climate": "blizzard",
		"floor": 2,
		"boss": "THE WARDEN",
		"cutscene": "warden",
		"music": "boss_bear",
		"outdoor_set": "deck",
		"props": {"1,7": "set/lifeboat", "1,13": "set/lifeboat", "1,19": "set/lifeboat", "39,7": "set/lifeboat", "39,13": "set/lifeboat", "39,19": "set/lifeboat", "19,6": "set/funnel", "8,10": "set/bar_counter", "32,10": "set/bar_counter", "9,17": "set/crates", "32,17": "set/crates", "14,13": "set/deck_chair", "14,15": "set/deck_chair", "29,13": "set/deck_chair", "29,15": "set/deck_chair", "19,20": "set/cowl_vent", "25,20": "set/cowl_vent", "12,6": "set/cowl_vent", "31,6": "set/cowl_vent"},
		"map": [
			"############################################",
			"#..........................................#",
			"#...1.................2................3...#",
			"#..........................................#",
			"#=======...==========...=========...=======#",
			"#..........................................#",
			"#...........C......CCCCCC......C...........#",
			"#CCCC..............CCCCCC..............CCCC#",
			"#CCCC..............CCCCCC..............CCCC#",
			"#..........................................#",
			"#.......CCCC....................CCCC.......#",
			"#..........................................#",
			"#...............~~~~~~~~~~~~...............#",
			"#CCCC.........C.~~~~~~~~~~~~.C.........CCCC#",
			"#CCCC...........~~~~~~~~~~~~...........CCCC#",
			"#.............C.~~~~~~~~~~~~.C.............#",
			"#...............~~~~~~~~~~~~...............#",
			"#........CCC....................CCC........#",
			"#........CCC....................CCC........#",
			"#CCCC..................................CCCC#",
			"#CCCC..............C.....C.............CCCC#",
			"#..........................................#",
			"#..........................................#",
			"#.....................G....................#",
			"############################################",
		],
		"enemies": [
			{"type": "warden", "route": "123"},
		],
		"zones": {"sundeck": {"rect": Rect2i(0, 0, 44, 25), "heated": false}},
		"breakers": [],
		"doors": {},
		"stairs": {"22,23": "cruise_deck"},
		"entries": {"stairs": Vector2i(22, 22)},
		"names": {},
		"messages": {},
	},
}


## 同一棟建築裡的房間：合併進主區域的地圖（無縫：門是自動門，直接走進去，不切換畫面）。
## door = 兩邊共用的門 id；合併後那扇門變成室內門（+）。房間自己的設定（安全屋、標題）變成「區域內的一塊範圍」。
const ROOMS := {
	"station_1f": {"into": "south_shore", "door": "front", "also": ["cargo"]},
	"fuel_depot": {"into": "south_shore", "door": "depot"},
	"station_safe": {"into": "station_1f", "door": "safe"},
	"station_2f_office": {"into": "station_2f", "door": "office"},
	"station_east_wing": {"into": "station_2f", "door": "east_wing"},
	"huts_safe": {"into": "weather_huts", "door": "bunk"},
	"ice_caves": {"into": "north_harbor", "door": "caves"},
	"gate_one_yard": {"into": "ice_caves", "door": "gate_tunnel"},
	"gate_one_base": {"into": "gate_one_yard", "door": "base_gate"},
	"gate_one_safe": {"into": "gate_one_base", "door": "g1safe"},
	"cruise_interior": {"into": "cruise_deck", "door": "atrium"},
}

static var _composed := {}
static var _layout_data: Dictionary = DATA
static var _layout_rooms: Dictionary = ROOMS


## 目前用的地圖資料（測試可以換成舊版的固定地圖，見 use_layout）
static func all() -> Dictionary:
	return _layout_data


static func rooms() -> Dictionary:
	return _layout_rooms


## 換一份地圖資料（行為測試用：tools/tests/legacy_areas.gd）。不給參數 = 換回正式的地圖。
static func use_layout(data: Dictionary = DATA, room_table: Dictionary = ROOMS) -> void:
	_layout_data = data
	_layout_rooms = room_table
	_composed.clear()



## 這個區域（或房間）實際所在的地圖
static func root_of(area_id: String) -> String:
	var id := area_id
	while rooms().has(id):
		id = rooms()[id].into
	return id


static func get_area(area_id: String) -> Dictionary:
	assert(all().has(area_id), "沒有這個區域：%s" % area_id)
	var root := root_of(area_id)
	if not _composed.has(root):
		_composed[root] = _compose(root)
	return _composed[root]


## 這個區域（或房間）的格子座標 + 位移 = 合併後地圖的座標。
## 房間在主地圖左邊／上面時，主地圖自己也會往右下移，所以主區域的位移不一定是 0。
static func area_offset(area_id: String) -> Vector2i:
	return get_area(area_id).offsets[area_id]


## 房間貼進主地圖的位移（舊名稱，同 area_offset）
static func room_offset(room_id: String) -> Vector2i:
	return area_offset(room_id)


## 把房間（或整棟建築、相鄰的戶外區域）貼進主區域的地圖，所有格子座標換成合併後地圖的座標。
## - 房間可以有敵人（巡邏點換成格子座標 cells）、也可以有自己的房間（巢狀：先把房間自己組好再貼進來）。
## - 房間可以在主地圖的任何方向：在左邊／上面時整張主地圖往右下移。
## - 室內建築貼進戶外地圖：自動加進 indoor_rects（室內地板、不失溫），房間黑幕讓沒進去前看不到裡面。
## - 每個房間記成一個範圍 regions（標題、安全屋、主題、氣候、音樂、電燈、敵人編號起點），Level 依位置查。
## - 存檔 key 一律用「原本的區域 id:原本的座標」（item_keys），溫度區域的旗標也用原本的區域 id，舊存檔照樣能用。
static func _compose(root: String) -> Dictionary:
	var data: Dictionary = all()[root].duplicate(true)
	data["regions"] = []
	data["item_keys"] = {}
	data["offsets"] = {root: Vector2i.ZERO}
	data["breaker_cells"] = {}
	data["region_cells"] = {}
	_tag_zones(data, root)
	_tag_breakers(data, root)
	var rooms: Array = []
	var shift := Vector2i.ZERO
	for room_id in rooms():
		if rooms()[room_id].into != root:
			continue
		var room: Dictionary = _compose(room_id)
		var door_id: String = rooms()[room_id].door
		var off: Vector2i = data.doors[door_id].cell - room.doors[door_id].cell
		for extra in rooms()[room_id].get("also", []):
			assert(data.doors[extra].cell - room.doors[extra].cell == off, "房間 %s 的門 %s 對不上" % [room_id, extra])
		rooms.append([room_id, room, off])
		shift = Vector2i(maxi(shift.x, -off.x), maxi(shift.y, -off.y))
	if shift != Vector2i.ZERO:
		for key in _cell_keys(data.map):
			data.item_keys[key] = "%s:%s" % [root, key]
		data = _shifted(data, shift)
		var rows0: Array = []
		for i in shift.y:
			rows0.append("")
		for r in data.map:
			rows0.append("#".repeat(shift.x) + r)
		data.map = rows0
	var map: Array = data.map.duplicate()
	for entry in rooms:
		var room_id: String = entry[0]
		var room0: Dictionary = entry[1]
		var offset: Vector2i = entry[2] + shift
		var door_id: String = rooms()[room_id].door
		var shared: Vector2i = data.doors[door_id].cell
		var room := _shifted(room0, offset)
		# 敵人：巡邏點字元換成格子座標（避免和主地圖的巡邏點衝突），地圖上那格變回地板
		var rows: Array = room0.map.duplicate()
		var enemy_start: int = data.enemies.size()
		var enemies: Array = data.enemies.duplicate()
		for ei in room0.get("enemies", []).size():
			var def: Dictionary = room0.enemies[ei]
			var cells: Array[Vector2i] = []
			if def.has("cells"):
				for c in def.cells:
					cells.append(c + offset)
			else:
				for ch in String(def.route):
					var at := _find_char(rows, ch)
					assert(at.x >= 0, "房間 %s 缺少巡邏點 %s" % [room_id, ch])
					cells.append(at + offset)
			# 存檔 key 用原本的區域和編號（打倒的敵人、離開時的位置）
			enemies.append({"type": def.type, "cells": cells, "key": def.get("key", "%s:%d" % [room_id, ei])})
		for def in room0.get("enemies", []):
			for ch in String(def.get("route", "")):
				var at := _find_char(rows, ch)
				var line0: String = rows[at.y]
				line0[at.x] = "."
				rows[at.y] = line0
		data["enemies"] = enemies
		# 地圖（記下真的貼上去的格子：這個房間的範圍）
		var mine := {}
		for y in rows.size():
			var gy := offset.y + y
			while map.size() <= gy:
				map.append("")
			var line: String = map[gy]
			var needed: int = offset.x + String(rows[y]).length()
			if line.length() < needed:
				line += "#".repeat(needed - line.length())
			for x in String(rows[y]).length():
				# 房間的空白邊（#）不蓋掉主地圖已經有的地板：鄰近的區域可以互相貼得很近
				if rows[y][x] == "#" and line[offset.x + x] != "#":
					continue
				line[offset.x + x] = rows[y][x]
				mine[Vector2i(offset.x + x, gy)] = rows[y][x] != "#"
			map[gy] = line
		# 共用的門變成室內門；權限、電力設定留在門上
		var shared_ids: Array = [door_id]
		shared_ids.append_array(rooms()[room_id].get("also", []))
		var inner: Dictionary = data.get("inner_doors", {})
		inner.merge(room.get("inner_doors", {}))
		var region_doors: Array = data.get("region_doors", []).duplicate()
		for rd in room.get("region_doors", []):
			region_doors.append(rd)
		for sid in shared_ids:
			var sc: Vector2i = data.doors[sid].cell
			# 走過這扇門＝進入／離開這個範圍：存檢查點用（主地圖這邊的入口 = 門外一格）
			var outer: Vector2i = sc + data.doors[sid].spawn_dir
			var ents: Dictionary = data.get("entries", {})
			if not ents.has(sid):
				ents[sid] = outer
			data["entries"] = ents
			region_doors.append({"region": root, "door": sid, "cell": outer})
			region_doors.append({"region": room_id, "door": sid, "cell": room.doors[sid].cell + room.doors[sid].spawn_dir})
			var door_line: String = map[sc.y]
			door_line[sc.x] = "+"
			map[sc.y] = door_line
			var pair: Dictionary = data.doors[sid]
			inner["%d,%d" % [sc.x, sc.y]] = {"access": pair.get("access", 0), "power": pair.get("power", false),
				"safe": room0.get("safe", false)}
			data.doors.erase(sid)
		data["inner_doors"] = inner
		data["region_doors"] = region_doors
		for d in room.doors:
			if not shared_ids.has(d):
				data.doors[d] = room.doors[d]
		# 入口：「房間:入口」，不衝突的話也可以直接用入口名
		var entries: Dictionary = data.get("entries", {})
		for e in room.get("entries", {}):
			var cell: Vector2i = room.entries[e]
			entries["%s:%s" % [room_id, e]] = cell
			if not entries.has(e):
				entries[e] = cell
		for sid in shared_ids:
			entries["%s:%s" % [room_id, sid]] = room.doors[sid].cell + room.doors[sid].spawn_dir
		data["entries"] = entries
		for field in ["names", "hidden", "loot", "stairs", "safes", "gear", "reels", "item_keys", "breaker_cells", "offsets", "props"]:
			var dst: Dictionary = data.get(field, {})
			dst.merge(room.get(field, {}), true)
			data[field] = dst
		for key in _cell_keys(room0.map):
			var k2 := _shift_key(key, offset)
			if not data.item_keys.has(k2):
				data.item_keys[k2] = "%s:%s" % [room_id, key]
		for field in ["learn", "messages"]:
			var dst2: Dictionary = data.get(field, {})
			dst2.merge(room.get(field, {}))
			data[field] = dst2
		# 溫度區域：名稱重複時改成「房間:名稱」（配電箱指向新名稱）
		var zones: Dictionary = data.get("zones", {})
		for z in room.zones:
			var zname: String = z if not zones.has(z) else "%s:%s" % [room_id, z]
			zones[zname] = room.zones[z]
			if zname != z:
				for bk in room.breaker_cells:
					if room.breaker_cells[bk] == z:
						data.breaker_cells[bk] = zname
		data["zones"] = zones
		var hazards: Array = data.get("hazards", []).duplicate()
		hazards.append_array(room.get("hazards", []))
		var cams: Array = data.get("camera_zones", []).duplicate()
		cams.append_array(room.get("camera_zones", []))
		data["camera_zones"] = cams
		var sets: Array = data.get("sets", []).duplicate()
		sets.append_array(room.get("sets", []))
		data["sets"] = sets
		data["hazards"] = hazards
		# 範圍：巢狀的房間放前面（region_at 找第一個符合的＝最裡面那間）
		var base_index: int = data.regions.size()
		for r in room.regions:
			var rc: Dictionary = r.duplicate()
			rc.enemy_start = rc.get("enemy_start", 0) + enemy_start
			data.regions.append(rc)
		for c in room.region_cells:
			data.region_cells[c] = room.region_cells[c] + base_index
		# 這個房間自己的格子：貼上去的地板，和緊鄰地板的牆（共用的門不算）
		var own_index: int = data.regions.size()
		var shared_cells: Array = shared_ids.map(func(sid): return room.doors[sid].cell)
		for c in mine:
			if room.region_cells.has(c) or shared_cells.has(c):
				continue
			var take: bool = mine[c]
			if not take:
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if mine.get(c + Vector2i(dx, dy), false):
							take = true
			if take:
				data.region_cells[c] = own_index
		var rect := _content_rect(rows, offset, shared_cells)
		data.regions.append({"id": room_id, "rect": rect, "safe": room0.get("safe", false), "title": room0.title,
			"powered": room0.get("powered_area", false), "theme": room0.get("theme", ""),
			"outdoor": room0.get("outdoor", false), "climate": room0.get("climate", ""),
			"music": room0.get("music", ""), "ambience": room0.get("ambience", ""), "step": room0.get("step", ""),
			"outdoor_set": room0.get("outdoor_set", ""), "set": room0.get("set", ""),
			"enemy_start": enemy_start})
		# 戶外區域裡的建築（倉庫、崗哨）照樣是室內
		var ir: Array = data.get("indoor_rects", []).duplicate()
		ir.append_array(room.get("indoor_rects", []))
		data["indoor_rects"] = ir
	data.map = map
	return data


## 房間實際佔的範圍：不是 # 的格子（共用的門不算）外擴一格，限制在房間地圖裡
static func _content_rect(rows: Array, offset: Vector2i, shared: Array) -> Rect2i:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-1, -1)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#" or shared.has(Vector2i(x, y) + offset):
				continue
			lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
			hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	if hi.x < 0:
		return Rect2i(offset, Vector2i.ZERO)
	lo = Vector2i(maxi(lo.x - 1, 0), maxi(lo.y - 1, 0))
	hi = Vector2i(hi.x + 1, mini(hi.y + 1, rows.size() - 1))
	return Rect2i(lo + offset, hi - lo + Vector2i.ONE)


## 主區域自己的溫度區域、配電箱記上原本的區域 id（存檔旗標、配電箱都對得上）
static func _tag_zones(data: Dictionary, area_id: String) -> void:
	var zones: Dictionary = {}
	for z in data.get("zones", {}):
		var zc: Dictionary = data.zones[z].duplicate()
		if not zc.has("area"):
			zc["area"] = area_id
			zc["name"] = z
		zones[z] = zc
	data["zones"] = zones


static func _tag_breakers(data: Dictionary, _area_id: String) -> void:
	var i := 0
	for y in data.map.size():
		var row: String = data.map[y]
		for x in row.length():
			if row[x] == "X":
				data.breaker_cells["%d,%d" % [x, y]] = data.breakers[i]
				i += 1


## 整個區域資料的格子座標都加上 off（地圖本身不動）
static func _shifted(d: Dictionary, off: Vector2i) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	for field in ["names", "hidden", "loot", "stairs", "safes", "gear", "reels", "item_keys", "breaker_cells", "inner_doors", "props"]:
		var dst := {}
		for key in d.get(field, {}):
			dst[_shift_key(key, off)] = d[field][key]
		out[field] = dst
	var doors := {}
	for id in d.get("doors", {}):
		var dc: Dictionary = d.doors[id].duplicate()
		dc.cell += off
		doors[id] = dc
	out["doors"] = doors
	var entries := {}
	for e in d.get("entries", {}):
		entries[e] = d.entries[e] + off
	out["entries"] = entries
	var zones := {}
	for z in d.get("zones", {}):
		var zc: Dictionary = d.zones[z].duplicate()
		zc.rect = Rect2i(zc.rect.position + off, zc.rect.size)
		zones[z] = zc
	out["zones"] = zones
	for field in ["hazards", "regions", "camera_zones", "sets"]:
		var arr: Array = []
		for item in d.get(field, []):
			var ic: Dictionary = item.duplicate()
			ic.rect = Rect2i(ic.rect.position + off, ic.rect.size)
			if ic.has("frame"):
				ic.frame = ic.frame + off
			arr.append(ic)
		out[field] = arr
	var ir: Array = []
	for r in d.get("indoor_rects", []):
		ir.append(Rect2i(r.position + off, r.size))
	out["indoor_rects"] = ir
	var en: Array = []
	for def in d.get("enemies", []):
		var dc2: Dictionary = def.duplicate()
		if dc2.has("cells"):
			var cs: Array[Vector2i] = []
			for c in dc2.cells:
				cs.append(c + off)
			dc2.cells = cs
		en.append(dc2)
	out["enemies"] = en
	var rds: Array = []
	for rd in d.get("region_doors", []):
		var rdc: Dictionary = rd.duplicate()
		rdc.cell += off
		rds.append(rdc)
	out["region_doors"] = rds
	var rcells := {}
	for c in d.get("region_cells", {}):
		rcells[c + off] = d.region_cells[c]
	out["region_cells"] = rcells
	var offs := {}
	for k in d.get("offsets", {}):
		offs[k] = d.offsets[k] + off
	out["offsets"] = offs
	return out


static func _shift_key(key: String, offset: Vector2i) -> String:
	var p := key.split(",")
	return "%d,%d" % [int(p[0]) + offset.x, int(p[1]) + offset.y]


static func _find_char(rows: Array, ch: String) -> Vector2i:
	for y in rows.size():
		var x := String(rows[y]).find(ch)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


static func _cell_keys(rows: Array) -> Array[String]:
	var keys: Array[String] = []
	for y in rows.size():
		for x in String(rows[y]).length():
			if not "#.".contains(rows[y][x]):
				keys.append("%d,%d" % [x, y])
	return keys
