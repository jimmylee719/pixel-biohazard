"""重新設計 A 組：海閘碼頭、研究站（一樓、無菌室、二樓、站長室、東翼、地下一樓）、燃料庫、機庫、
天線塔（廣場、通訊甲板）、鑽探井（井口、井底）、1962 年的燈籠監聽站。

這個檔案是這些區域地圖的「唯一來源」：python3 tools/area_patch.py tools/map_specs/redesign_a.py [區域 id…]
（舊的 batch1～4 不再使用。）直接執行這個檔案 = 只檢查、把地圖印出來：python3 tools/map_specs/redesign_a.py [區域 id…]

設計原則（參考經典生存恐怖／潛行遊戲的關卡結構，不抄任何一款的地圖）：
  - 空間少而好記：一棟建築 5～8 個空間，每個都有兩個字講得出來的用途、在地圖上認得出輪廓。
  - 每個區域一個「主空間」（大廳、機房、作業大廳……長邊 14～22 格）當樞紐，其他空間掛在它旁邊；
    主空間裡用柱子、成排的機器、大型物件、玻璃隔間切出掩體和視線死角，不留大片空地。
  - 環狀動線：重要的空間之間至少兩條路（主要的一條＋後門／維修通道），走廊只是短短的連接。
  - 大小有變化：一大、幾個中、兩三個小的專用房間；不排一整排一樣的小房間
    （二樓的床位隔間是故意的，一張地圖最多一處）。
  - 先讓玩家隔著窗戶看到目標或鎖著的門，再拿到鑰匙。

寫法：地圖直接畫成文字（Map.parse）或用 painter 畫；有座標的欄位（names、gear、hidden、門……）
用「符號#第幾個」（由上到下、由左到右，從 0 算）或 (x, y) 指定，由 area() 換成座標並檢查，
所以改地圖時不用自己算座標。
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import Map

HERE = os.path.dirname(os.path.abspath(__file__))
SET_DIR = os.path.join(HERE, "..", "..", "assets", "sprites", "set")
LEGACY = os.path.join(HERE, "..", "tests", "legacy_areas.gd")

AREAS = {}
MAPS = {}

## 這一輪新增的大型地標（另一位同事在畫；圖還沒進來時那一塊會用一般家具暫代）：名稱 → 佔幾格
NEW_PROPS = {
    "reactor": (3, 3), "turbine": (4, 2), "drill_rig": (3, 3), "snow_crawler": (4, 2), "crane": (2, 2),
    "specimen_tank": (2, 2), "scanner": (3, 2), "server_bank": (3, 2), "workbench": (3, 2), "reception_desk": (4, 2),
    "pillar": (1, 1), "railing": (1, 1), "forklift": (2, 1), "console_bank": (4, 1), "tape_reel_bank": (3, 1),
    "antenna_mast": (2, 2), "pump_station": (3, 2), "pool_table": (2, 2), "watchtower": (2, 2), "gate_barrier": (3, 1),
}
WALKABLE_NOT = set("#CH=~")
NOT_ITEM = set("#.C")


class Raw(str):
    """直接寫進 areas.gd 的 GDScript 原始碼。"""


def V(x, y):
    return Raw("Vector2i(%d, %d)" % (x, y))


def R(x, y, w, h):
    return Raw("Rect2i(%d, %d, %d, %d)" % (x, y, w, h))


def gd(v, multiline=False):
    if isinstance(v, Raw):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, (list, tuple)):
        items = [gd(x) for x in v]
        if multiline and items:
            return "[\n\t\t\t" + ",\n\t\t\t".join(items) + ",\n\t\t]"
        return "[" + ", ".join(items) + "]"
    if isinstance(v, dict):
        items = ["%s: %s" % (json.dumps(k, ensure_ascii=False), gd(x)) for k, x in v.items()]
        if multiline and items:
            return "{\n\t\t\t" + ",\n\t\t\t".join(items) + ",\n\t\t}"
        return "{" + ", ".join(items) + "}"
    raise TypeError(v)


def _cell(m, ref):
    """(x, y) 或 "符號" 或 "符號#第幾個" → (x, y)"""
    if isinstance(ref, tuple):
        return ref
    ch, _, n = ref.partition("#") if len(ref) > 1 else (ref, "", "")
    return m.find(ch, int(n or 0))


def _key(m, ref):
    return "%d,%d" % _cell(m, ref)


def _legacy_routes(aid):
    text = open(LEGACY, encoding="utf-8").read()
    start = text.index('\n\t"%s": {\n' % aid)
    block = text[start:text.index("\n\t},\n", start)]
    return re.findall(r'"route": "(\w+)"', block)


def _big_sizes(name):
    """這個名稱有哪些大小的圖（已經有的 PNG ＋ 這一輪新增的）。"""
    base = name.split("/")[-1]
    sizes = set()
    if os.path.isdir(SET_DIR):
        for f in os.listdir(SET_DIR):
            mm = re.fullmatch(re.escape(base) + r"_(\d+)x(\d+)\.png", f)
            if mm:
                sizes.add((int(mm.group(1)), int(mm.group(2))))
    if base in NEW_PROPS and NEW_PROPS[base] != (1, 1):
        sizes.add(NEW_PROPS[base])
    return sizes


def area(aid, m, doors, names=None, hidden=None, loot=None, gear=None, stairs=None, reels=None, safes=None,
         props=None, entries=None, sets=None, fields=None):
    """登記一個區域。doors = {id: (哪一格, 目標區域, (dx, dy), 其他欄位的原始碼)}；其他有座標的欄位見檔案開頭。"""
    if isinstance(m, str):
        m = Map.parse(m)
    rows = m.rows()
    problems = []

    def walk(x, y):
        return 0 <= y < m.h and 0 <= x < m.w and rows[y][x] not in WALKABLE_NOT

    out = dict(fields or {})
    # 門
    lines, used = [], set()
    for did, spec in doors.items():
        ref, to, d = spec[0], spec[1], spec[2]
        extra = spec[3] if len(spec) > 3 else ""
        x, y = _cell(m, ref)
        used.add((x, y))
        if rows[y][x] != "D":
            problems.append("門 %s 的格子 (%d,%d) 不是 D" % (did, x, y))
        if not walk(x + d[0], y + d[1]):
            problems.append("門 %s 前面 (%d,%d) 走不進去" % (did, x + d[0], y + d[1]))
        lines.append('"%s": {"cell": Vector2i(%d, %d), "to": "%s", "spawn_dir": Vector2i(%d, %d)%s}'
                     % (did, x, y, to, d[0], d[1], (", " + extra) if extra else ""))
    if m.count("D") != len(used):
        problems.append("地圖上有 %d 個 D，doors 只寫了 %d 個" % (m.count("D"), len(used)))
    out["doors"] = Raw("{\n\t\t\t" + ",\n\t\t\t".join(lines) + ",\n\t\t}") if lines else Raw("{}")
    # 有座標的欄位
    for fname, data in (("names", names), ("hidden", hidden), ("loot", loot), ("gear", gear), ("stairs", stairs),
                        ("reels", reels), ("safes", safes)):
        conv = {}
        for ref, value in (data or {}).items():
            k = _key(m, ref)
            x, y = _cell(m, ref)
            if rows[y][x] in NOT_ITEM:
                problems.append("%s %s 指到 %s" % (fname, k, rows[y][x]))
            conv[k] = value
        out[fname] = Raw(gd(conv, multiline=len(conv) > 1)) if conv or fname == "names" else None
    # 指定的家具：一定要在 C 上；大型物件要剛好是那一塊的左上角、大小有圖
    rect_at = {(x, y): (w, h) for x, y, w, h in m.rects("C")}
    conv = {}
    for (x, y), name in (props or {}).items():
        full = name if "/" in name else "set/" + name
        if rows[y][x] != "C":
            problems.append("props (%d,%d) %s 不在 C 上（是 %s）" % (x, y, name, rows[y][x]))
        sizes = _big_sizes(full)
        size = rect_at.get((x, y))
        if size and size[0] >= 2 and size[1] >= 2:
            if size not in sizes:
                problems.append("props (%d,%d) %s：這一塊是 %dx%d，沒有這個大小的圖（有 %s）" % (x, y, name, size[0], size[1], sorted(sizes)))
        elif sizes and not any(s[1] == 1 for s in sizes) and NEW_PROPS.get(full.split("/")[-1]) != (1, 1) \
                and not os.path.exists(os.path.join(SET_DIR, full.split("/")[-1] + ".png")):
            problems.append("props (%d,%d) %s 是大型物件，但這裡不是 2x2 以上一整塊的左上角" % (x, y, name))
        conv["%d,%d" % (x, y)] = full
    out["props"] = Raw(gd(conv)) if conv else None
    if entries is not None:
        conv = {}
        for name, ref in entries.items():
            x, y = _cell(m, ref)
            if not walk(x, y):
                problems.append("入口 %s (%d,%d) 不能站" % (name, x, y))
            conv[name] = V(x, y)
        out["entries"] = Raw(gd(conv))
    if sets is not None:
        for (x, y, w, h), _s in sets:
            if x < 0 or y < 0 or x + w > m.w or y + h > m.h:
                problems.append("sets 範圍 %s 超出地圖" % ((x, y, w, h),))
        out["sets"] = Raw(gd([{"rect": R(*r), "set": s} for r, s in sets], multiline=len(sets) > 2))
    # 巡邏點
    for route in _legacy_routes(aid):
        for ch in route:
            if m.count(ch) != 1:
                problems.append("巡邏點 %s 有 %d 個" % (ch, m.count(ch)))
    # 連通
    open_cells = {(x, y) for y in range(m.h) for x in range(m.w) if walk(x, y)}
    if open_cells:
        seen, stack = set(), [next(iter(open_cells))]
        seen.add(stack[0])
        while stack:
            x, y = stack.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in open_cells and n not in seen:
                    seen.add(n)
                    stack.append(n)
        if len(seen) != len(open_cells):
            problems.append("有 %d 格走不到（例如 %s）" % (len(open_cells) - len(seen), sorted(open_cells - seen)[0]))
    # 置物櫃、互動物件旁邊要站得到
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "H" and not any(walk(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                problems.append("置物櫃 (%d,%d) 旁邊沒有地板" % (x, y))
    for p in problems:
        print("  !! %s：%s" % (aid, p))
    AREAS[aid] = {"map": rows, "allow_diff": True, "fields": {k: (None if v is None else str(v if isinstance(v, Raw) else gd(v)))
                                                              for k, v in out.items()}}
    MAPS[aid] = m
    return m


def zone_all(name, m, **kw):
    """整張地圖一個溫度區域。"""
    d = {"rect": R(0, 0, m.w, m.h)}
    d.update(kw)
    return Raw("{\n\t\t\t%s: %s,\n\t\t}" % (json.dumps(name), gd(d)))


# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 海閘碼頭（區域 id 仍是 south_shore）：鑿進岩壁的水泥碼頭，開場。一個大空間（碼頭）＋一間檢查哨。
#   - 補給船停在切進碼頭的船渠裡（主角從船上下來）；吊車、貨櫃排成兩條通道（明的一條沿著水邊、
#     暗的一條貼著北牆），卡車停在貨物門前。
#   - 北牆：研究站正門（中間）、貨物門（東）；西北角一小段坡道上去是機庫的電動捲門（一開始就看得到、要電）。
#   - 西邊檢查哨（有窗）後面是往氣象小屋的隧道；東邊捲門出去是燃料庫（戶外，第一次踩到雪）。
#   研究站一樓貼在北牆上面（x 5～48、y 0～16），所以那一塊要全部是牆。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = Map(52, 32)
m.room(1, 12, 3, 5).put(2, 11, "D")                     # 往機庫的坡道
m.room(1, 17, 50, 11)                                   # 碼頭
m.room(1, 28, 50, 3, "~")                               # 水道
m.room(15, 24, 9, 4, "~")                               # 船渠（切進碼頭）
m.put(26, 16, "D").put(41, 16, "D").put(51, 22, "D")
# 檢查哨
m.wall(1, 21, 9, 21).wall(1, 26, 9, 26).wall(9, 21, 9, 26)
m.put(9, 24, "+").put(9, 22, "=").put(9, 23, "=").put(0, 23, "D")
m.put(2, 22, "CC").put(5, 22, "C").put(7, 22, "C").put(1, 25, "H").put(4, 24, "l").put(3, 25, "A").put(7, 25, "x")
m.put(1, 27, "CC")                                      # 檢查哨南邊的角落：油桶
# 補給船、吊車
m.block(18, 25, 3, 2)
m.block(25, 24, 2, 2)
# 北牆邊：管線、木箱
m.put(5, 17, "CC").put(18, 17, "CCC").put(30, 17, "CC").put(45, 17, "CC")
# 貨櫃（兩排，中間是通道）、卡車（倒車對著貨物門）、堆高機
m.block(11, 19, 4, 2).block(17, 19, 2, 3).block(29, 19, 3, 3).block(34, 20, 5, 2).block(45, 20, 2, 3)
m.block(33, 24, 4, 2).block(40, 24, 2, 2)
m.put(21, 21, "CC")
# 岸邊：護欄、繫船柱、路燈
m.put(28, 27, "CCC").put(37, 27, "CCCC").put(46, 27, "CC")
for x in (12, 26, 33, 43):
    m.put(x, 27, "C")
for x, y in ((11, 22), (28, 22), (48, 24)):
    m.put(x, y, "C")
m.put(12, 25, "P").put(14, 25, "t").put(27, 18, "B").put(49, 18, "A").put(47, 18, "K")
m.put(43, 22, "o").put(49, 26, "r").put(31, 25, "x").put(6, 19, "x")
m.put(2, 18, "1").put(8, 19, "2").put(31, 23, "3").put(43, 19, "4")
area("south_shore", m,
     doors={
         "front": ((26, 16), "station_1f", (0, 1)),
         "huts": ((0, 23), "weather_huts", (1, 0)),
         "cargo": ((41, 16), "station_1f", (0, 1)),
         "depot": ((51, 22), "fuel_depot", (-1, 0)),
         # 機庫的捲門是電動的：要先恢復電力（機庫是 Boss 戰場，維持獨立區域）
         "hangar": ((2, 11), "hangar", (0, 1), '"power": true'),
     },
     names={"K": "supply_crate_shore"},
     hidden={"A#0": "reveal:cache_shore"},          # 聽過 127.80 的作業日誌之後才會出現
     gear={"t": "wool_hat"},
     sets=[((1, 22, 8, 4), "office")],
     props={(34, 20): "truck", (18, 25): "boat", (25, 24): "crane", (21, 21): "forklift",
            (12, 27): "bollard", (26, 27): "bollard", (33, 27): "bollard", (43, 27): "bollard",
            (11, 22): "lamp_post", (28, 22): "lamp_post", (48, 24): "lamp_post",
            (28, 27): "barrier", (37, 27): "barrier", (46, 27): "barrier", (18, 17): "pipe_run", (1, 27): "drums_row"},
     fields={"title": "Sea Gate", "theme": "industrial", "outdoor": False, "set": "dock", "climate": "temperate",
             "lit": True, "zones": Raw("{}")})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 研究站一樓（44x17，8 個空間）。主空間 = 中央大廳（正門進來，接待櫃台、四根柱子，樓梯間開在大廳北邊）。
#   西：餐廳（開放式廚房）── 裝備間（玄關置物櫃）── 警衛室（對著大廳的窗，消音器在裡面）
#   北：準備室（配電箱；往北是無菌室＝安全屋，往東是濕實驗室）
#   東：濕實驗室（隔著走廊的玻璃看得到裡面的鳴骨者）── 維修走廊（東端是地下室的門，要權限卡 2）── 車庫（貨物門）
#   環狀動線：大廳→餐廳→裝備間→大廳；大廳→準備室→實驗室→走廊→大廳；大廳→走廊→車庫→大廳。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("station_1f", """
#########################D##################
#CCCC.CC......#G....l#CC...X.#CCC.N.CCC.CCC#
#.............#......#.......#.............#
#..CCC..CCC...#..1...#q......+..CC...CC..T.#
#.............+......#.......#..CC.a.CC....#
#..CCC..CCC...#......####+####.............#
#M..2.......B.#............CC#I.....b.....V#
#.............#..............##+#===#===#+##
####+##########..............+......c......D
#H.H.C.C.C....#.......CC.....#...5.........#
#.............+..C........C..###########+###
#.....B.#######..............#CC.......A...#
#..CC...#CC..C=....CCCC......#...CCCC......#
#..CC...+.....=....CCCC......+...CCCC..d...#
#.......#H..^.#..C........C..#..........CC.#
#H..3..A#...A.#C....4.......C#CC...6.B.LS..#
#####################D##############D#######
""",
     doors={
         "front": ((21, 16), "south_shore", (0, -1)),
         "cargo": ((36, 16), "south_shore", (0, -1)),
         "safe": ((25, 0), "station_safe", (0, 1)),
         "basement": ((43, 8), "station_b1", (-1, 0), '"access": 2'),
     },
     names={"X": "lounge_breaker", "G": "stairs_up", "T": "tape_lab", "N": "note_lab"},
     hidden={"L": "reveal:shotgun_1f", "S": "reveal:shotgun_1f"},   # 聽過 124.35 Mendez 的錄音之後才會出現
     stairs={"G": "station_2f"},
     entries={"stairs": (16, 2)},
     sets=[((1, 1, 13, 7), "mess"), ((15, 1, 6, 5), "lounge"), ((22, 1, 7, 4), "lab"), ((30, 1, 13, 6), "lab"),
           ((15, 6, 14, 10), "lounge"), ((9, 12, 5, 4), "comms"), ((1, 9, 13, 7), "storage"),
           ((30, 8, 13, 2), "utility"), ((30, 11, 13, 5), "garage")],
     props={(6, 1): "fridge", (7, 1): "stove", (19, 12): "reception_desk", (33, 12): "snow_crawler",
            (17, 10): "pillar", (26, 10): "pillar", (17, 14): "pillar", (26, 14): "pillar",
            (15, 15): "plant", (28, 15): "plant", (27, 6): "sofa",
            (5, 9): "locker_gear", (7, 9): "locker_gear", (9, 9): "locker_gear",
            (32, 3): "specimen_tank", (37, 3): "specimen_tank", (13, 12): "gun_cabinet"},
     fields={"climate": "arctic",
             "zones": Raw('{\n\t\t\t"lounge": {"rect": Rect2i(0, 0, 29, 17), "heated": true},\n'
                          '\t\t\t"lab": {"rect": Rect2i(29, 0, 15, 17), "heated": true},\n\t\t}')})

# ── 無菌室（安全屋）：準備室北邊的一間，無線電和儲物箱。
area("station_safe", """
#############
#CC.R..CCC.Y#
#...........#
#C.........M#
#C...CC.....#
#....CC...CC#
#...........#
######D######
""",
     doors={"safe": ((6, 7), "station_1f", (0, -1))},
     names={"R": "radio_safe"},
     entries={"radio": (4, 2)},
     fields={"climate": "arctic", "camera_zones": Raw('[{"rect": Rect2i(1, 1, 11, 6), "zoom": 1.25}]')})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 燃料庫：碼頭東邊捲門外的戶外廠區（第一次走到雪地）＝ 廠區 ＋ 兩棟建築。
#   西北是油槽和泵浦，中間一條從大門到倉庫的車道（卡車停在路邊），東邊是倉庫（主空間：成排的貨架、
#   保暖裝備、柴油；裡面有鳴骨者），西南的泵房是小屋（聽了頻率才出現的補給藏在裡面）。
#   倉庫兩條路：西邊的正門、南邊巷子裡釘著木板的後門。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("fuel_depot", """
####################################
#..................................#
#..CCCCC..CCCC.H...................#
#..CCCCC..CCCC...###################
#................#.N..CCC..CC..C..##
#..CCC....CCC....#.tt.........?.F.##
#..CCC...........#................##
#............2...#.t...CCCC..CCC..##
#.l......o.......#.........a......##
#..............C.+...............w##
D...1..CCCC......#.....CCCC..CCC..##
#......CCCC......#................##
#C...............#..w.....B....b..##
#.....########...#.A.............H##
#.....#.ML..C#...########p##########
#.....+......#........CC.....#######
#.....#CC....#.3.CC;.###############
#..;..########...CC.r.##############
#.....................##############
####################################
""",
     doors={"depot": ((0, 10), "south_shore", (1, 0))},
     names={"F": "fuel_can", "N": "manifest_depot"},
     hidden={"M": "reveal:cache_depot", "L": "reveal:cache_depot"},
     gear={"t#0": "arctic_suit", "t#1": "snow_goggles", "t#2": "crampons"},
     loot={"w#1": ["ethanol", 1], "w#0": ["bottle", 2]},
     sets=[((18, 4, 16, 10), "storage"), ((7, 14, 6, 3), "utility")],
     props={(3, 2): "tank", (10, 2): "tank", (3, 5): "pump_station", (10, 5): "pipe_run", (7, 10): "truck",
            (1, 12): "lamp_post", (15, 9): "lamp_post"},
     fields={"climate": "arctic", "indoor_rects": Raw("[Rect2i(18, 4, 16, 10), Rect2i(7, 14, 6, 3)]"),
             "zones": None})
AREAS["fuel_depot"]["fields"]["zones"] = str(zone_all("outside", m, heated=False))

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 研究站二樓（40x15，6 個空間）：生活區。主空間 = 交誼廳（樓梯上來就是；撞球桌、沙發、柱子）。
#   北：床位區（三個用隔板隔開的床位＝這張地圖唯一的一排小隔間）── 醫務室（掃描儀）── 裝備庫（潛行裝備、權限卡）
#   東：往東翼的走廊（隔著窗看得到站長室的前廳和那扇要權限卡的門）── 前廳（南邊是站長室）
#   環狀動線：交誼廳→床位區→醫務室→走廊→交誼廳；交誼廳→前廳→走廊→交誼廳。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("station_2f", """
########################################
#G...#CC..#CC..#CC..#CCC.CC..C#ttt..C.C#
#....#....#....#....#.........#.......H#
#....#.a..#....#..b.#.....CCC.#....Q...#
#H..l#..............+.....CCC.#C......C#
#..x.+.........x....#...x....M#........#
#....###+########+####=+=#######+#######
#.........CCC.....CCC..................D
#..1...C........C..................2...#
#...................x..###==+==#########
#.........CC...........#.C.......CCC...#
#.........CC......CCC..#...............#
#......C...c....C......+.....d........H#
#CC..H......CCCC.....CC#CC........L..CC#
##############################D#########
""",
     doors={
         "office": ((30, 14), "station_2f_office", (0, -1), '"access": 1'),
         "east_wing": ((39, 7), "station_east_wing", (-1, 0)),
     },
     names={"Q": "keycard_2f"},
     gear={"t#0": "sneaking_suit", "t#1": "balaclava", "t#2": "soft_soles"},
     stairs={"G": "station_1f"},
     entries={"stairs": (2, 2)},
     sets=[((1, 1, 4, 5), "lounge"), ((6, 1, 14, 5), "dorm"), ((21, 1, 9, 5), "medical"), ((31, 1, 8, 5), "barracks"),
           ((1, 6, 23, 8), "lounge"), ((24, 10, 15, 4), "office")],
     props={(26, 3): "scanner", (10, 10): "pool_table", (7, 8): "pillar", (16, 8): "pillar", (7, 12): "pillar",
            (16, 12): "pillar", (36, 1): "locker_gear", (38, 1): "locker_gear", (31, 4): "footlocker",
            (38, 4): "footlocker", (25, 10): "plant"},
     fields={"set": "dorm", "zones": None})
# 二樓的暖氣壞了：整層都是冷的，凍眠體才會一直睡著
AREAS["station_2f"]["fields"]["zones"] = str(zone_all("upper", m, heated=False, powered=True))

# ── 站長室：前廳南邊，要權限卡。
area("station_2f_office", """
######D#######
#CCC.....CCCC#
#N.........O.#
#............#
#...CCC......#
#H........CC.#
#.x.......V..#
##############
""",
     doors={"office": ((6, 0), "station_2f", (0, 1))},
     names={"O": "director_terminal", "N": "note_office"},
     props={(4, 4): "desk_wide", (1, 1): "shelf_files", (9, 1): "sofa", (10, 5): "plant"})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 東翼（38x22，6 個空間，十字形）：生物隔離區。主空間 = 中央的隔離大廳（四座樣本槽、中間的監控主機、柱子；
#   冰甲巨人在裡面巡）。
#   西：除汙室（入口；防護裝備、紀錄；隔著窗看得到大廳）    東：樣本庫（孢子；詠者關在玻璃後面，抗菌藥劑在最裡面）
#   北：低溫實驗室（冷凍槽、掃描儀；兩扇門＋一排窗）          南：機房（發電機、鍋爐；孢子；斧頭、釘槍、Kovac 的備忘）
#   西南：器材間（孢子；爬行者）＝ 除汙室→器材間→機房→大廳 的後路。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("station_east_wing", """
######################################
#########CC.CC.CC....CC.CCC###########
#########CC.CC.CC.........H###########
#########...c...x.....CCC..###########
#########......d......CCC.M###########
#########..................###########
###########+###======###+#############
#CCC.C.C#..................#CC.CC.CCC#
#.......=..CC.C..x...C.CC..=.........#
#.ttt...#..CC..........CC..=..CC..a..#
D.......+1......CCC........#..CC.....#
#.....l.#.......CCC......2.+.........#
#N......=..CC..........CC..#......CC.#
#CC...:.#..CC.C......C.CC..=..x...CC.#
#H......#..................#V........#
####+#######+##########+##############
#CC...CC#CC..CC.CCC........###########
#....x..#CC..CC.CCC.....z.H###########
#.b.....+..................###########
#CC..A..#......CCC....N....###########
#CC.....#n.m...............###########
######################################
""",
     doors={"east_wing": ((0, 10), "station_2f", (1, 0))},
     names={"N#0": "wing_log", "N#1": "kovac_memo"},
     gear={"t#0": "hazmat_suit", "t#1": "gas_mask", "t#2": "hazmat_boots"},
     sets=[((9, 1, 18, 5), "lab"), ((28, 7, 9, 8), "lab"), ((9, 16, 18, 5), "utility"),
           ((1, 16, 7, 5), "storage")],
     props={(1, 7): "locker_gear", (2, 7): "locker_gear", (3, 7): "locker_gear", (5, 7): "shelf_linen", (7, 7): "sink",
            (11, 8): "specimen_tank", (23, 8): "specimen_tank", (11, 12): "specimen_tank", (23, 12): "specimen_tank",
            (16, 10): "server_bank", (14, 8): "pillar", (21, 8): "pillar", (14, 13): "pillar", (21, 13): "pillar",
            (22, 3): "scanner", (9, 1): "cryo_tank", (12, 1): "cryo_tank", (15, 1): "cryo_tank",
            (30, 9): "specimen_tank", (34, 12): "specimen_tank",
            (9, 16): "genset", (13, 16): "boiler", (16, 16): "pump_station"},
     fields={
         # 孢子外洩的房間：沒穿防護裝備會一直感染
         "hazards": Raw('[{"rect": Rect2i(28, 7, 9, 8), "kind": "spores"}, {"rect": Rect2i(1, 16, 7, 5), "kind": "spores"}, '
                        '{"rect": Rect2i(9, 16, 18, 5), "kind": "spores"}]'),
         "zones": None})
AREAS["station_east_wing"]["fields"]["zones"] = str(zone_all("wing", m, heated=False, powered=True))

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 地下一樓（36x15，5 個空間）。主空間 = 發電機大廳（渦輪機組、泵浦、柱子；主線要在這裡加柴油發動發電機）。
#   西北：樓梯口的短走廊    西：樣本冷凍庫（一直是冷的，凍眠體）
#   南：井口閘室（往鑽探井，要權限卡 3；隔著窗從大廳看得到那扇門）、檔案室（1962 年的盤式錄音機、保險箱）
#   環狀動線：走廊→大廳→冷凍庫→走廊。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("station_b1", """
##D#################################
#...l........#CC.CCC..........CCC..#
#.......1....+................CCC..#
####+#########...C...........C.....#
#CC..CC.CC.CC#......CCCC...........#
#............#......CCCC.....E..CC.#
#..a....x....#........2.........CC.#
#CC........V.#...C..CCCC.....C.....#
#CC...CC.....+..................3..#
#.....CC.b...#CC.....;H......M...CC#
#............####+#====#######+#####
#..x......CCc#..........#CCC...CCC.#
#H.CC.....CC.#..L......H#..&...M..s#
#..CC........#..........#..........#
###################D################
""",
     doors={
         "basement": ((2, 0), "station_1f", (0, 1)),
         "shaft": ((19, 14), "drill_shaft", (0, -1), '"access": 3'),
     },
     names={"E": "generator_b1", "&": "reel_b1"},
     # 盤式錄音機：1962 年燈籠站最後一捲帶子。播放 = 走進那一夜（lantern_1962）
     reels={"&": Raw('{"to": "lantern_1962", "entry": "start", "scene": "reel_b1", "prompt": "Play the 1962 reel"}')},
     safes={"s": Raw('{"reveal": "reveal:cache_caves", "text": "SAFE (maintenance office): a hunter\'s ledger. '
                     '\\"Left spare .308 and two flares in the ice caves, east end, below the glowing wall. In case.\\""}')},
     hidden={"M#1": "memory:lantern"},              # 1962 年的佐藤留下的急救包（看完記憶才知道在哪）
     entries={"reel": (27, 13)},
     sets=[((1, 4, 12, 10), "lab"), ((25, 11, 10, 3), "comms")],
     props={(20, 4): "turbine", (32, 5): "genset", (20, 7): "pipe_run", (30, 1): "pump_station", (17, 3): "pillar", (29, 3): "pillar", (17, 7): "pillar",
            (29, 7): "pillar", (25, 11): "tape_drive", (26, 11): "tape_drive", (27, 11): "server",
            (31, 11): "radio_rack", (32, 11): "shelf_files", (33, 11): "shelf_files"},
     fields={"set": "utility", "camera_zones": None,
             # 樣本冷凍庫一直是冷的（電力恢復後冷凍櫃更冷）；其他地方恢復電力後有暖氣
             "zones": Raw('{\n\t\t\t"freezer": {"rect": Rect2i(1, 4, 12, 10), "heated": false},\n'
                          '\t\t\t"b1": {"rect": Rect2i(0, 0, 36, 15), "heated": false, "powered": true},\n\t\t}')})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 機庫（Boss：苔原之母）：固定鏡頭的一整個戰場（30x16 剛好一個畫面），四堆貨當掩體、角落是工作台和置物櫃。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
area("hangar", """
##############################
#.............X..............#
#..CCC..................CC.M.#
#..CCC..................CC...#
#............................#
#.......CC..........CC.......#
#.......CC..........CC.......#
#..............1.............#
#............................#
#.......CC..........CC.......#
#.......CC..........CC.......#
#............................#
#.H..A........Z.........L..H.#
#............................#
#............................#
##############D###############
""",
     doors={"hangar": ((14, 15), "south_shore", (0, -1))},
     names={"Z": "snowcat", "X": "hangar_breaker"},
     entries={"snowcat": (14, 11)},
     props={(3, 2): "workbench", (8, 5): "crates", (20, 5): "container0", (8, 9): "container1", (20, 9): "crates"},
     fields={"set": "garage"})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 天線塔 廣場：岩壁圍起來的廠區 ＋ 兩棟小建築（北邊的塔基＝樓梯間、東邊的中繼機房）。
#   雪地車停在西南角；貨櫃、卡車、路障把廣場切成幾條通道，中間是輔助天線桅杆，南邊是油槽和瞭望台。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("tower_yard", """
##################################
##################################
#############.G..CC.H#############
#############........#############
#############.x....B.#############
#############........#############
################+#################
#................................#
#.C..CCCC.........CC..b.##########
#....CCCC..C......CC....#.N.C.M.##
#...1.....CCC...........+.......##
#.......................#.....A.##
#..CCC.......CCCC..C....#.CC...H##
#..CCC...a...CCCC.......##########
#................................#
#.......CC.......CCC....CC...2...#
#...Z...CC.......CCC;...CC.......#
#.....................3.......A..#
#.....4......CCC.................#
##################################
""",
     doors={},
     names={"Z": "snowcat_tower", "N": "note_relay"},
     stairs={"G": "tower_top"},
     entries={"stairs": (15, 3), "snowcat": (6, 16)},
     sets=[((13, 2, 8, 4), "utility"), ((25, 9, 7, 4), "comms")],
     props={(17, 15): "tank", (11, 9): "lamp_post", (18, 8): "antenna_mast", (19, 12): "lamp_post", (2, 8): "signpost",
            (8, 15): "watchtower", (5, 8): "container1", (13, 12): "truck", (3, 12): "crates", (24, 15): "crates",
            (10, 10): "barrier", (13, 18): "barrier"},
     fields={"indoor_rects": Raw("[Rect2i(13, 2, 8, 4), Rect2i(25, 9, 7, 4)]"), "zones": None})
AREAS["tower_yard"]["fields"]["zones"] = str(zone_all("yard", m, heated=False))

# ── 天線塔 通訊甲板：通訊室（上行終端機）、樓梯間、天線碟平台（主空間：碟型天線在中間）。
area("tower_top", """
##################################
#..U....N...##...................#
#...........##.x.............5.X.#
#.H.........##...................#
#...........##......CCCCCC.......#
#...........##..6...CCCCCC....x..#
#.....A.....##......CCCCCC.......#
######.#######......CCCCCC.......#
#..........................7.....#
######.#######...........x.......#
#...........##.........x.........#
#.G.........##.....8.............#
#.....B...H.##...................#
#...........##........x..........#
##################################
""",
     doors={},
     names={"U": "uplink", "N": "note_comms", "X": "dish_breaker"},
     stairs={"G": "tower_yard"},
     entries={"stairs": (3, 11)},
     sets=[((1, 1, 11, 6), "comms")],
     props={(20, 4): "dish"},
     fields={"set": "utility"})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 鑽探井 井口（26x19，4 個空間）。主空間 = 井口大廳：中間是灌滿融冰水的井（走不過去、看得過去），鑽機立在井中央，
#   四周一圈走道＝天然的環狀動線（鳴骨者繞著井巡）。南邊三間小的：泵房、控制室（有窗對著井）、往井底的樓梯間，
#   三間彼此相通。
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("drill_shaft", """
##########D###############
#...l....................#
#.CC..............H...CC.#
#........................#
#..C..~~~~~~~~~~~~~~..C..#
#.1...~~~~~~~~~~~~~~...2.#
#.....~~~~~CCC~~~~~~.....#
#..x..~~~~~CCC~~~~~~..b..#
#.....~~~~~CCC~~~~~~.....#
#.a...~~~~~~~~~~~~~~.....#
#..C..~~~~~~~~~~~~~~..C..#
#........................#
#....B...........x....A..#
####+####==####+##########
#.......#.....#..........#
#.CC....#..M..#.CC..3..L.#
#.CC..c.+.....+.CC.....G.#
#H......#.x...#........H.#
##########################
""",
     doors={"shaft": ((10, 0), "station_b1", (0, 1))},
     stairs={"G": "shaft_bottom"},
     entries={"stairs": (22, 16)},
     props={(11, 6): "drill_rig", (3, 4): "pillar", (22, 4): "pillar", (3, 10): "pillar", (22, 10): "pillar",
            (2, 15): "genset", (16, 15): "crates"},
     fields={"set": "utility", "zones": None})
AREAS["drill_shaft"]["fields"]["zones"] = str(zone_all("shaft", m, heated=False))

# ── 井底（最終 Boss：深井）：固定鏡頭的戰場，四根柱子擋共鳴脈衝。
area("shaft_bottom", """
##############################
#.G.......................J..#
#............................#
#....CC..............CC......#
#....CC..............CC......#
#............................#
#.........x.........x........#
#..............1.............#
#............................#
#.........x.........x........#
#............................#
#....CC..............CC......#
#....CC..............CC......#
#.H..A.......X.......L....H..#
#..........M.................#
##############################
""",
     doors={},
     names={"J": "shaft_lift", "X": "pit_breaker"},
     stairs={"G": "drill_shaft"},
     entries={"stairs": (3, 1)},
     fields={"set": "utility"})

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# 1962 年的燈籠監聽站（40x15，6 個空間）：佐藤的記憶。主空間 = 監聽大廳（三排監聽台對著北牆、中間的海圖桌、柱子）。
#   西：營房（起點）── 伙房        東：錄音帶室（目標：最後一捲帶子；隔著窗從大廳看得到）── 少校辦公室（窗對著大廳）
#   南：電纜廊道（後路：營房→伙房→廊道→辦公室→錄音帶室，不用穿過大廳）
# ═══════════════════════════════════════════════════════════════════════════════════════════════
m = area("lantern_1962", """
########################################
#CC...CC#..CC.N..CCCC..CC....#CCC...CCC#
#.......#....................=.........#
#......H#..CCCC..CCCC..CCCC..+....&....#
#.......+....................=..5......#
#CC...CC#..CCCC..CCCC..CCCC..#CC......H#
####+####......1.......2.....#####+#####
#CC...CC#..C....CCCC......C..#CC.....CC#
#.......#....................=...CCC..N#
#.CCC...+....................=....6....#
#M.x..N.#..C..............C..#.........#
####+#######+############+########+#####
#...3.....CC...........CCC.........4...#
#......................................#
########################################
""",
     doors={},
     names={"&": "reel_1962", "N#0": "lantern_log", "N#1": "major_order", "N#2": "sato_letter"},
     reels={"&": Raw('{"to": "station_b1", "entry": "reel", "scene": "lantern_signal", "flag": "memory:lantern", '
                     '"prompt": "Play the last reel"}')},
     entries={"start": (3, 2)},
     sets=[((1, 1, 7, 5), "barracks"), ((9, 1, 20, 10), "comms"), ((30, 1, 9, 5), "comms"), ((30, 7, 9, 4), "office"),
           ((1, 7, 7, 4), "mess")],
     props={(11, 3): "console_bank", (17, 3): "console_bank", (23, 3): "console_bank",
            (11, 5): "console_bank", (17, 5): "console_bank", (23, 5): "console_bank",
            (30, 1): "tape_reel_bank", (36, 1): "tape_reel_bank",
            (11, 7): "pillar", (26, 7): "pillar", (11, 10): "pillar", (26, 10): "pillar"},
     fields={"camera_zones": None, "zones": None})
AREAS["lantern_1962"]["fields"]["zones"] = str(zone_all("lantern", m, heated=True))


if __name__ == "__main__":
    snap = os.environ.get("MAP_SNAPSHOT", "")
    before = json.load(open(snap)) if snap and os.path.exists(snap) else {}
    for aid, m2 in MAPS.items():
        if len(sys.argv) > 1 and aid not in sys.argv[1:]:
            continue
        print(aid, "%dx%d" % (m2.w, m2.h))
        m2.show()
        if aid in before:
            now = {}
            for row in m2.rows():
                for ch in row:
                    if ch not in ".#C=+~ ":
                        now[ch] = now.get(ch, 0) + 1
            diff = {k: (before[aid].get(k, 0), now.get(k, 0)) for k in set(before[aid]) | set(now)
                    if before[aid].get(k, 0) != now.get(k, 0)}
            if diff:
                print("   符號數量和改之前不一樣（之前, 現在）：", diff)
