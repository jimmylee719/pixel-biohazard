"""第一批：海閘碼頭（原本的南岸）、研究站一樓、無菌室、燃料庫。"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import Map

AREAS = {}

# ── 海閘碼頭：島的南邊，鑿進岩壁的水泥碼頭（補給船停在這裡）。不在雪地、不冷。
#    北牆兩扇門進研究站（正門、貨物門），東邊的捲門出去是燃料庫（戶外），西邊的檢查哨通往氣象小屋的隧道，
#    西北角的維修通道往北到機庫的捲門。
m = Map(52, 32)
m.room(1, 1, 3, 16)                       # 維修通道（往機庫）
m.put(2, 0, "D")
m.col(3, 3, "C").col(1, 7, "CC").col(3, 12, "C")
m.room(1, 17, 50, 11)                     # 碼頭
m.put(10, 16, "D").put(41, 16, "D")
m.room(1, 28, 50, 3, "~")                 # 水道
m.put(51, 22, "D")
# 檢查哨（西邊，通往氣象小屋的隧道）
m.wall(1, 21, 9, 21).wall(1, 26, 9, 26).wall(9, 21, 9, 26)
m.put(9, 24, "+").put(9, 22, "=").put(0, 23, "D")
m.put(3, 22, "CC").put(7, 22, "C").put(1, 25, "H").put(4, 24, "l").put(3, 25, "A").put(7, 25, "x")
# 北牆邊的貨、管線
m.put(5, 17, "CC").put(19, 17, "CCC").put(30, 17, "CC").put(45, 17, "CC")
# 貨櫃、卡車、木箱
m.block(13, 19, 4, 2).block(20, 21, 2, 2).block(24, 19, 4, 2).block(31, 21, 5, 2).block(37, 19, 3, 2).block(44, 23, 2, 2)
# 岸邊的護欄、繫船柱、路燈
m.put(12, 26, "CCC").put(27, 26, "CCCC").put(38, 26, "CC")
for x in (11, 24, 34, 43):
    m.put(x, 27, "C")
for x, y in ((11, 22), (29, 23), (47, 20)):
    m.put(x, y, "C")
m.block(16, 28, 3, 2)                     # 補給船（停在水道裡）
m.put(18, 26, "P").put(20, 26, "t").put(27, 18, "B").put(49, 18, "A").put(47, 18, "K")
m.put(41, 24, "o").put(49, 26, "r").put(42, 26, "x")
m.put(2, 10, "1").put(7, 19, "2").put(29, 24, "3").put(42, 20, "4")
AREAS["south_shore"] = {
    "map": m.rows(),
    "doors": {"hangar": (2, 0), "front": (10, 16), "cargo": (41, 16), "huts": (0, 23), "depot": (51, 22)},
    "fields": {
        "title": '"Sea Gate"', "theme": '"industrial"', "outdoor": "false", "set": '"dock"', "climate": '"temperate"', "lit": "true",
        "zones": "{}",
        "sets": '[{"rect": Rect2i(1, 22, 8, 4), "set": "office"}]',
        "props": '{"31,21": "set/truck", "16,28": "set/boat", "11,27": "set/bollard", "24,27": "set/bollard", "34,27": "set/bollard", '
                 '"43,27": "set/bollard", "11,22": "set/lamp_post", "29,23": "set/lamp_post", "47,20": "set/lamp_post", '
                 '"12,26": "set/barrier", "27,26": "set/barrier", "38,26": "set/barrier", "19,17": "set/pipe_run"}',
        "doors": '''{
			"front": {"cell": Vector2i(10, 16), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"huts": {"cell": Vector2i(0, 23), "to": "weather_huts", "spawn_dir": Vector2i(1, 0)},
			"cargo": {"cell": Vector2i(41, 16), "to": "station_1f", "spawn_dir": Vector2i(0, 1)},
			"depot": {"cell": Vector2i(51, 22), "to": "fuel_depot", "spawn_dir": Vector2i(-1, 0)},
			# 機庫的捲門是電動的：要先恢復電力（機庫是 Boss 戰場，維持獨立區域）
			"hangar": {"cell": Vector2i(2, 0), "to": "hangar", "spawn_dir": Vector2i(0, 1), "power": true},
		}''',
    },
}

# ── 研究站一樓：中間一條東西向的走廊，北邊是樓梯間、餐廳、廚房、準備室（通無菌室）、濕實驗室，
#    南邊是接待大廳（正門）、保全室、倉庫、卸貨區（貨物門）。地下室的門在走廊東端。
AREAS["station_1f"] = {
    "map": """
#########################D##################
#G..l#CC.CC.CC#CCCC.CC#.......#CCCC.N.CCCCC#
#....#........#......H#.......#............#
#....+..CC.CC.+..CC...+...q...+..CC..CC..T.#
#H...#..CC.CC.#..CC.B.#.......#..CC..CC....#
#....#1.......#M......#C..X..C#.a.....I..bV#
###+######+#######+######+######+####+######
#..........2.....................c.........D
#.................3........................#
####+##########+###########+###+####+#######
#CC...CCCC..#CC.CCCC..#CCCC.CC#........A...#
#...........#.........#.......#.CC..CC..CC.#
#..CCC......+...CC....#.......#.CC..CC..CC.#
#......4....#...CC..A.#..CC...#.......d....#
#H..........#^.....B..#..CC.A.#CC.....5.LS.#
#....6....CC#H.....CC.#.......#CC..B.......#
#####D##############################D#######
""",
    "allow_diff": True,
    "fields": {
        "zones": '''{
			"lounge": {"rect": Rect2i(0, 0, 23, 17), "heated": true},
			"lab": {"rect": Rect2i(23, 0, 21, 17), "heated": true},
		}''',
        "climate": '"arctic"',
        "entries": '{"stairs": Vector2i(2, 2)}',
        "sets": '''[
			{"rect": Rect2i(1, 1, 4, 5), "set": "lounge"}, {"rect": Rect2i(6, 1, 8, 5), "set": "mess"},
			{"rect": Rect2i(15, 1, 7, 5), "set": "mess"}, {"rect": Rect2i(23, 1, 7, 5), "set": "medical"},
			{"rect": Rect2i(31, 1, 12, 5), "set": "lab"}, {"rect": Rect2i(1, 10, 11, 6), "set": "lounge"},
			{"rect": Rect2i(13, 10, 9, 6), "set": "comms"}, {"rect": Rect2i(23, 10, 7, 6), "set": "storage"},
			{"rect": Rect2i(31, 10, 12, 6), "set": "garage"},
		]''',
        "props": '{"15,1": "set/counter", "20,1": "set/fridge", "21,1": "set/stove", "6,1": "set/vending", "7,1": "set/water_cooler", '
                 '"1,10": "set/sofa", "6,10": "set/desk_wide", "13,10": "set/gun_cabinet", "14,10": "props/cabinet", '
                 '"16,10": "set/desk_wide", "10,15": "set/plant", "11,15": "set/vending"}',
        "doors": '''{
			"front": {"cell": Vector2i(5, 16), "to": "south_shore", "spawn_dir": Vector2i(0, -1)},
			"cargo": {"cell": Vector2i(36, 16), "to": "south_shore", "spawn_dir": Vector2i(0, -1)},
			"safe": {"cell": Vector2i(25, 0), "to": "station_safe", "spawn_dir": Vector2i(0, 1)},
			"basement": {"cell": Vector2i(43, 7), "to": "station_b1", "spawn_dir": Vector2i(-1, 0), "access": 2},
		}''',
    },
}

# ── 無菌室（安全屋）：準備室北邊的小房間
AREAS["station_safe"] = {
    "map": """
#############
#CC.R..CCC.Y#
#...........#
#C.........M#
#C...CC.....#
#....CC...CC#
#...........#
######D######
""",
    "fields": {
        "entries": '{\n\t\t\t"radio": Vector2i(4, 2),\n\t\t}',
        "camera_zones": '[{"rect": Rect2i(1, 1, 11, 6), "zoom": 1.25}]',
        "climate": '"arctic"',
        "doors": '{\n\t\t\t"safe": {"cell": Vector2i(6, 7), "to": "station_1f", "spawn_dir": Vector2i(0, -1)},\n\t\t}',
    },
}

# ── 燃料庫：碼頭東邊捲門外的戶外廠區（第一次走到雪地）。北邊是油槽和管線，東邊是倉庫（保暖裝備、柴油）。
m = Map(36, 20)
m.room(1, 1, 34, 18)
m.put(0, 10, "D")
m.box(17, 3, 18, 12)                      # 倉庫（裡面 x18–33、y4–13）
m.put(17, 9, "+").put(25, 14, "p")
m.put(19, 4, "N").put(19, 5, "tt").put(19, 7, "t")
m.put(22, 4, "CCC").put(27, 4, "CC").put(31, 4, "C")
m.put(23, 7, "CCCC").put(29, 7, "CCC").put(23, 10, "CCCC").put(29, 10, "CCC")
m.put(32, 5, "F").put(33, 9, "w").put(20, 12, "w").put(26, 12, "B").put(19, 13, "A").put(33, 13, "H")
m.put(27, 8, "a").put(31, 12, "b")
m.block(3, 2, 5, 2).block(10, 2, 4, 2)    # 油槽
m.put(3, 5, "CCCC").put(10, 5, "CCC")     # 管線
m.block(5, 13, 4, 2)                      # 卡車
m.block(12, 16, 2, 2)                     # 貨櫃
m.put(2, 8, "l").put(15, 2, "H").put(9, 8, "o").put(15, 17, "r").put(2, 16, "ML")
m.put(1, 12, "C").put(15, 11, "C").put(11, 9, "C")
m.put(4, 10, "1").put(13, 7, "2").put(10, 16, "3")
m.wall(17, 16, 34, 18)                    # 倉庫南邊只留一條小巷
m.put(22, 15, "CC").wall(29, 15, 34, 15)
AREAS["fuel_depot"] = {
    "map": m.rows(),
    "fields": {
        "indoor_rects": "[Rect2i(18, 4, 16, 10)]",
        "zones": '{\n\t\t\t"outside": {"rect": Rect2i(0, 0, 36, 20), "heated": false},\n\t\t}',
        "climate": '"arctic"',
        "sets": '[{"rect": Rect2i(18, 4, 16, 10), "set": "storage"}]',
        "props": '{"3,2": "set/tank", "10,2": "set/tank", "3,5": "set/pipe_run", "10,5": "set/pipe_run", "5,13": "set/truck", '
                 '"1,12": "set/lamp_post", "15,11": "set/lamp_post", "11,9": "set/signpost"}',
    },
}

if __name__ == "__main__":
    for k, v in AREAS.items():
        print(k)
        if isinstance(v["map"], list):
            m2 = Map(len(v["map"][0]), len(v["map"]))
            m2.g = [list(r) for r in v["map"]]
            m2.show()
