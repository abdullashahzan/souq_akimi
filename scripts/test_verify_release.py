import tempfile
import unittest
from pathlib import Path
import zipfile

from verify_release import verify


class ReleaseArtifactSafetyTest(unittest.TestCase):
    def artifact(self, filename, payload):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name)/'app.apk'
        with zipfile.ZipFile(path,'w') as archive:
            archive.writestr(filename,payload)
        return path

    def test_clean_payload(self):
        verify(self.artifact('lib/arm64-v8a/libapp.so',b'ordinary content'))

    def test_groq_key_is_rejected(self):
        with self.assertRaises(AssertionError):
            verify(self.artifact('lib/arm64-v8a/libapp.so',b'gsk_'+b'x'*32))

    def test_private_key_is_rejected(self):
        with self.assertRaises(AssertionError):
            verify(self.artifact('assets/config',b'-----BEGIN PRIVATE KEY-----'))

    def test_demo_and_signing_assets_are_rejected(self):
        for name in ['assets/flutter_assets/assets/images/demo/a.jpg','assets/dart_defines.json','keys/private.jks']:
            with self.subTest(name=name), self.assertRaises(AssertionError):
                verify(self.artifact(name,b'content'))
