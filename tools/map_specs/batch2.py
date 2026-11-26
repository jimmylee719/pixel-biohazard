"""第二批：研究站二樓、站長室、東翼、地下室、機庫、天線塔、鑽井、氣象小屋。"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import Map

AREAS = {}

# ── 二樓（宿舍層）：北邊是樓梯間、兩間寢室、盥洗室、裝備室；南邊是交誼廳、醫務室、倉庫、站長室的前廳。
#    走廊東端通東翼；站長室在前廳南邊（要權限卡）。
AREAS["station_2f"] = {
    "map": """
########################################
#G...#CC..CC.#CC..CC.#C.CCC..#ttt..C.CC#
#....#.......#.......#.......#........H#
#....+.a.....+....b..+..x....+.....Q...#
#H..l#CC..CC.#CC..x..#CC....M#C.......C#
###+####+#######+#######+#######+#######
#....1...............c.............2...D
#......................................#
####+#########+###########+########+####
#CC..CCC.#CC...CCC..#CCCC..CC#CC.......#
#........#..........#........#..x......#
#..CC....#...CC..d..#........#.........#
#..CC..x.#...CC.....#..CC..L.#.........#
#........#H.........#........#......CC.#
#################################D######
""",
    "fields": {
        "zones": '{\n\t\t\t"upper": {"rect": Rect2i(0, 0, 40, 15), "heated": false, "powered": true},\n\t\t}',
        "entries": '{"stairs": Vector2i(2, 2)}',
        "sets": '''[
			{"rect": Rect2i(1, 1, 4, 4), "set": "lounge"}, {"rect": Rect2i(6, 1, 15, 4), "set": "dorm"},
			{"rect": Rect2i(22, 1, 7, 4), "set": "medical"}, {"rect": Rect2i(30, 1, 9, 4), "set": "barracks"},
			{"rect": Rect2i(1, 9, 8, 5), "set": "lounge"}, {"rect": Rect2i(10, 9, 10, 5), "set": "medical"},
			{"rect": Rect2i(21, 9, 8, 5), "set": "storage"}, {"rect": Rect2i(30, 9, 9, 5), "set": "office"},
		]''',
        "set": '"dorm"',
        "props": '{"22,1": "set/sink", "24,1": "set/shelf_linen", "35,1": "set/locker_gear", "37,1": "set/locker_gear", '
                 '"30,4": "set/footlocker", "38,4": "set/footlocker", "30,9": "set/sofa", "36,13": "set/plant"}',
        "doors": '''{
			"office": {"cell": Vector2i(33, 14), "to": "station_2f_office", "spawn_dir": Vector2i(0, -1), "access": 1},
			"east_wing": {"cell": Vector2i(39, 6), "to": "station_east_wing", "spawn_dir": Vector2i(-1, 0)},
		}''',
    },
}

AREAS["station_2f_office"] = {
    "map": """
######D#######
#CCC.....CCCC#
#N.........O.#
#............#
#...CCC......#
#H........CC.#
#.x.......V..#
##############
""",
    "fields": {
        "props": '{"4,4": "set/desk_wide", "1,1": "set/shelf_files", "9,1": "set/sofa", "10,5": "set/plant"}',
        "doors": '{\n\t\t\t"office": {"cell": Vector2i(6, 0), "to": "station_2f", "spawn_dir": Vector2i(0, 1)},\n\t\t}',
    },
}

# 東翼（station_east_wing）在 batch4.py 重畫了。

# ── 地下室：樓梯下來是一條走廊；西邊是樣本冷凍庫（凍眠體），中間是錄音帶檔案室，
#    東邊是發電機房，檔案室南邊的前室通往鑽井（要權限卡）。
AREAS["station_b1"] = {
    "map": """
##D#################################
#...l............1................2#
#..................................#
####+#########+#####+####+##########
#CC..CC..CC....#CCCC.CC#C..CCCC..CC#
#..............#.......#.........;H#
#..a.....x.....#.&..M..#..CC.......#
#CC..........V.#....s..#..CCE......#
#CC....b.......#CC.....#........3..#
#........x.....###+#####.CCCC....M.#
#..CC......CCc.#.......#.CCCC......#
#H.CC......CC..#..L....+...........#
################.......#############
################.......#############
###################D################
""",
    "allow_diff": True,   # 多了一份木柴 ;（發電機旁）
    "doors": {"basement": (2, 0), "shaft": (19, 14)},
    "fields": {
        "camera_zones": '[{"rect": Rect2i(1, 4, 14, 8), "zoom": 1.15}]',
        "zones": '''{
			"freezer": {"rect": Rect2i(1, 4, 14, 8), "heated": false},
			"b1": {"rect": Rect2i(0, 0, 36, 15), "heated": false, "powered": true},
		}''',
        "entries": '{"reel": Vector2i(17, 7)}',
        "sets": '[{"rect": Rect2i(1, 4, 14, 8), "set": "lab"}, {"rect": Rect2i(16, 4, 7, 5), "set": "comms"}, '
                '{"rect": Rect2i(24, 4, 11, 8), "set": "utility"}, {"rect": Rect2i(1, 1, 34, 2), "set": "utility"}]',
        "props": '{"16,4": "set/tape_drive", "17,4": "set/tape_drive", "18,4": "set/server", "19,4": "set/radio_rack", '
                 '"21,4": "set/shelf_files", "22,4": "set/shelf_files", "16,8": "set/oscilloscope", "17,8": "set/console"}',
    },
}

AREAS["hangar"] = {"fields": {"set": '"garage"', "props": '{"8,5": "set/crates", "20,5": "set/container0", "8,9": "set/container1", "20,9": "set/crates"}'}}
AREAS["drill_shaft"] = {"fields": {"set": '"utility"'}}
AREAS["shaft_bottom"] = {"fields": {"set": '"utility"'}}
AREAS["tower_top"] = {"fields": {
    "set": '"utility"', "sets": '[{"rect": Rect2i(1, 1, 11, 6), "set": "comms"}]', "props": '{"20,4": "set/dish"}'}}

# ── 天線塔底的院子（戶外，雪地）：北邊是樓梯小屋，東邊是中繼站，院子裡停著雪地車、貨櫃、油槽。
m = Map(34, 20)
m.room(1, 7, 32, 12)
m.box(12, 1, 10, 6)
m.put(16, 6, "+").put(14, 2, "G").put(20, 2, "H").put(17, 2, "CC").put(14, 4, "x").put(19, 4, "B")
m.box(24, 8, 9, 6)
m.put(24, 10, "+").put(26, 9, "N").put(28, 9, "C").put(30, 9, "M").put(30, 11, "A").put(31, 12, "H").put(26, 12, "CC")
m.put(4, 16, "Z").put(30, 17, "A")
m.block(8, 9, 4, 2).block(17, 15, 3, 2).block(25, 16, 2, 2)
m.put(6, 12, "C").put(15, 11, "C").put(21, 9, "C").put(11, 16, "CC").put(2, 8, "C")
m.put(4, 10, "1").put(29, 15, "2").put(22, 17, "3").put(6, 18, "4").put(15, 13, "a").put(20, 8, "b")
m.put(20, 16, ";")                         # 木柴（油槽旁）
AREAS["tower_yard"] = {
    "map": m.rows(),
    "allow_diff": True,
    "fields": {
        "zones": '{\n\t\t\t"yard": {"rect": Rect2i(0, 0, 34, 20), "heated": false},\n\t\t}',
        "indoor_rects": "[Rect2i(13, 2, 8, 4), Rect2i(25, 9, 7, 4)]",
        "entries": '{"stairs": Vector2i(15, 3), "snowcat": Vector2i(6, 16)}',
        "sets": '[{"rect": Rect2i(13, 2, 8, 4), "set": "utility"}, {"rect": Rect2i(25, 9, 7, 4), "set": "comms"}]',
        "props": '{"17,15": "set/tank", "6,12": "set/lamp_post", "15,11": "set/antenna_mast", "21,9": "set/lamp_post", "2,8": "set/signpost"}',
    },
}

# ── 氣象小屋：隧道出來的雪地聚落。西邊是氣象觀測小屋，北邊是床鋪小屋（安全屋），東邊是彼得的小屋，
#    西北角的岩脊上有信標油桶，北邊的路通往北港。
m = Map(48, 28)
m.room(1, 1, 46, 26)
m.put(12, 0, "D").put(47, 22, "D")
m.wall(18, 3, 29, 9).put(24, 9, "D")       # 床鋪小屋（huts_safe 貼在這裡）
m.box(4, 10, 13, 8)                        # 氣象觀測小屋
m.put(10, 17, "+").put(4, 13, "p").put(16, 13, "=")
m.put(6, 11, "N").put(8, 11, "CCC").put(14, 12, "I").put(14, 15, "w").put(5, 16, "q").put(8, 15, "B").put(15, 16, "H")
m.put(8, 13, "a").put(13, 14, "b").put(12, 11, "CC")
m.box(34, 14, 9, 7)                        # 彼得的小屋
m.put(38, 20, "+").put(36, 15, "N").put(41, 15, "u").put(37, 17, "x").put(35, 19, "H").put(41, 19, "M").put(38, 15, "CC")
m.put(2, 2, "CC").put(2, 3, "C").put(6, 1, "CC").put(8, 5, "C").put(5, 4, "o")   # 岩脊、信標
m.put(33, 6, "u").put(44, 21, "u").put(6, 24, "ALu")
m.put(20, 22, "r").put(3, 20, "r").put(30, 25, "r").put(44, 23, "l").put(27, 22, "ww").put(22, 19, "o")
m.block(38, 4, 4, 2).block(31, 10, 2, 2)   # 貨櫃、木箱
m.put(17, 12, "C").put(22, 14, "CC").put(26, 17, "C").put(14, 21, "CCC").put(34, 23, "CC").put(44, 10, "C").put(2, 14, "C").put(30, 2, "C")
m.put(42, 25, "C").put(24, 25, "CC").put(10, 5, "C").put(45, 16, "C")
m.put(8, 7, "1").put(4, 22, "2").put(20, 24, "3").put(22, 12, "4").put(36, 10, "5").put(40, 24, "6").put(29, 13, "7").put(45, 18, "8")
m.put(31, 21, "c").put(16, 20, "d").put(27, 11, "x").put(12, 23, "x").put(41, 12, "x")
m.put(40, 16, "*").put(36, 18, "|")        # 彼得是獵人：十字弓和弩箭在他的小屋
m.put(45, 10, ";").put(13, 16, ";").put(36, 23, ";")   # 木柴：柴堆旁、觀測小屋、木箱旁
AREAS["weather_huts"] = {
    "map": m.rows(),
    "allow_diff": True,
    "doors": {"harbor": (12, 0), "bunk": (24, 9), "huts": (47, 22)},
    "fields": {
        "zones": '{\n\t\t\t"outside": {"rect": Rect2i(0, 0, 48, 28), "heated": false},\n\t\t}',
        "indoor_rects": "[Rect2i(5, 11, 11, 6), Rect2i(35, 15, 7, 5)]",
        "sets": '[{"rect": Rect2i(1, 1, 9, 5), "set": "wild"}]',
        "props": '{"17,12": "set/antenna_mast", "26,17": "set/lamp_post", "14,21": "set/barrier", "34,23": "set/crates_long", '
                 '"44,10": "set/wood_pile", "2,14": "set/sled", "30,2": "set/snow_mound", "42,25": "set/lamp_post", '
                 '"10,5": "set/signpost", "45,16": "set/snow_mound", "22,14": "set/pipe_run", "24,25": "set/barrier"}',
    },
}

AREAS["huts_safe"] = {
    "map": """
############
#CC.R...Y.H#
#..........#
#C......u..#
#C...CC....#
#..........#
######D#####
""",
    "fields": {"entries": '{"radio": Vector2i(4, 2)}'},
}

if __name__ == "__main__":
    for k in ("weather_huts", "tower_yard"):
        m2 = Map(1, 1)
        m2.g = [list(r) for r in AREAS[k]["map"]]
        m2.w = len(m2.g[0])
        print(k)
        m2.show()
