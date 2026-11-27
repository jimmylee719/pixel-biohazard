#!/usr/bin/env python3
"""把遊戲裡的劇情文字匯出成一份中英對照劇本：docs/SCRIPT.md。

用法：python3 tools/export_script.py
來源：scripts/world/{cutscenes,radio_calls,frequencies,endings,uplink_messages,codex,areas}.gd、
      scripts/autoload/missions.gd、scripts/main.gd（KOVAC_INTRO）；中文來自 tools/locale/zh_TW.py。
docs/SCRIPT.md 是產生出來的，不要手改：要改對白就改上面的來源檔，再跑一次這支程式。
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "locale"))
from zh_TW import T  # noqa: E402

ZH = dict(T)
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')


def read(rel):
    return open(os.path.join(ROOT, rel), encoding="utf-8").read().split("\n")


def show(raw):
    return raw.replace('\\"', '"').replace("\\\\", "\\")


def zh(raw):
    return show(ZH.get(raw, "（缺中文）"))


def pair(raw, indent=""):
    return "%s- %s\n%s  %s" % (indent, show(raw), indent, zh(raw))


def field(line, key):
    m = re.search(r'"%s": "((?:[^"\\]|\\.)*)"' % key, line)
    return m.group(1) if m else None


def cutscenes():
    out = ["## 1. 過場（依遊戲裡的順序）", ""]
    scene = None
    for line in read("scripts/world/cutscenes.gd"):
        m = re.match(r'^\t"([a-z_0-9]+)": \[', line)
        if m:
            scene = m.group(1)
            out += ["### `%s`" % scene, ""]
            continue
        if scene is None or not line.startswith("\t\t{"):
            continue
        if '"say"' in line:
            who = field(line, "say")
            if who is None:
                who = "Shen"
            text = field(line, "text")
            out.append("- **%s／%s**：%s\n  %s" % (show(who), zh(who), show(text), zh(text)))
        elif '"caption"' in line:
            c = field(line, "caption")
            out.append("- 〔地點字幕〕%s\n  %s" % (show(c), zh(c)))
        elif '"title_card"' in line:
            t, s = field(line, "title_card"), field(line, "sub")
            out.append("- 〔片名卡〕%s ／ %s\n  %s ／ %s" % (show(t), show(s), show(ZH.get(t, t)), zh(s)))
        elif '"name"' in line:
            n, r = field(line, "name"), field(line, "role")
            out.append("- 〔人物名牌〕%s — %s\n  %s — %s" % (show(n), show(r), zh(n), zh(r)))
        elif '"credit"' in line:
            c = field(line, "credit")
            out.append("- 〔片頭字幕〕%s\n  %s" % (show(c), zh(c)))
        elif '"era"' in line:
            e = field(line, "era")
            out.append("- 〔畫面〕%s" % ("回到現在" if e == "" else "切到 %s 年的色調" % e))
        elif '"fade_out"' in line:
            out.append("- 〔畫面〕切到黑")
        elif '"fade_in"' in line:
            out.append("- 〔畫面〕淡入")
        elif '"pan_enemy"' in line:
            out.append("- 〔鏡頭〕移到敵人身上")
        elif '"pan"' in line:
            out.append("- 〔鏡頭〕移到場景")
        elif '"flash"' in line:
            out.append("- 〔畫面〕白光一閃")
        elif '"sfx"' in line:
            out.append("- 〔音效〕%s" % field(line, "sfx"))
    out.append("")
    return out


def radio_calls():
    out = ["## 2. 無線電：柯瓦奇的主線通話", "",
           "第一次用無線電：", "", pair(const_string("scripts/main.gd", "KOVAC_INTRO")), ""]
    for line in read("scripts/world/radio_calls.gd"):
        m = re.search(r'\{"after": "([a-z_]+)"', line)
        if m:
            out += ["", "完成主線「%s」之後：" % m.group(1), ""]
        elif line.startswith("\t\t\"KOVAC"):
            out.append(pair(LIT.search(line).group(1)))
    out.append("")
    return out


def const_string(rel, name):
    for line in read(rel):
        if line.startswith("const %s" % name):
            return LIT.search(line).group(1)
    return ""


def frequencies():
    out = ["## 3. 無線電：可以調到的頻率", ""]
    freq = None
    for line in read("scripts/world/frequencies.gd"):
        m = re.search(r'"freq": (\d+).*"label": "([^"]+)"', line)
        if m:
            freq = int(m.group(1))
            out += ["", "### %d.%02d MHz — %s／%s" % (freq // 100, freq % 100, m.group(2), zh(m.group(2))), ""]
        elif freq and line.startswith("\t\t\t\""):
            out.append(pair(LIT.search(line).group(1)))
    out.append("")
    return out


def missions():
    out = ["## 4. 任務", ""]
    main = False
    for line in read("scripts/autoload/missions.gd"):
        if '"id":' in line:
            main = '"main": true' in line
        t = field(line, "title")
        if t and line.startswith("\t\t\"title\""):
            out += ["", "### %s%s／%s" % ("【主線】" if main else "【支線】", show(t), zh(t)), ""]
        for key in ("desc", "radio"):
            v = field(line, key)
            if v and line.startswith("\t\t\"%s\"" % key):
                out.append(pair(v))
    out.append("")
    return out


def documents():
    out = ["## 5. 文件、錄音帶、筆記（依區域）", ""]
    title, inside = "", False
    for line in read("scripts/world/areas.gd"):
        t = field(line, "title")
        if t and line.startswith("\t\t\"title\""):
            title = t
        if re.match(r'^\t\t"messages": \{\s*$', line):
            inside = True
            out += ["", "### %s／%s" % (show(title), zh(title)), ""]
            continue
        if inside:
            if re.match(r"^\t\t\},?\s*$", line):
                inside = False
                continue
            m = re.match(r'^\t\t\t"[a-z_0-9]+": "((?:[^"\\]|\\.)*)"', line)
            if m:
                out.append(pair(m.group(1)))
    out.append("")
    return out


def uplink_and_endings():
    out = ["## 6. 天線塔的訊息與回覆", ""]
    for line in read("scripts/world/uplink_messages.gd"):
        if line.startswith("\t\t\"label\"") or line.startswith("\t\t\"sent\"") or line.startswith("\t\t\"reply\"") \
                or (line.startswith("\t\"") and not line.startswith("\t\"\"")):
            m = LIT.findall(line)
            raw = m[-1] if line.startswith("\t\t") else m[0]
            out.append(pair(raw))
    out += ["", "## 7. 結局", ""]
    for line in read("scripts/world/endings.gd"):
        t = field(line, "title")
        if t:
            out += ["", "### %s／%s" % (show(t), zh(t)), ""]
        elif line.startswith("\t\t\t\""):
            out.append(pair(LIT.search(line).group(1)))
        elif line.startswith("const INFECTED_LINE"):
            out += ["", "（已感染時「最後的光」的第一句）", "", pair(LIT.search(line).group(1))]
    out.append("")
    return out


def codex():
    out = ["## 8. 圖鑑", ""]
    for line in read("scripts/world/codex.gd"):
        n = field(line, "name")
        if n and '"group"' in line:
            out += ["", "**%s／%s**" % (show(n), zh(n)), ""]
        d = field(line, "desc")
        if d:
            out.append(pair(d))
    out.append("")
    return out


def main():
    out = ["# AFTERSIGNAL《迴頻》本篇劇本（中英對照）", "",
           "> 這份檔案由 `python3 tools/export_script.py` 從遊戲資料產生，**不要手改**。",
           "> 設定與角色的說話方式見 `docs/SERIES_BIBLE.md`。", ""]
    for part in (cutscenes, radio_calls, frequencies, missions, documents, uplink_and_endings, codex):
        out += part()
    text = "\n".join(out)
    open(os.path.join(ROOT, "docs", "SCRIPT.md"), "w", encoding="utf-8").write(text)
    print("wrote docs/SCRIPT.md: %d lines, 缺中文 %d 處" % (text.count("\n") + 1, text.count("（缺中文）")))


if __name__ == "__main__":
    main()
