import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/plant.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _subscription;

  /// Запуск live-синхронизации (Web + Mobile)
  void startLiveSync() {
    final user = _auth.currentUser;
    if (user == null) return;

    _subscription?.cancel();

    _subscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .snapshots()
        .listen((snapshot) async {
          final prefs = await SharedPreferences.getInstance();

          final plants = snapshot.docs
              .map((doc) => Plant.fromJson(doc.data()))
              .toList();

          await prefs.setStringList(
            'plants',
            plants.map((p) => jsonEncode(p.toJson())).toList(),
          );

          print('🔁 Live sync: ${plants.length} растений');
        });
  }

  /// Остановка синхронизации (при logout)
  void stopLiveSync() {
    _subscription?.cancel();
    _subscription = null;
  }
}
