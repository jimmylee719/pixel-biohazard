# 產生 locale/zh_TW.po（Godot 直接讀 .po，不用另外匯入）。
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from zh_TW import T
root = os.path.join(os.path.dirname(__file__), "..", "..")
seen = set()
lines = ['msgid ""', 'msgstr ""', '"Content-Type: text/plain; charset=UTF-8\\n"', '"Language: zh_TW\\n"', '']
for en, zh in T:
    if en in seen:
        continue
    seen.add(en)
    # 英文原文已經是 GDScript 的跳脫寫法（\"），.po 用同樣的跳脫，所以原樣放進去
    lines.append('msgid "%s"' % en)
    lines.append('msgstr "%s"' % zh.replace('"', '\\"'))
    lines.append('')
open(os.path.join(root, "locale", "zh_TW.po"), "w", encoding="utf-8").write("\n".join(lines))
print("wrote %d entries" % len(seen))
