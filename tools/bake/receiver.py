"""Принимает от Studio (POST /<name>) данные слова и пишет их в out/<name>.
Запуск: python tools/bake/receiver.py  (порт 34900, только localhost)."""

import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        name = self.path.strip("/")
        # только безопасные имена файлов: латиница/цифры/._-
        if not re.fullmatch(r"[A-Za-z0-9._-]{1,80}", name):
            self.send_response(400)
            self.end_headers()
            return
        body = self.rfile.read(int(self.headers["Content-Length"]))
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(body)
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


HTTPServer(("127.0.0.1", 34900), Handler).serve_forever()
