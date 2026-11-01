#!/usr/bin/env python3
"""Build a key-free Android release with an external, persistent signing key."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

def main():
    credentials = Path(os.environ.get('SOUQ_SIGNING_CONFIG', Path.home()/'.config/souq-akimi/release/signing.json'))
    if not credentials.is_file():
        sys.exit('Missing private signing configuration. See docs/releases.md. Never use the debug key for releases.')
    data = json.loads(credentials.read_text())
    env = dict(os.environ)
    for suffix, key in [('STORE_FILE','storeFile'), ('STORE_PASSWORD','storePassword'), ('KEY_ALIAS','keyAlias'), ('KEY_PASSWORD','keyPassword')]:
        if not data.get(key):
            sys.exit('Incomplete signing configuration.')
        env['SOUQ_SIGNING_'+suffix] = data[key]
    # No dart_defines.json: public releases must not contain a Groq credential.
    subprocess.run(['flutter', 'build', 'apk', '--release'], cwd=ROOT, env=env, check=True)
    subprocess.run([sys.executable, 'scripts/verify_release.py', 'build/app/outputs/flutter-apk/app-release.apk'], cwd=ROOT, env=env, check=True)

if __name__ == '__main__':
    main()
