"""Пересобирает src/server/WordBank.luau: одиночные слова (число) остаются как есть, слова из загруженных пакетов
(out/packs.txt: «p01 <assetId>» по строке + out/plan.json) пишутся как { pack = assetId, part = "w041" }.
Запуск: python tools/bake/bank.py"""

import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
BANK = os.path.join(HERE, "..", "..", "src", "server", "WordBank.luau")
OUT = os.path.join(HERE, "out")

text = open(BANK, encoding="utf-8").read()
singles = re.findall(r'\["([^"]+)"\] = (\d+), -- (w\d+)', text)
uploaded = dict(line.split() for line in open(os.path.join(OUT, "packs.txt"), encoding="utf-8") if line.strip())
plan = json.load(open(os.path.join(OUT, "plan.json"), encoding="utf-8"))

lines = [f'\t["{w}"] = {a}, -- {k}' for w, a, k in singles]
for p in plan:
    asset = uploaded.get(p["pack"])
    if asset:
        lines.append(f"\t-- пакет {p['pack']}")
        lines += [f'\t["{w}"] = {{ pack = {asset}, part = "{k}" }},' for k, w in p["words"]]

out = (
    "--!strict\n"
    "-- Заранее запечённые 3D-модели слов: слово (как после RoundLogic.cleanWord) → ассет.\n"
    "--   число — модель из одного слова; { pack, part } — пакет из многих слов, part — имя MeshPart внутри.\n"
    "-- Делает tools/bake (см. tools/bake/README.md). Ассеты на аккаунте владельца игры — иначе LoadAsset не загрузит.\n"
    "-- w31…w40 — ещё и реквизит арен (Services/Arena, prop).\n\n"
    "export type Entry = number | { pack: number, part: string }\n\n"
    "return {\n" + "\n".join(lines) + "\n} :: { [string]: Entry }\n"
)
open(BANK, "w", encoding="utf-8", newline="").write(out)
print(f"singles {len(singles)}, packs {sum(1 for p in plan if p['pack'] in uploaded)}, words {len(lines) - sum(1 for l in lines if l.startswith(chr(9) + '--'))}")
