#!/usr/bin/env python3
"""Fail closed if a public APK includes secret credentials or demo assets."""
import hashlib
from pathlib import Path
import re
import sys
import zipfile

def verify(path):
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            if item.is_dir():
                continue
            assert not any(part in item.filename.lower() for part in ['demo_catalogue', '/images/demo/', 'dart_defines', '.jks', 'service-account']), f'Forbidden asset: {item.filename}'
            data = archive.read(item)
            assert not re.search(rb'gsk_[A-Za-z0-9]{20,}', data), f'Groq credential in {item.filename}'
            assert b'-----BEGIN PRIVATE KEY-----' not in data, f'Private key in {item.filename}'
    print('Public artifact scan passed; SHA-256:', hashlib.sha256(Path(path).read_bytes()).hexdigest())

if __name__ == '__main__':
    verify(sys.argv[1])
