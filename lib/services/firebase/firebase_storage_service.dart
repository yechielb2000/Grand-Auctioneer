import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService(this._storage);

  final FirebaseStorage _storage;

  Future<String> uploadAvatar({
    required String uid,
    required Uint8List imageBytes,
    required String contentType,
  }) async {
    if (imageBytes.isEmpty) throw ArgumentError.value(imageBytes, 'imageBytes');
    final reference = _storage.ref().child('users/$uid/avatar');
    final snapshot = await reference.putData(
      imageBytes,
      SettableMetadata(contentType: contentType),
    );
    return snapshot.ref.getDownloadURL();
  }
}
