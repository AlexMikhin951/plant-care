import 'dart:developer';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Инициализация сервиса и временной зоны
  Future<void> init() async {
    if (_initialized) {
      log('⚙️ NotificationService уже инициализирован');
      return;
    }

    // --- Инициализация временных зон ---
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final tzName = tzInfo.identifier; // ✅ верно
      tz.setLocalLocation(tz.getLocation(tzName));
      log('🕓 Временная зона установлена: $tzName');
    } catch (e) {
      log('⚠️ Ошибка timezone, используем UTC: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // --- Настройка плагина уведомлений ---
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        log('🔔 Нажали уведомление: ${details.payload}');
      },
    );

    // --- Создание канала Android ---
    const androidChannel = AndroidNotificationChannel(
      'plant_channel',
      'Plant Notifications',
      description: 'Напоминания о растениях',
      importance:
          Importance.defaultImportance, // не max, чтобы не мешать системе
      playSound: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      log('✅ Канал уведомлений создан');
    }

    _initialized = true;
    log('✅ NotificationService инициализирован успешно');
  }

  /// Мгновенное уведомление
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'plant_channel',
        'Plant Notifications',
        channelDescription: 'Напоминания о растениях',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(id, title, body, details, payload: payload);

    final now = DateFormat('HH:mm:ss').format(DateTime.now());
    Fluttertoast.showToast(
      msg: "🔔 Уведомление показано ($now)",
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  /// Плановое уведомление (неточное, энергосберегающее)
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await init();

    final scheduled = tz.TZDateTime.from(scheduledDate, tz.local);

    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      Fluttertoast.showToast(
        msg: "⚠️ Время уведомления уже прошло!",
        toastLength: Toast.LENGTH_SHORT,
      );
      log('⏰ Время уведомления в прошлом: $scheduled');
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'plant_channel',
        'Plant Notifications',
        channelDescription: 'Напоминания о растениях',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      // 💡 Новый режим: позволяет системе немного сместить время для экономии энергии
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null, // без повторов
      payload: payload,
    );

    final formatted = DateFormat('dd.MM.yyyy HH:mm:ss').format(scheduledDate);
    Fluttertoast.showToast(
      msg: "📅 Уведомление (неточное) запланировано на $formatted",
      toastLength: Toast.LENGTH_SHORT,
    );

    log('📅 Запланировано неточное уведомление: $title на $formatted');
  }
}
