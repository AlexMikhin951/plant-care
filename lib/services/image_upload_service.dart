import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  /// Загружает фото и возвращает download URL
  static Future<String> uploadPlantImage({
    required Uint8List bytes,
    required String plantId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();

    final ref = FirebaseStorage.instance.ref(
      'plants/${user.uid}/$plantId/$fileName.jpg',
    );

    await ref.putData(bytes);

    return await ref.getDownloadURL();
  }
}
