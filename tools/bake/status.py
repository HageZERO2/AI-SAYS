"""Что из out/plan.json уже выгружено из Studio. Слово готово, когда есть pos/nrm/uv и вся текстура
(RGBA сторона² байт, куски по 512 КБ до base64).
Запуск: python tools/bake/status.py [N]  — печатает готовые пакеты и следующие N заданий для BakeTool."""

import base64
import json
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


def complete(key: str) -> bool:
    for name in ("pos", "nrm", "uv"):
        if not os.path.exists(os.path.join(OUT, f"{key}.{name}.0")):
            return False
    size, i = 0, 0
    while os.path.exists(part := os.path.join(OUT, f"{key}.tex.{i}")):
        size += len(base64.b64decode(open(part, "rb").read()))
        i += 1
    side = int((size // 4) ** 0.5)
    return size > 0 and side * side * 4 == size


plan = json.load(open(os.path.join(OUT, "plan.json"), encoding="utf-8"))
todo, ready = [], []
for p in plan:
    missing = [w for w in p["words"] if not complete(w[0])]
    if missing:
        todo += missing
    else:
        ready.append(p["pack"])
n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
print("ready packs:", " ".join(ready) or "-")
print("left:", len(todo))
print("{ " + ", ".join('{"%s","%s"}' % (w, k) for k, w in todo[:n]) + " }")
