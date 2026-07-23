import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Добавлен для связи с UID
import '../config/app_secrets.dart';
import '../models/plant.dart';

class AIService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // 🔥 Экземпляр Auth

  // ============================================================
  // 🔥 ЕДИНАЯ ФУНКЦИЯ СОХРАНЕНИЯ (СВЯЗАННАЯ С ПОЛЬЗОВАТЕЛЕМ)
  // ============================================================
  Future<void> savePlantToFirebase(Plant plant) async {
    final user = _auth.currentUser;
    if (user == null) {
      print("⚠️ Ошибка сохранения: Пользователь не авторизован");
      return;
    }

    // Сохраняем по пути: users -> {userId} -> plants -> {plantId}
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('plants')
        .doc(plant.id)
        .set(plant.toJson(), SetOptions(merge: true));

    print("✅ Растение сохранено в профиль пользователя: ${user.uid}");
  }

  // ============================================================
  // 🔹 РЕГИСТРАЦИЯ РАСТЕНИЯ (Прямой запрос к OpenRouter)
  // ============================================================
  Future<Plant> recognizePlantWithGemini({
    required String imagePath,
    Uint8List? imageBytesWeb,
  }) async {
    const prompt = '''
Ты бот-ботаник. Ответь строго в формате JSON на русском языке.
Все поля обязательны. condition всегда -100.
Формат:
{
  "id": "unique_id",
  "name": "название",
  "description": "описание",
  "careInstructions": "инструкции",
  "careTips": "советы",
  "condition": -100,
  "watering": "каждые N дней в HH:MM",
  "fertilizing": "каждые N дней в HH:MM",
  "pruning": "не требуется", или "каждые N дней в HH:MM",
  "repotting": "не требуется", или "каждые N дней в HH:MM",
  "misting": "не требуется", или "каждые N дней в HH:MM",
  "cleaningLeaves": "не требуется", или "каждые N дней в HH:MM",
  "pestControl": "не требуется", или "каждые N дней в HH:MM",
  "staking": "не требуется", или "каждые N дней в HH:MM",
  "lightAdjustment": "не требуется", или "каждые N дней в HH:MM",
  "temperatureAdjustment": "не требуется" или "каждые N дней в HH:MM",
}
''';

    // 🔹 Подготовка изображения
    Uint8List imageBytes;
    if (kIsWeb) {
      if (imageBytesWeb == null)
        throw Exception('На Web нужно передать imageBytesWeb');
      imageBytes = imageBytesWeb;
    } else {
      imageBytes = await File(imagePath).readAsBytes();
    }
    final String base64Image = base64Encode(imageBytes);

    // 🔹 Прямой HTTP запрос к OpenRouter
    final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer ${AppSecrets.openRouterApiKeyOrThrow}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "model": "google/gemma-3-12b-it:free",
        "messages": [
          {
            "role": "user",
            "content": [
              {"type": "text", "text": prompt},
              {
                "type": "image_url",
                "image_url": {"url": "data:image/jpeg;base64,$base64Image"},
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка API: ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final String text = responseData['choices'][0]['message']['content'].trim();

    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (jsonMatch == null) throw Exception('JSON не найден в ответе');

    final Map<String, dynamic> jsonData = jsonDecode(jsonMatch.group(0)!);

    // 🔹 Создание объекта Plant
    final plant = Plant(
      id: jsonData["id"]?.toString() ?? const Uuid().v4(),
      name: jsonData["name"]?.toString() ?? "Неизвестное растение",
      description: jsonData["description"]?.toString() ?? "",
      careInstructions: jsonData["careInstructions"]?.toString() ?? "",
      careTips: jsonData["careTips"] ?? "",
      condition: (jsonData["condition"] as num?)?.toInt() ?? -100,
      imagePaths: [imagePath],
    );

    // 🔹 Логика расписаний (без изменений)
    final actions = {
      "watering": jsonData["watering"],
      "fertilizing": jsonData["fertilizing"],
      "pruning": jsonData["pruning"],
      "repotting": jsonData["repotting"],
      "misting": jsonData["misting"],
      "cleaningLeaves": jsonData["cleaningLeaves"],
      "pestControl": jsonData["pestControl"],
      "staking": jsonData["staking"],
      "lightAdjustment": jsonData["lightAdjustment"],
      "temperatureAdjustment": jsonData["temperatureAdjustment"],
    };

    final now = DateTime.now();
    final timeRegex = RegExp(r'(\d{2}):(\d{2})');
    final intervalRegex = RegExp(r'каждые (\d+) дней');

    actions.forEach((key, value) {
      if (value is! String || value == "не требуется") return;
      final times = timeRegex
          .allMatches(value)
          .map(
            (m) => TimeOfDay(
              hour: int.parse(m.group(1)!),
              minute: int.parse(m.group(2)!),
            ),
          )
          .toList();
      final interval = intervalRegex.firstMatch(value);
      final days = interval != null ? int.parse(interval.group(1)!) : 1;
      final endDate = DateTime(now.year + 3, now.month, now.day);

      for (final time in times) {
        DateTime date = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        while (date.isBefore(endDate)) {
          if (!date.isBefore(now)) {
            switch (key) {
              case "watering":
                plant.wateringDates.add(date);
                break;
              case "fertilizing":
                plant.fertilizingDates.add(date);
                break;
              case "pruning":
                plant.pruningDates.add(date);
                break;
              case "repotting":
                plant.repottingDates.add(date);
                break;
              case "misting":
                plant.mistingDates.add(date);
                break;
              case "cleaningLeaves":
                plant.cleaningLeavesDates.add(date);
                break;
              case "pestControl":
                plant.pestControlDates.add(date);
                break;
              case "staking":
                plant.stakingDates.add(date);
                break;
              case "lightAdjustment":
                plant.lightAdjustmentDates.add(date);
                break;
              case "temperatureAdjustment":
                plant.temperatureAdjustmentDates.add(date);
                break;
            }
          }
          date = date.add(Duration(days: days));
        }
      }
    });

    // Сохранение уже по новому пути
    await savePlantToFirebase(plant);
    return plant;
  }
}
