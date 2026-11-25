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
class_name Areas
extends RefCounted

const START_AREA := "south_shore"
## 沒有設定 climate 的區域用這個氣候（見 Climates）
const DEFAULT_CLIMATE := "arctic"
const START_ENTRY := "start"

const DATA := {
	"south_shore": {
		"theme": "outdoor",
		"cutscene": "opening",
		"title": "South Shore",
		"outdoor": true,
		"map": [
			"########################################",
			"########################################",
			"########################################",
			"########################################",
			"########################################",
			"########################################",
			"########################################",
			"######D#############D#########D#########",
			"#.......l..............................#",
			"#....................................A.#",
			"#...1...........2......................#",
			"#...........CC.........................#",
			"D..........................CC..........#",
			"#..........................CC..........#",
			"#.....4.........3......................#",
			"#.........B......CC....................D",
			"#................................CC....#",
			"#..................CCCCC.........CC....#",
			"#..CC..............CCCCC...............#",
			"#..CC.r................................#",
			"#........C..............C..............#",
			"#........C...........Pt.C...........K..#",
			"#.............................o........#",
			"#.A....................................#",
			"########################################",
		],
		"gear": {"22,21": "wool_hat"},
		"enemies": [
			{"type": "patroller", "route": "1234"},
		],
		# 戶外整區都是冷的：感染者在外面行動遲緩
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 40, 25), "heated": false},
		},
		"breakers": [],
		"doors": {
			"front": {"cell": Vector2i(6, 7), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"huts": {"cell": Vector2i(0, 12), "to": "weather_huts", "spawn_dir": Vector2i(1, 0)},
			"cargo": {"cell": Vector2i(30, 7), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"depot": {"cell": Vector2i(39, 15), "to": "fuel_depot", "spawn_dir": Vector2i(-1, 0)},
			# 機庫的捲門是電動的：要先恢復電力
			"hangar": {"cell": Vector2i(20, 7), "to": "hangar", "spawn_dir": Vector2i(0, 1), "power": true},
		},
		"names": {
			"36,21": "supply_crate_shore",
		},
		# 聽過 127.80 的作業日誌之後才會出現
		"hidden": {
			"37,9": "reveal:cache_shore",
		},
		"messages": {},
	},

	"station_1f": {
		"theme": "lab",
		"cutscene": "station_first",
		"title": "Station 1F",
		"powered_area": true,
		"outdoor": false,
		"map": [
			"############################################",
			"#......H.........A.###########D#############",
			"#.G.......1........####........X..N......###",
			"#...............2..====.W.......a.....B..###",
			"#...CC......CC.....####.............I....###",
			"#...CC......CC............CCCCC..CCCCC...###",
			"D..l.....................................###",
			"#..................####..d..............H###",
			"#...CC......CC....H####..................###",
			"#...CC......CC.....####...CCCCC..CCCCC...###",
			"#..............3...####................b.###",
			"#...............M..####H.c............T.V###",
			"########...############..................###",
			"########+++#################+++#############",
			"########.4.#################...#############",
			"########...#################...#############",
			"########...#################...#############",
			"########.q..............C...............####",
			"########......B.5.....6.C.....A.........####",
			"########............H................LS.####",
			"##############D###################....######",
			"##################################.B..######",
			"##################################....######",
			"##################################....######",
			"###################################D########",
		],
		"enemies": [
			{"type": "patroller", "route": "123456"},
			{"type": "listener", "route": "abcd"},
		],
		"zones": {
			"lounge": {"rect": Rect2i(1, 1, 18, 11), "heated": true},
			"lab": {"rect": Rect2i(23, 2, 18, 11), "heated": true},
		},
		"breakers": ["lounge"],
		"doors": {
			"front": {"cell": Vector2i(0, 6), "to": "south_shore", "spawn_dir": Vector2i(1, 0)},
			"cargo": {"cell": Vector2i(35, 24), "to": "south_shore", "spawn_dir": Vector2i(0, -1)},
			"safe": {"cell": Vector2i(14, 20), "to": "station_safe", "spawn_dir": Vector2i(0, -1)},
			"basement": {"cell": Vector2i(30, 1), "to": "station_b1", "spawn_dir": Vector2i(0, 1), "access": 2},
		},
		"stairs": {"2,2": "station_2f"},
		"entries": {"stairs": Vector2i(2, 3)},
		"names": {
			"31,2": "lounge_breaker",
			"2,2": "stairs_up",
			"38,11": "tape_lab",
			"34,2": "note_lab",
		},
		# 聽過 124.35 Mendez 的錄音之後才會出現
		"hidden": {
			"37,19": "reveal:shotgun_1f",
			"38,19": "reveal:shotgun_1f",
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
		"map": [
			"#########D##########",
			"#..................#",
			"#..R...........Y...#",
			"#..................#",
			"#..CC..........CC..#",
			"#..CC..........CC..#",
			"#..................#",
			"#.........M........#",
			"#..................#",
			"####################",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"safe": {"cell": Vector2i(9, 0), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
		},
		"entries": {
			"radio": Vector2i(3, 3),
		},
		"names": {
			"3,2": "radio_safe",
		},
		"messages": {},
	},

	"station_2f": {
		"theme": "dorm",
		"title": "Station 2F",
		"floor": 2,
		"powered_area": true,
		"outdoor": false,
		"map": [
			"########################################",
			"#.....#...........#...........#.ttt...##",
			"#.G...#.CC.....CC.#.CC...d.Q..#.....M.##",
			"#.....#.......x...#...........#..CC...##",
			"#.....#.....a.....#....b......#..CC....D",
			"#.....#.CC.....CC.#.CC.....CC.#.......##",
			"#.....#....x......#...x.......#......H##",
			"#.....#...........#...........#.......##",
			"###.########.###########.#########.#####",
			"#......................................#",
			"#....1....................c.........2..D",
			"#H...............................x...l.#",
			"############.###########################",
			"#######...........######################",
			"#######..x......L.######################",
			"########################################",
		],
		"gear": {"32,1": "sneaking_suit", "33,1": "balaclava", "34,1": "soft_soles"},
		"enemies": [
			{"type": "patroller", "route": "12"},
			{"type": "sleeper", "route": "a"},
			{"type": "sleeper", "route": "b"},
			{"type": "sleeper", "route": "c"},
			{"type": "sleeper", "route": "d"},
		],
		# 二樓的暖氣壞了：整層都是冷的，凍眠體才會一直睡著
		"zones": {
			"upper": {"rect": Rect2i(0, 0, 40, 16), "heated": false, "powered": true},
		},
		"breakers": [],
		"doors": {
			"office": {"cell": Vector2i(39, 10), "to": "station_2f_office", "spawn_dir": Vector2i(-1, 0), "access": 1},
			"east_wing": {"cell": Vector2i(39, 4), "to": "station_east_wing", "spawn_dir": Vector2i(-1, 0)},
		},
		"stairs": {"2,2": "station_1f"},
		"entries": {"stairs": Vector2i(2, 3)},
		"names": {
			"27,2": "keycard_2f",
		},
		"messages": {},
	},

	"station_2f_office": {
		"theme": "office",
		"title": "Director's Office",
		"powered_area": true,
		"outdoor": false,
		"map": [
			"################",
			"#..............#",
			"#..N........O..#",
			"#..............#",
			"#.......CC.....#",
			"D.......CC.....#",
			"#..............#",
			"#............V.#",
			"#..............#",
			"################",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"office": {"cell": Vector2i(0, 5), "to": "station_2f", "spawn_dir": Vector2i(1, 0)},
		},
		"names": {
			"12,2": "director_terminal",
			"3,2": "note_office",
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
		"indoor_rects": [Rect2i(19, 4, 18, 11)],
		"map": [
			"########################################",
			"#......................................#",
			"#..ML....CC............................#",
			"#........CC.......####################.#",
			"#...............H.#.N................#.#",
			"#.....CC..........#.tt.............F.#.#",
			"#.....CC..........#..CCCC...CCCC.....#.#",
			"#.................#.t................#.#",
			"#.............2...#.......a......CC..#.#",
			"#..CC............................CC.w#.#",
			"D..l..............#..CCCC...CCCC.CC..#.#",
			"#.................#..............CC..#.#",
			"#...........CC....#......B.......CC..#.#",
			"#..1........CC....#.A.w.........b...H#.#",
			"#.................#..................#.#",
			"#..............C..#########p##########.#",
			"#....o...3.....C.......................#",
			"#......................................#",
			"#.......r..............................#",
			"########################################",
			"########################################",
			"########################################",
		],
		"hidden": {"3,2": "reveal:cache_depot", "4,2": "reveal:cache_depot"},
		"gear": {"20,5": "arctic_suit", "21,5": "snow_goggles", "20,7": "crampons"},
		"enemies": [
			{"type": "patroller", "route": "123"},
			{"type": "listener", "route": "ab"},
		],
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 40, 22), "heated": false},
		},
		"breakers": [],
		"doors": {
			"depot": {"cell": Vector2i(0, 10), "to": "south_shore", "spawn_dir": Vector2i(1, 0)},
		},
		"names": {
			"35,5": "fuel_can",
			"20,4": "manifest_depot",
		},
		"loot": {
			"22,13": ["ethanol", 1],
			"36,9": ["bottle", 2],
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
		"map": [
			"##D#####################################",
			"#...l..................................#",
			"#.....1.............................2..#",
			"#......................................#",
			"#...##############.......#######.#######",
			"#...##############.......#............H#",
			"#...##############....s..#.............#",
			"#...######.##########.####.............#",
			"#................#.......#.............#",
			"#....a...x.....V.#.......#....CCCC.....#",
			"#.....CC.....CC..#..CC...#....CCCCE....#",
			"#.....CC.....CC..#.......#....CCCC.....#",
			"#........b.......#.......#....CCCC.....#",
			"#..........x.....#.......#..........3..#",
			"#.....CC.....CCc.#.....L.#...........M.#",
			"#H...............#.......#.............#",
			"#####################D##################",
			"########################################",
		],
		"safes": {"22,6": {"reveal": "reveal:cache_caves", "text": "SAFE (maintenance office): a hunter's ledger. \"Left spare .308 and two flares in the ice caves, east end, below the glowing wall. In case.\""}},
		"enemies": [
			{"type": "patroller", "route": "123"},
			{"type": "sleeper", "route": "a"},
			{"type": "sleeper", "route": "b"},
			{"type": "sleeper", "route": "c"},
		],
		# 樣本冷凍庫一直是冷的（電力恢復後冷凍櫃更冷）；其他地方恢復電力後有暖氣
		"zones": {
			"freezer": {"rect": Rect2i(4, 8, 13, 8), "heated": false},
			"b1": {"rect": Rect2i(0, 0, 40, 18), "heated": false, "powered": true},
		},
		"breakers": [],
		"doors": {
			"basement": {"cell": Vector2i(2, 0), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"shaft": {"cell": Vector2i(21, 16), "to": "drill_shaft", "spawn_dir": Vector2i(0, -1), "access": 3},
		},
		"names": {
			"34,10": "generator_b1",
		},
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
		"map": [
			"########################################",
			"########################################",
			"##############............##############",
			"##############.G........H.##############",
			"##############....CC......##############",
			"##############.x........B.##############",
			"##############............##############",
			"###################..###################",
			"#......................................#",
			"#...................b.........##########",
			"#.............................#.N...M.##",
			"#.............................#.....AH##",
			"#.....................................##",
			"#.............................#.......##",
			"#.............................##########",
			"#....1...............CC.............2..#",
			"#......................................#",
			"#.......CC.........a........CC.........#",
			"#.......CC..................CC.........#",
			"#......................................#",
			"#...Z...........CC...................A.#",
			"#....4..........CC..........3..........#",
			"#......................................#",
			"########################################",
		],
		"enemies": [
			{"type": "patroller", "route": "1234"},
			{"type": "patroller", "route": "ab"},
		],
		"zones": {
			"yard": {"rect": Rect2i(0, 0, 40, 24), "heated": false},
		},
		"indoor_rects": [Rect2i(14, 2, 12, 5), Rect2i(31, 10, 7, 4)],
		"breakers": [],
		"doors": {},
		"stairs": {"15,3": "tower_top"},
		"entries": {"stairs": Vector2i(16, 4), "snowcat": Vector2i(6, 20)},
		"snowcat_to": "hangar",
		"names": {
			"4,20": "snowcat_tower",
			"32,10": "note_relay",
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
		"title": "Shaft Bottom",
		"outdoor": false,
		"floor": -3,
		"camera": "fixed",
		"boss": "THE DEEP WELL",
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
		"map": [
			"###############D################################################",
			"#..CCCC..CCCC....CCCC.....CCCC.....CCCC...........CCCC...CCCC..#",
			"#..CCCC..CCCC....CCCC.....CCCC.....CCCC...........CCCC...CCCC..#",
			"#.............................CCC..............................#",
			"#.........o...................u................................#",
			"#..............................................................#",
			"#...................r...................###########............#",
			"#.......1.................4.............###########............#",
			"#................................CC.....###########.x..........#",
			"#.......................................###########............#",
			"#....CC.....#############...............###########............#",
			"#....CC.....#.......N...#...............###########............#",
			"#...........#.I.......w.#...............#####D#####....CC......#",
			"#...........#...........#.CC...........................CC......#",
			"#...........p..a........#.CC...................................#",
			"#...........#........b..#...........7.................5........#",
			"#...........#q..B......H#......................................#",
			"#...........#...........#.............CC.......................#",
			"#...........######..#####.............CC....................l..D",
			"#.....................................CC.......................#",
			"#.....CCC.........o...........................u................#",
			"#.....CCC.................................................8....#",
			"#...........................####.####..........................#",
			"#...........................#.......#..........CC..............#",
			"#...2.................3.....#....N.u#..........CC..............#",
			"#...........................#..x....#..........................#",
			"#.............CC............#.......#.............ww...........#",
			"#.............CC............#H....M.#..........................#",
			"#.......r...................#.......#..........................#",
			"#...........................#########....................CC....#",
			"#.......................................c...r............CC....#",
			"#......................x..................x....................#",
			"#.....ALu................d............................6........#",
			"#..............................................................#",
			"#..............................................................#",
			"################################################################",
		],
		"enemies": [
			{"type": "patroller", "route": "1234"},
			{"type": "patroller", "route": "56"},
			{"type": "patroller", "route": "78"},
			{"type": "listener", "route": "ab"},
			{"type": "sleeper", "route": "c"},
			{"type": "sleeper", "route": "d"},
		],
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 64, 36), "heated": false},
		},
		"indoor_rects": [Rect2i(13, 11, 11, 7), Rect2i(29, 23, 7, 6)],
		"breakers": [],
		"doors": {
			"huts": {"cell": Vector2i(63, 18), "to": "south_shore", "spawn_dir": Vector2i(-1, 0)},
			"bunk": {"cell": Vector2i(45, 12), "to": "huts_safe", "spawn_dir": Vector2i(0, 1)},
			"harbor": {"cell": Vector2i(15, 0), "to": "north_harbor", "spawn_dir": Vector2i(0, 1)},
		},
		"names": {
			"10,4": "beacon_drum",
			"20,11": "met_log",
			"33,24": "pieter_note",
		},
		# 點燃稜線上的信標之後，補給無人機投下的東西
		"hidden": {
			"6,32": "reveal:huts_cache",
			"7,32": "reveal:huts_cache",
			"8,32": "reveal:huts_cache",
		},
		"loot": {
			"22,12": ["heat_pack", 1],
			"50,26": ["stone", 3],
			"51,26": ["ethanol", 1],
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
			"################",
			"#..R........Y..#",
			"#..............#",
			"#.CC.......H...#",
			"#.CC...........#",
			"#.......u......#",
			"#..............#",
			"#..............#",
			"#######D########",
		],
		"enemies": [],
		"zones": {},
		"breakers": [],
		"doors": {
			"bunk": {"cell": Vector2i(7, 8), "to": "weather_huts", "spawn_dir": Vector2i(0, -1)},
		},
		"entries": {"radio": Vector2i(3, 2)},
		"names": {"3,1": "radio_huts"},
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
		"map": [
			"################################################",
			"####################....########################",
			"####################.CC.########################",
			"####################....########################",
			"#..........y......................CCCC.........#",
			"#..1...CCCC.......................CCCC.....2...#",
			"#......CCCC.........3..........................#",
			"#...........................###=######=#####...#",
			"#....CC.....................#.........#t.t#....#",
			"#....CC.....................#..CC..a..#.H.#....#",
			"#...........r...............=..CC.....+t..#....#",
			"#...........................#..s...N..#...#....#",
			"#......CCC..........4.......#.v....CC.##+###...#",
			"#......CCC..................#..b...CC.....M#...#",
			"#...........................######++########...#",
			"#..............................................#",
			"#...CC...........CCCC..........................#",
			"#...CC...........CCCC.............k......CC....#",
			"#.....5..........................6.......CC....#",
			"#..............................................D",
			"#.........w.............x......................#",
			"#..............................................#",
			"#....CC..............o.................CC......#",
			"#....CC..........7.....................CC...8..#",
			"#..............................................#",
			"#..........u...................................#",
			"#...........l..................................#",
			"##########D#####################################",
		],
		"safes": {"31,11": {"reveal": "reveal:cache_depot", "text": "SAFE (harbor office): Gatekeeper supply note. \"Medical cache stashed at the fuel depot, northwest corner of the yard, under the tarp.\""}},
		# 港口的暴風雪：沒穿保暖裝備體溫掉很快
		"climate": "blizzard",
		"gear": {"39,8": "eod_armor", "41,8": "eod_helmet", "39,10": "eod_boots"},
		"enemies": [
			{"type": "guard", "route": "12"},
			{"type": "guard", "route": "34"},
			{"type": "guard", "route": "ab"},
			{"type": "guard", "route": "78"},
			{"type": "hound", "route": "56"},
		],
		"zones": {
			"outside": {"rect": Rect2i(0, 0, 48, 28), "heated": false},
		},
		"indoor_rects": [Rect2i(29, 8, 14, 6)],
		"breakers": [],
		"reinforcements": {"type": "guard", "count": 2, "doors": ["harbor", "caves"]},
		"doors": {
			"harbor": {"cell": Vector2i(10, 27), "to": "weather_huts", "spawn_dir": Vector2i(0, -1)},
			"caves": {"cell": Vector2i(47, 19), "to": "ice_caves", "spawn_dir": Vector2i(-1, 0)},
		},
		"names": {"35,11": "gate_orders"},
		"loot": {"10,20": ["shells", 2]},
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
			"#.......######..............####....#......#",
			"#......########......x......####.........u.#",
			"#.......######.............................#",
			"##.......####........CC.........b...########",
			"##...................CC.......####...#######",
			"D..l..u........###............#####...######",
			"##.............####..3....c.......#....#####",
			"###.....a......####...............#.....####",
			"####...........###...........##...........##",
			"#####.....##..............x..###....d.....##",
			"######...####.....4.........####.......yk###",
			"#######..####...........##.........M....####",
			"########.......####.....##.......##....#####",
			"#########.....######...........####...######",
			"############################################",
		],
		"hidden": {"40,16": "reveal:cache_caves", "39,16": "reveal:cache_caves"},
		"climate": "blizzard",
		"hazards": [{"rect": Rect2i(26, 7, 12, 7), "kind": "spores"}],
		"enemies": [
			{"type": "crawler", "route": "12"},
			{"type": "crawler", "route": "34"},
			{"type": "husk", "route": "ab"},
			{"type": "sleeper", "route": "d"},
		],
		"zones": {
			"cave": {"rect": Rect2i(0, 0, 44, 21), "heated": false},
		},
		"breakers": [],
		"doors": {
			"caves": {"cell": Vector2i(0, 11), "to": "north_harbor", "spawn_dir": Vector2i(1, 0)},
		},
		"names": {"42,5": "hunter_note"},
		"messages": {
			"hunter_note": "NOTE, pinned under the rifle: \"Came down here after the dogs. They weren't dogs anymore. Took the rifle off the rack for bears. Doesn't matter what you shoot - it hears the shot from everywhere. - Ivo\"",
		},
	},

	# 北緯站 東翼：生物實驗室。走廊兩側是實驗室（自動門、觀察窗），爬行者、詠者、膨脹者。
	"station_east_wing": {
		"theme": "lab",
		"title": "East Wing",
		"floor": 2,
		"powered_area": true,
		"outdoor": false,
		"cutscene": "east_wing",
		"map": [
			"############################################",
			"#.......#.........#.........#..............#",
			"#..CC...#..CC.CC..#..CC.CC..#..H........m..#",
			"#..CC...#.........#....a....#..............#",
			"#.......#..x......#.........#....CCCC......#",
			"#....N..#....n....#..V......#....CCCC..b...#",
			"#.......#.........#.........#..............#",
			"###++####==++==####==++==####==++==#########",
			"D....l.....1...................2...........#",
			"#.ttt......................................#",
			"###++####==++==####==++==#######++##########",
			"#.......#.........#.........#........#.....#",
			"#..CC...#..CC.CC..#..CC.CC..#...c....#..H..#",
			"#..CC...#....d....#.........#........+..z..#",
			"#...M...#.........#....x....#..CCCC..#.....#",
			"#.......#..A......#.........#..CCCC..#..N..#",
			"#.......#.........#.........#........#.....#",
			"############################################",
		],
		# 孢子外洩的實驗室：沒穿防護裝備會一直感染
		"hazards": [{"rect": Rect2i(19, 1, 9, 6), "kind": "spores"}, {"rect": Rect2i(9, 11, 9, 6), "kind": "spores"}, {"rect": Rect2i(29, 11, 8, 6), "kind": "spores"}],
		"gear": {"2,9": "hazmat_suit", "3,9": "gas_mask", "4,9": "hazmat_boots"},
		"enemies": [
			{"type": "patroller", "route": "12"},
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
		"names": {"5,5": "wing_log", "41,15": "kovac_memo"},
		"messages": {
			"wing_log": "LAB LOG, East Wing: \"Sealed the wing on the director's order. Twelve still inside. He says the cold will keep them asleep. He says a lot of things.\"",
			"kovac_memo": "MEMO - A. KOVAC (dated before she left): \"It isn't a disease. It's a hibernation strategy that uses us as the burrow. Whoever is paying for this already knows that.\"",
		},
	},
}


## 同一棟建築裡的房間：合併進主區域的地圖（無縫：門是自動門，直接走進去，不切換畫面）。
## door = 兩邊共用的門 id；合併後那扇門變成室內門（+）。房間自己的設定（安全屋、標題）變成「區域內的一塊範圍」。
const ROOMS := {
	"station_safe": {"into": "station_1f", "door": "safe"},
	"station_2f_office": {"into": "station_2f", "door": "office"},
	"huts_safe": {"into": "weather_huts", "door": "bunk"},
}

static var _composed := {}


## 這個區域（或房間）實際所在的地圖
static func root_of(area_id: String) -> String:
	return ROOMS[area_id].into if ROOMS.has(area_id) else area_id


static func get_area(area_id: String) -> Dictionary:
	assert(DATA.has(area_id), "沒有這個區域：%s" % area_id)
	var root := root_of(area_id)
	if not _composed.has(root):
		_composed[root] = _compose(root)
	return _composed[root]


## 把房間貼進主區域的地圖，所有格子座標換成主地圖的座標。
## 房間格子上的東西用「房間 id:房間裡的座標」當存檔 key（WorldState 的紀錄和以前一樣）。
static func _compose(root: String) -> Dictionary:
	var data: Dictionary = DATA[root].duplicate(true)
	var map: Array = data.map.duplicate()
	data["regions"] = []
	data["item_keys"] = {}
	for room_id in ROOMS:
		if ROOMS[room_id].into != root:
			continue
		var room: Dictionary = DATA[room_id]
		var door_id: String = ROOMS[room_id].door
		var shared: Vector2i = data.doors[door_id].cell
		var offset: Vector2i = shared - room.doors[door_id].cell
		assert(offset.x >= 0 and offset.y >= 0, "房間 %s 要放在主地圖的右邊或下面" % room_id)
		assert(room.enemies.is_empty(), "房間 %s 不能有敵人（巡邏點符號會衝突）" % room_id)
		# 地圖
		var rows: Array = room.map
		for y in rows.size():
			var gy := offset.y + y
			while map.size() <= gy:
				map.append("")
			var line: String = map[gy]
			var needed: int = offset.x + String(rows[y]).length()
			if line.length() < needed:
				line += "#".repeat(needed - line.length())
			for x in String(rows[y]).length():
				line[offset.x + x] = rows[y][x]
			map[gy] = line
		# 共用的門變成室內門；權限、電力設定留在門上
		var door_line: String = map[shared.y]
		door_line[shared.x] = "+"
		map[shared.y] = door_line
		var inner: Dictionary = data.get("inner_doors", {})
		inner["%d,%d" % [shared.x, shared.y]] = {"access": data.doors[door_id].get("access", 0),
			"safe": room.get("safe", false)}
		data["inner_doors"] = inner
		data.doors.erase(door_id)
		# 其他通往外面的門
		for d in room.doors:
			if d != door_id:
				var copy: Dictionary = room.doors[d].duplicate()
				copy.cell += offset
				data.doors[d] = copy
		# 入口：「房間:入口」，不衝突的話也可以直接用入口名
		var entries: Dictionary = data.get("entries", {})
		for e in room.get("entries", {}):
			var cell: Vector2i = room.entries[e] + offset
			entries["%s:%s" % [room_id, e]] = cell
			if not entries.has(e):
				entries[e] = cell
		var inside: Vector2i = room.doors[door_id].cell + room.doors[door_id].spawn_dir + offset
		entries["%s:%s" % [room_id, door_id]] = inside
		data["entries"] = entries
		# 以格子座標當 key 的資料
		for field in ["names", "hidden", "loot", "stairs"]:
			var src: Dictionary = room.get(field, {})
			var dst: Dictionary = data.get(field, {})
			for key in src:
				var p := String(key).split(",")
				dst["%d,%d" % [int(p[0]) + offset.x, int(p[1]) + offset.y]] = src[key]
			data[field] = dst
		for key in _cell_keys(room.map):
			var p := String(key).split(",")
			data.item_keys["%d,%d" % [int(p[0]) + offset.x, int(p[1]) + offset.y]] = "%s:%s" % [room_id, key]
		for field in ["learn", "messages"]:
			var dst2: Dictionary = data.get(field, {})
			dst2.merge(room.get(field, {}))
			data[field] = dst2
		var zones: Dictionary = data.get("zones", {})
		for z in room.get("zones", {}):
			var zc: Dictionary = room.zones[z].duplicate()
			zc.rect = Rect2i(zc.rect.position + offset, zc.rect.size)
			zones[z] = zc
		data["zones"] = zones
		var rect := Rect2i(offset, Vector2i(String(rows[0]).length(), rows.size()))
		data.regions.append({"id": room_id, "rect": rect, "safe": room.get("safe", false), "title": room.title})
		if data.outdoor:
			var ir: Array = data.get("indoor_rects", []).duplicate()
			ir.append(rect)
			data["indoor_rects"] = ir
	data.map = map
	return data


## 房間貼進主地圖的位移（房間裡的座標 + 位移 = 主地圖的座標）
static func room_offset(room_id: String) -> Vector2i:
	var r: Dictionary = ROOMS[room_id]
	return DATA[r.into].doors[r.door].cell - DATA[room_id].doors[r.door].cell


static func _cell_keys(rows: Array) -> Array[String]:
	var keys: Array[String] = []
	for y in rows.size():
		for x in String(rows[y]).length():
			if not "#.".contains(rows[y][x]):
				keys.append("%d,%d" % [x, y])
	return keys
