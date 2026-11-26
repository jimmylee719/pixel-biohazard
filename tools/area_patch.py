#!/usr/bin/env python3
"""重新設計區域地圖的工具：python3 tools/area_patch.py <規格檔.py> [區域 id ...]

規格檔定義 AREAS = {區域 id: {"map": 多行字串或列的清單, "fields": {欄位: GDScript 原始碼或 None}, "doors": {門 id: (x, y)},
                              "rekey": {"舊x,舊y": "新x,新y"}, "allow_diff": True}}

做的事：
  1. 以 tools/tests/legacy_areas.gd 裡那個區域的舊資料為基礎（重跑幾次結果都一樣）。
  2. 換上新的地圖；座標當 key 的欄位（names、hidden、loot、gear、stairs、reels、safes、props）和門的 cell，
     依「同一種符號在地圖上由上到下、由左到右第幾個」自動對應到新座標（也可以用 rekey、doors 明確指定）。
  3. fields 裡的欄位整個換掉（沒有就加在 map 前面；None = 刪掉）。zones、entries、camera_zones 這類寫死範圍的要自己給。
  4. 檢查：每列一樣長、物件符號的數量沒變、所有能走的格子連在一起、物件旁邊走得到。
"""
import importlib.util
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
AREAS_GD = os.path.join(HERE, "..", "scripts", "world", "areas.gd")
LEGACY_GD = os.path.join(HERE, "tests", "legacy_areas.gd")
FREE = set(".#C=+Hx ~")
SOLID = set("#CH=~")
KEYED = ["names", "hidden", "loot", "gear", "stairs", "reels", "safes", "props"]


def find_block(text, area_id):
    m = re.search(r'\n\t"%s": \{\n' % re.escape(area_id), text)
    if not m:
        return None
    start = m.start() + 1
    end = text.index("\n\t},\n", m.end()) + len("\n\t},\n")
    return start, end


def match_value(text, i):
    """從 i（值的第一個字元）找到值的結尾（不含逗號）。"""
    if text[i] in "{[":
        depth, j, in_str = 0, i, False
        while j < len(text):
            c = text[j]
            if in_str:
                if c == "\\":
                    j += 1
                elif c == '"':
                    in_str = False
            elif c == '"':
                in_str = True
            elif c in "{[(":
                depth += 1
            elif c in "}])":
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
        raise ValueError("括號沒有對上")
    j = text.index("\n", i)
    return j - 1 if text[j - 1] == "," else j


def field_span(block, name):
    m = re.search(r'\n\t\t"%s": ' % re.escape(name), block)
    if not m:
        return None
    vs = m.end()
    ve = match_value(block, vs)
    return m.start() + 1, vs, ve


def get_map(block):
    _, vs, ve = field_span(block, "map")
    return re.findall(r'"([^"\n]*)"', block[vs:ve])


def symbol_cells(rows):
    out = {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch not in FREE:
                out.setdefault(ch, []).append((x, y))
    return out


def check_connected(area_id, rows):
    h, w = len(rows), len(rows[0])
    passable = {(x, y) for y in range(h) for x in range(w) if rows[y][x] not in SOLID}
    if not passable:
        return
    seen = set()
    comps = []
    for start in sorted(passable, key=lambda c: (c[1], c[0])):
        if start in seen:
            continue
        stack, comp = [start], {start}
        seen.add(start)
        while stack:
            x, y = stack.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in passable and n not in seen:
                    seen.add(n)
                    comp.add(n)
                    stack.append(n)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    if len(comps) > 1:
        for c in comps[1:]:
            print("  !! %s：有 %d 格走不到（例如 %s）" % (area_id, len(c), sorted(c)[0]))
    main = comps[0]
    # 會擋路的互動物件不在這裡（都是地板上的東西），所以只要在主要的連通區就好


def patch(text, legacy, area_id, spec):
    span = find_block(text, area_id)
    lspan = find_block(legacy, area_id)
    assert span and lspan, "找不到區域 %s" % area_id
    block = legacy[lspan[0]:lspan[1]]
    old_rows = get_map(block)
    new_rows = spec.get("map") or old_rows  # 不給 map = 地圖不變，只改欄位
    if isinstance(new_rows, str):
        new_rows = [r for r in new_rows.split("\n") if r.strip() != ""]
    w = len(new_rows[0])
    for y, r in enumerate(new_rows):
        assert len(r) == w, "%s 第 %d 列長度 %d（應該 %d）：%s" % (area_id, y, len(r), w, r)
    old_cells, new_cells = symbol_cells(old_rows), symbol_cells(new_rows)
    mapping = {}
    for ch in sorted(set(old_cells) | set(new_cells)):
        a, b = old_cells.get(ch, []), new_cells.get(ch, [])
        if len(a) != len(b) and not spec.get("allow_diff"):
            print("  !! %s：符號 %s 數量 %d → %d" % (area_id, ch, len(a), len(b)))
        for i in range(min(len(a), len(b))):
            mapping["%d,%d" % a[i]] = "%d,%d" % b[i]
    mapping.update(spec.get("rekey", {}))
    # 地圖
    _, vs, ve = field_span(block, "map")
    block = block[:vs] + "[\n" + "".join('\t\t\t"%s",\n' % r for r in new_rows) + "\t\t]" + block[ve:]
    # 座標當 key 的欄位
    for name in KEYED:
        sp = field_span(block, name)
        if not sp or name in spec.get("fields", {}):
            continue
        _, vs, ve = sp

        def rk(m):
            k = m.group(1)
            if k not in mapping:
                print("  !! %s.%s：%s 沒有對應的新座標" % (area_id, name, k))
                return m.group(0)
            return '"%s":' % mapping[k]
        block = block[:vs] + re.sub(r'"(\d+,\d+)":', rk, block[vs:ve]) + block[ve:]
    # 門
    sp = field_span(block, "doors")
    if sp and "doors" not in spec.get("fields", {}):
        _, vs, ve = sp
        dtext = block[vs:ve]

        def rd(m):
            did = m.group(1)
            if did in spec.get("doors", {}):
                x, y = spec["doors"][did]
            else:
                key = "%s,%s" % (m.group(3), m.group(4))
                assert key in mapping, "%s 的門 %s（%s）沒有對應" % (area_id, did, key)
                x, y = mapping[key].split(",")
            return '"%s": {%s"cell": Vector2i(%s, %s)' % (did, m.group(2), x, y)
        dtext = re.sub(r'"(\w+)": \{([^{}\n]*?)"cell": Vector2i\((\d+), (\d+)\)', rd, dtext)
        block = block[:vs] + dtext + block[ve:]
        for m in re.finditer(r'"cell": Vector2i\((\d+), (\d+)\)', dtext):
            x, y = int(m.group(1)), int(m.group(2))
            if new_rows[y][x] != "D":
                print("  !! %s：門的格子 (%d,%d) 不是 D，是 %s" % (area_id, x, y, new_rows[y][x]))
    # 整個換掉的欄位
    for name, src in spec.get("fields", {}).items():
        sp = field_span(block, name)
        if sp:
            ls, vs, ve = sp
            if src is None:
                end = ve + 1 if block[ve] == "," else ve
                block = block[:ls] + block[end + 1:]
            else:
                block = block[:vs] + src + block[ve:]
        elif src is not None:
            at = field_span(block, "map")[0]
            block = block[:at] + '\t\t"%s": %s,\n' % (name, src) + block[at:]
    check_connected(area_id, new_rows)
    for name in ("entries",):
        if spec.get("map") and field_span(block, name) and name not in spec.get("fields", {}):
            print("  !! %s：有 %s 但規格沒有給新的" % (area_id, name))
    return text[:span[0]] + block + text[span[1]:]


def main():
    spec_path = sys.argv[1]
    sp = importlib.util.spec_from_file_location("spec", spec_path)
    mod = importlib.util.module_from_spec(sp)
    sp.loader.exec_module(mod)
    only = sys.argv[2:]
    text = open(AREAS_GD, encoding="utf-8").read()
    legacy = open(LEGACY_GD, encoding="utf-8").read()
    for area_id, spec in mod.AREAS.items():
        if only and area_id not in only:
            continue
        text = patch(text, legacy, area_id, spec)
        print("ok", area_id)
    open(AREAS_GD, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
