#!/usr/bin/env python3
"""Build-only download of checksum-locked report assets; never used at runtime."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import time
import urllib.request

manifest, root = map(Path, sys.argv[1:])
root.mkdir(parents=True, exist_ok=False)
for asset in json.loads(manifest.read_text()):
    for attempt in range(3):
        try:
            with urllib.request.urlopen(asset['download'], timeout=90) as source:
                data = source.read()
            if hashlib.sha256(data).hexdigest() != asset['sha256']:
                raise ValueError('asset checksum mismatch: ' + asset['file'])
            (root / asset['file']).write_bytes(data)
            break
        except ValueError:
            raise
        except OSError:
            if attempt == 2:
                raise
            time.sleep(2)
shutil.copyfile(manifest, root / 'assets.json')
