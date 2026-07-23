import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  static Future<void> setup() async {
    final messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    print('FCM Token: $token');
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Пользователь не авторизован. Пропускаем регистрацию токена.');
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
