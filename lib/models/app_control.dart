import 'package:cloud_firestore/cloud_firestore.dart';

class LaunchMessage {
  const LaunchMessage({
    required this.id,
    required this.title,
    required this.body,
    this.active = false,
    this.everyLaunch = true,
  });
  final String id;
  final String title;
  final String body;
  final bool active;
  final bool everyLaunch;

  factory LaunchMessage.fromMap(Map<String, dynamic> data) => LaunchMessage(
    id: data['id'] as String? ?? '',
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    active: data['active'] == true,
    everyLaunch: data['everyLaunch'] != false,
  );
  bool get visible =>
      active && id.isNotEmpty && title.isNotEmpty && body.isNotEmpty;
}

class AppControl {
  const AppControl({this.maintenance = false, this.message = ''});
  final bool maintenance;
  final String message;
  factory AppControl.fromMap(Map<String, dynamic> data) => AppControl(
    maintenance: data['maintenance'] == true,
    message: data['message'] as String? ?? '',
  );
}

class UserAccess {
  const UserAccess({this.status = 'active', this.reason = ''});
  final String status;
  final String reason;
  bool get blocked => status != 'active';
  factory UserAccess.fromMap(Map<String, dynamic> data) => UserAccess(
    status: data['status'] as String? ?? 'active',
    reason: data['reason'] as String? ?? '',
  );
}

class AdminUser {
  const AdminUser(this.uid, this.data);
  final String uid;
  final Map<String, dynamic> data;
  String get username => data['username'] as String? ?? '';
  String get email => data['email'] as String? ?? '';
  String get name => data['displayName'] as String? ?? username;
  factory AdminUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AdminUser(doc.id, doc.data() ?? {});
}
