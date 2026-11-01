import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/app_control.dart';

class AppControlRepository {
  AppControlRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;
  Stream<AppControl> watchControl() => _db
      .doc('appConfig/control')
      .snapshots()
      .map((doc) => AppControl.fromMap(doc.data() ?? {}));
  Stream<LaunchMessage> watchMessage() => _db
      .doc('appConfig/launchMessage')
      .snapshots()
      .map((doc) => LaunchMessage.fromMap(doc.data() ?? {}));
  Stream<UserAccess> watchAccess(String uid) => _db
      .doc('userAccess/$uid')
      .snapshots()
      .map((doc) => UserAccess.fromMap(doc.data() ?? {}));
}
