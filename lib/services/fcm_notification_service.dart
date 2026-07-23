import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FcmNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initAfterLogin(User user) async {
    await _fcm.requestPermission();

    final token = await _fcm.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
