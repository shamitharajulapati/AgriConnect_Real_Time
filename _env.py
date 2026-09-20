"""Loads .env into os.environ if present — no external dependency needed.
Imported by the root-level admin scripts before they read os.environ[...].
"""
import os


def load():
    path = os.path.join(os.path.dirname(__file__), '.env')
    if not os.path.exists(path):
        return
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, _, value = line.partition('=')
            os.environ.setdefault(key.strip(), value.strip())


load()
