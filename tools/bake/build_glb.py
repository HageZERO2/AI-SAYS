"""Собирает out/<key>.glb из потоков out/<key>.<pos|nrm|uv|tex>.<N> (base64 кусками, см. bake_word.luau).
Запуск: python tools/bake/build_glb.py <key> [<key> ...]  |  --pack <name> <key> [<key> ...]"""

import base64
import io
import json
import os
import struct
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")


def pad4(b: bytes, fill: bytes = b"\0") -> bytes:
    return b + fill * (-len(b) % 4)


def stream(key: str, name: str) -> bytes:
    data, i = b"", 0
    while os.path.exists(part := os.path.join(OUT, f"{key}.{name}.{i}")):
        with open(part, "rb") as f:
            data += base64.b64decode(f.read())
        i += 1
    assert data, f"no {key}.{name}.*"
    return data


def word_buffers(key: str) -> tuple[list[bytes], int, list[float], list[float], int]:
    """Буферы одного слова: [pos, nrm, uv, png], число углов, min/max позиций, сторона текстуры."""
    pos, nrm, uv, rgba = (stream(key, name) for name in ("pos", "nrm", "uv", "tex"))
    side = int((len(rgba) // 4) ** 0.5)
    assert side * side * 4 == len(rgba), "texture is not square RGBA"
    png = io.BytesIO()
    # генератор отдаёт 1024², для объекта в игре хватает 512² (у EditableImage нет Resize)
    img = Image.frombytes("RGBA", (side, side), rgba).convert("RGB")
    img.resize((min(side, 512),) * 2, Image.LANCZOS).save(png, "PNG")
    side = min(side, 512)

    pos = list(struct.unpack(f"<{len(pos) // 4}f", pos))
    nrm = list(struct.unpack(f"<{len(nrm) // 4}f", nrm))
    # Импорт Roblox поворачивает glTF на 180° вокруг Y (forward +Z → −Z): заранее поворачиваем обратно,
    # иначе загруженная модель смотрит назад (проверено на «акулы»). Поворот, не зеркало — обход треугольников тот же.
    for arr in (pos, nrm):
        arr[0::3] = [-v for v in arr[0::3]]
        arr[2::3] = [-v for v in arr[2::3]]
    n = len(pos) // 3
    assert n % 3 == 0 and len(uv) == n * 8 and len(nrm) == n * 3, "corner arrays mismatch"
    xs, ys, zs = pos[0::3], pos[1::3], pos[2::3]
    bufs = [struct.pack(f"<{len(pos)}f", *pos), struct.pack(f"<{len(nrm)}f", *nrm), uv, png.getvalue()]
    return bufs, n, [min(xs), min(ys), min(zs)], [max(xs), max(ys), max(zs)], side


def build(name: str, keys: list[str]) -> str:
    """out/<name>.glb: по мешу, узлу, материалу и текстуре на каждый ключ; имя узла и меша = ключ
    (импорт Roblox делает из узла MeshPart с этим именем — по нему игра находит слово в пакете)."""
    views, blob = [], b""
    gltf = {
        "asset": {"version": "2.0", "generator": "ai-says bake"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(keys)))}],
        "nodes": [],
        "meshes": [],
        "materials": [],
        "textures": [],
        "images": [],
        "accessors": [],
        "bufferViews": views,
    }
    tris = 0
    for i, key in enumerate(keys):
        bufs, n, lo, hi, _ = word_buffers(key)
        tris += n // 3
        for data in bufs:
            views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
            blob = pad4(blob + data)
        v, a = 4 * i, 3 * i
        gltf["accessors"] += [
            {"bufferView": v, "componentType": 5126, "count": n, "type": "VEC3", "min": lo, "max": hi},
            {"bufferView": v + 1, "componentType": 5126, "count": n, "type": "VEC3"},
            {"bufferView": v + 2, "componentType": 5126, "count": n, "type": "VEC2"},
        ]
        gltf["images"].append({"bufferView": v + 3, "mimeType": "image/png"})
        gltf["textures"].append({"source": i})
        gltf["materials"].append(
            {"name": key, "pbrMetallicRoughness": {"baseColorTexture": {"index": i}, "metallicFactor": 0}}
        )
        gltf["meshes"].append(
            {"name": key, "primitives": [{"attributes": {"POSITION": a, "NORMAL": a + 1, "TEXCOORD_0": a + 2}, "material": i}]}
        )
        gltf["nodes"].append({"mesh": i, "name": key})
    gltf["buffers"] = [{"byteLength": len(blob)}]
    js = pad4(json.dumps(gltf).encode(), b" ")
    glb = (
        struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
        + struct.pack("<II", len(js), 0x4E4F534A)
        + js
        + struct.pack("<II", len(blob), 0x004E4942)
        + blob
    )
    path = os.path.join(OUT, name + ".glb")
    with open(path, "wb") as f:
        f.write(glb)
    return f"{path} {len(keys)} words {tris} tris {len(glb) // 1024} KB"


# python build_glb.py w01 w02            — по файлу на слово
# python build_glb.py --pack p01 w041 …  — один файл-пакет на несколько слов
args = sys.argv[1:]
if args[:1] == ["--pack"]:
    print(build(args[1], args[2:]))
else:
    for k in args:
        print(build(k, [k]))
