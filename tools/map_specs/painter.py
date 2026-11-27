"""畫地圖的小工具（給 tools/map_specs/*.py 用）：先全部是牆，再挖房間、畫牆、放東西。"""


class Map:
    def __init__(self, w, h, fill="#"):
        self.w, self.h = w, h
        self.g = [[fill] * w for _ in range(h)]

    def room(self, x, y, w, h, ch="."):
        """挖一塊地板（x, y = 左上角）。"""
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.g[yy][xx] = ch
        return self

    def wall(self, x0, y0, x1, y1, ch="#"):
        """畫一條牆（含兩端）。"""
        for yy in range(min(y0, y1), max(y0, y1) + 1):
            for xx in range(min(x0, x1), max(x0, x1) + 1):
                self.g[yy][xx] = ch
        return self

    def box(self, x, y, w, h):
        """畫一圈牆（外框 x, y, w, h），裡面變地板。"""
        self.wall(x, y, x + w - 1, y)
        self.wall(x, y + h - 1, x + w - 1, y + h - 1)
        self.wall(x, y, x, y + h - 1)
        self.wall(x + w - 1, y, x + w - 1, y + h - 1)
        self.room(x + 1, y + 1, w - 2, h - 2)
        return self

    def put(self, x, y, s):
        for i, ch in enumerate(s):
            if ch != " ":
                self.g[y][x + i] = ch
        return self

    def col(self, x, y, s):
        for i, ch in enumerate(s):
            if ch != " ":
                self.g[y + i][x] = ch
        return self

    def block(self, x, y, w, h, ch="C"):
        return self.room(x, y, w, h, ch)

    # ── 以下是 redesign_a.py 用的小工具 ──
    @classmethod
    def parse(cls, text):
        """把一張直接畫好的文字地圖（多行字串）變成 Map；每列一樣長才收。"""
        rows = [r for r in text.split("\n") if r.strip() != ""]
        for y, r in enumerate(rows):
            assert len(r) == len(rows[0]), "第 %d 列長度 %d（應該 %d）：%s" % (y, len(r), len(rows[0]), r)
        m = cls(len(rows[0]), len(rows))
        m.g = [list(r) for r in rows]
        return m

    def find(self, ch, n=0):
        """第 n 個（由上到下、由左到右）ch 的座標。"""
        i = 0
        for y, row in enumerate(self.g):
            for x, c in enumerate(row):
                if c == ch:
                    if i == n:
                        return (x, y)
                    i += 1
        raise KeyError("地圖上沒有第 %d 個 %s" % (n, ch))

    def count(self, ch):
        return sum(row.count(ch) for row in self.g)

    def rects(self, ch="C"):
        """和 Level._merge_rects 一樣的合併規則：回傳 [(x, y, w, h)]，用來確認大型物件的那一塊大小對不對。"""
        result, open_ = [], {}
        for y, row in enumerate(self.g):
            runs, x = [], 0
            while x < self.w:
                if row[x] == ch:
                    s = x
                    while x < self.w and row[x] == ch:
                        x += 1
                    runs.append((s, x))
                else:
                    x += 1
            nxt = {}
            for run in runs:
                if run in open_:
                    i = open_[run]
                    result[i][3] += 1
                    nxt[run] = i
                else:
                    result.append([run[0], y, run[1] - run[0], 1])
                    nxt[run] = len(result) - 1
            open_ = nxt
        return [tuple(r) for r in result]

    def rows(self):
        return ["".join(r) for r in self.g]

    def show(self):
        print("     " + "".join(str(i // 10) if i % 10 == 0 else " " for i in range(self.w)))
        print("     " + "".join(str(i % 10) for i in range(self.w)))
        for y, r in enumerate(self.rows()):
            print("%3d  %s" % (y, r))


def legacy_map(area_id):
    """舊版（tools/tests/legacy_areas.gd）的地圖，變成 Map：只想在原本的地圖上多放幾樣東西時用。"""
    import os
    import re
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tests", "legacy_areas.gd")
    text = open(path, encoding="utf-8").read()
    start = text.index('\n\t"%s": {\n' % area_id)
    at = text.index('\t\t"map": [', start)
    rows = re.findall(r'"([^"\n]*)"', text[at + 9:text.index("\n\t\t]", at)])
    m = Map(len(rows[0]), len(rows))
    m.g = [list(r) for r in rows]
    return m
