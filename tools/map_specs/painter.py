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
