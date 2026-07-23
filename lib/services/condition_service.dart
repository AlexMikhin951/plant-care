import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_secrets.dart';
import '../models/plant.dart';

class ConditionService {
  static const String _url = "https://openrouter.ai/api/v1/chat/completions";
  static const String _model = "google/gemma-3-12b-it:free";

  static Future<Plant> evaluateAndSaveCondition({required Plant plant}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован.');
    }

    if (plant.imagePaths.isEmpty) {
      throw Exception('Нет изображения для анализа.');
    }

    try {
      final imagePath = plant.imagePaths.last;
      Uint8List imageBytes;

      // УНИВЕРСАЛЬНЫЙ СПОСОБ ПОЛУЧЕНИЯ БАЙТОВ
      if (imagePath.startsWith('data:image')) {
        // Если это base64 строка
        imageBytes = base64Decode(imagePath.split(',').last);
      } else if (imagePath.startsWith('http') || kIsWeb) {
        // Если это URL (включая blob: на Web) или мы на Web платформе
        final response = await http.get(Uri.parse(imagePath));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        } else {
          throw Exception(
            'Не удалось загрузить изображение по пути: $imagePath',
          );
        }
      } else {
        // Для мобильных платформ (локальный путь)
        // Импортируйте 'dart:io' as io; и используйте io.File
        // Но лучше использовать универсальный метод выше
        throw Exception('Неподдерживаемый формат пути');
      }

      final String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(_url),
        headers: {
          "Authorization": "Bearer ${AppSecrets.openRouterApiKeyOrThrow}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text":
                      "Ты бот-ботаник. Оцени состояние растения по фото. Ответь ТОЛЬКО числом 0-100.",
                },
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
      final String text = responseData['choices'][0]['message']['content']
          .trim();
      final match = RegExp(r'(\d+)').firstMatch(text);

      if (match == null) throw Exception('Число не найдено.');

      int score = int.parse(match.group(1)!);
      if (score > 100) score = 100;

      plant.condition = score;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('plants')
          .doc(plant.id)
          .update({'condition': score});

      return plant;
    } catch (e) {
      print('⚠️ Ошибка: $e');
      rethrow;
    }
  }
}
