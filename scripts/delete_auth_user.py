#!/usr/bin/env python3
"""Trusted, preview-first Auth cleanup AFTER in-app marketplace removal.

Never run in Flutter or ship ADC/service-account credentials in an APK.
Requires firebase-admin and operator-owned Application Default Credentials.
"""
import argparse
import os

ADMIN_UID = 'srXNKWjiXBbza3JTfg4CAaHN4vx1'
ADMIN_EMAIL = 'abdullashahzan@gmail.com'


def validate_target(uid, email=''):
    if not uid or '/' in uid or uid == ADMIN_UID or email.lower() == ADMIN_EMAIL:
        raise ValueError('Refusing to delete the protected administrator or an invalid UID.')


def cleanup_ready(db, uid):
    access = db.document(f'userAccess/{uid}').get().to_dict() or {}
    if access.get('status') != 'deleted':
        raise ValueError('Remove the user from the marketplace first; a deletion tombstone is required.')
    if db.document(f'users/{uid}').get().exists:
        raise ValueError('Marketplace profile cleanup is incomplete. Retry removal in Admin → Users.')
    if db.document(f'publicProfiles/{uid}').get().exists:
        raise ValueError('Public profile cleanup is incomplete. Retry removal in Admin → Users.')
    from google.cloud.firestore_v1.base_query import FieldFilter
    for collection, field in [('products', 'sellerId'), ('services', 'providerId'), ('images', 'ownerId')]:
        if list(db.collection(collection).where(filter=FieldFilter(field, '==', uid)).limit(1).stream()):
            raise ValueError('Marketplace content cleanup is incomplete. Retry removal in Admin → Users.')
    if list(db.collection(f'users/{uid}/notifications').limit(1).stream()):
        raise ValueError('Inbox cleanup is incomplete. Retry removal in Admin → Users.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    parser.add_argument('--uid', required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--confirm-uid')
    args = parser.parse_args()
    validate_target(args.uid)
    if args.apply and args.confirm_uid != args.uid:
        parser.error('--apply requires --confirm-uid matching the exact target UID')
    if os.environ.get('FIREBASE_AUTH_EMULATOR_HOST') or os.environ.get('FIRESTORE_EMULATOR_HOST'):
        parser.error('Unset emulator variables before using this production cleanup tool.')
    import firebase_admin
    from firebase_admin import auth, firestore
    app = firebase_admin.initialize_app(options={'projectId': args.project})
    db = firestore.client(app)
    cleanup_ready(db, args.uid)
    try:
        user = auth.get_user(args.uid, app=app)
    except auth.UserNotFoundError:
        print('Login account is already absent. Marketplace tombstone and history retained.')
        return
    validate_target(user.uid, user.email or '')
    print(f'Project: {args.project}; target UID: {user.uid}. Order/request history is retained.')
    if not args.apply:
        print('Preview only. No writes. Add --apply --confirm-uid <UID> after reviewing the target.')
        return
    # The retained tombstone already blocks old tokens from marketplace writes.
    auth.revoke_refresh_tokens(user.uid, app=app)
    auth.delete_user(user.uid, app=app)
    db.collection('adminAudit').add({'action': 'auth.delete', 'targetId': user.uid,
        'actorId': 'trusted-iam-operator', 'createdAt': firestore.SERVER_TIMESTAMP})
    print('Firebase login account deleted. Tombstone retained to block stale credentials.')


if __name__ == '__main__':
    main()
