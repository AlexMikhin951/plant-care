import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'notification_service.dart';

class ToastNotificationService {
  final NotificationService _notificationService = NotificationService();

  /// Инициализация внутреннего NotificationService
  Future<void> init() async {
    await _notificationService.init();
  }

  void _showToast(
    String message, {
    ToastGravity gravity = ToastGravity.BOTTOM,
  }) {
    Fluttertoast.showToast(
      msg: message,
      gravity: gravity,
      toastLength: Toast.LENGTH_SHORT,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16,
    );
  }

  void addPlant() {
    _showToast("🌿 Растение добавлено!");
    _notificationService.showNotification(
      title: "Новое растение",
      body: "Растение успешно добавлено в список 🌱",
    );
  }

  void addAction() {
    _showToast("✅ Действие добавлено!");
    _notificationService.showNotification(
      title: "Новое действие",
      body: "Вы добавили новое действие для растения 💧",
    );
  }

  void saveData() {
    _showToast("💾 Данные сохранены!");
    _notificationService.showNotification(
      title: "Сохранение данных",
      body: "Изменения успешно сохранены 📋",
    );
  }

  void unsavedWarning() {
    _showToast("⚠️ Не забудьте сохранить внесённые изменения!");
    _notificationService.showNotification(
      title: "Напоминание",
      body: "Не забудьте сохранить внесённые данные 📝",
    );
  }
}
