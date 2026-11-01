import unittest
from delete_auth_user import ADMIN_EMAIL, ADMIN_UID, validate_target


class DeleteAuthSafetyTest(unittest.TestCase):
    def test_protected_uid_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_target(ADMIN_UID)

    def test_protected_email_is_rejected(self):
        with self.assertRaises(ValueError):
            validate_target('different-uid', ADMIN_EMAIL.upper())

    def test_invalid_uid_is_rejected(self):
        for uid in ['', 'a/b']:
            with self.assertRaises(ValueError):
                validate_target(uid)

    def test_normal_target_is_allowed(self):
        validate_target('test-user', 'test@example.com')
