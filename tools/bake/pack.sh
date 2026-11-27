#!/bin/sh
# Собрать пакет по имени из out/plan.json: sh pack.sh p02
keys=$(python -c "import json,sys;print(' '.join(w[0] for p in json.load(open('out/plan.json',encoding='utf-8')) if p['pack']==sys.argv[1] for w in p['words']))" "$1")
python build_glb.py --pack "$1" $keys
