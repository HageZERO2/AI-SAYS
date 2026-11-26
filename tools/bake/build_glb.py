"""Собирает out/<key>.glb из потоков out/<key>.<pos|nrm|uv|tex>.<N> (base64 кусками, см. bake_word.luau).
Запуск: python tools/bake/build_glb.py <key> [<key> ...]"""

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


def build(key: str) -> str:
    pos, nrm, uv, rgba = (stream(key, name) for name in ("pos", "nrm", "uv", "tex"))
    side = int((len(rgba) // 4) ** 0.5)
    assert side * side * 4 == len(rgba), "texture is not square RGBA"
    png = io.BytesIO()
    # генератор отдаёт 1024², для объекта в игре хватает 512² (у EditableImage нет Resize)
    img = Image.frombytes("RGBA", (side, side), rgba).convert("RGB")
    img.resize((min(side, 512),) * 2, Image.LANCZOS).save(png, "PNG")
    side = min(side, 512)
    png = png.getvalue()

    pos = list(struct.unpack(f"<{len(pos) // 4}f", pos))
    nrm = list(struct.unpack(f"<{len(nrm) // 4}f", nrm))
    # Импорт Roblox поворачивает glTF на 180° вокруг Y (forward +Z → −Z): заранее поворачиваем обратно,
    # иначе загруженная модель смотрит назад (проверено на «акулы»). Поворот, не зеркало — обход треугольников тот же.
    for arr in (pos, nrm):
        arr[0::3] = [-v for v in arr[0::3]]
        arr[2::3] = [-v for v in arr[2::3]]
    n = len(pos) // 3
    assert n % 3 == 0 and len(uv) == n * 8 and len(nrm) == n * 3, "corner arrays mismatch"
    bpos = struct.pack(f"<{len(pos)}f", *pos)
    bnrm = struct.pack(f"<{len(nrm)}f", *nrm)
    buv = uv
    views, blob = [], b""
    for data in (bpos, bnrm, buv, png):
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        blob = pad4(blob + data)
    xs, ys, zs = pos[0::3], pos[1::3], pos[2::3]
    gltf = {
        "asset": {"version": "2.0", "generator": "ai-says bake"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": key}],
        "meshes": [
            {
                "name": key,
                "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "material": 0}],
            }
        ],
        "materials": [
            {"name": key, "pbrMetallicRoughness": {"baseColorTexture": {"index": 0}, "metallicFactor": 0}}
        ],
        "textures": [{"source": 0}],
        "images": [{"bufferView": 3, "mimeType": "image/png"}],
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": n,
                "type": "VEC3",
                "min": [min(xs), min(ys), min(zs)],
                "max": [max(xs), max(ys), max(zs)],
            },
            {"bufferView": 1, "componentType": 5126, "count": n, "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": n, "type": "VEC2"},
        ],
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    js = pad4(json.dumps(gltf).encode(), b" ")
    glb = (
        struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(blob))
        + struct.pack("<II", len(js), 0x4E4F534A)
        + js
        + struct.pack("<II", len(blob), 0x004E4942)
        + blob
    )
    path = os.path.join(OUT, key + ".glb")
    with open(path, "wb") as f:
        f.write(glb)
    return f"{path} {n // 3} tris {side}px {len(glb) // 1024} KB"


for k in sys.argv[1:]:
    print(build(k))
