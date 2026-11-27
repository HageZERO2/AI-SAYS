"""План запекания: слова из words.txt, которых ещё нет в WordBank.luau → ключи w041… и пакеты по PACK слов.
Пишет out/plan.json: [{"pack": "p01", "words": [["w041", "слово"], ...]}, ...]. Повторный запуск даёт тот же план.
Запуск: python tools/bake/plan.py"""

import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
BANK = os.path.join(HERE, "..", "..", "src", "server", "WordBank.luau")
PACK = 20
TARGET = 500  # размер банка; лишние слова из words.txt подождут следующего раза
MAX_LEN = 20  # Config.MaxWordLength

bank_text = open(BANK, encoding="utf-8").read()
bank = set(re.findall(r'\["([^"]+)"\]', bank_text))
used_keys = [int(k) for k in re.findall(r"w(\d+)", bank_text)]
next_key = max(used_keys) + 1

words, seen, bad = [], set(), []
for line in open(os.path.join(HERE, "words.txt"), encoding="utf-8"):
    w = line.strip()
    if not w or w.startswith("#"):
        continue
    # то же, что RoundLogic.cleanWord: строчные, 2..20 символов, без цифр/разметки
    if w != w.lower() or not 2 <= len(w) <= MAX_LEN or re.search(r'[\d<>{}"\\]', w):
        bad.append(w)
        continue
    if w in bank or w in seen:
        continue
    seen.add(w)
    words.append(w)

words = words[: max(0, TARGET - len(bank))]
packs = []
for i in range(0, len(words), PACK):
    chunk = words[i : i + PACK]
    packs.append(
        {
            "pack": f"p{len(packs) + 1:02d}",
            "words": [[f"w{next_key + i + j:03d}", w] for j, w in enumerate(chunk)],
        }
    )
os.makedirs(os.path.join(HERE, "out"), exist_ok=True)
with open(os.path.join(HERE, "out", "plan.json"), "w", encoding="utf-8") as f:
    json.dump(packs, f, ensure_ascii=False, indent=1)
print(f"bank {len(bank)}, new {len(words)}, total {len(bank) + len(words)}, packs {len(packs)}, bad {bad}")
