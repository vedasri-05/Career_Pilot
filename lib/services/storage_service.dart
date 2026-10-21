import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads user resume to Firebase Storage
  Future<String> uploadResume({
    required PlatformFile file,
    required String userId,
  }) async {
    final bytes = await file.readAsBytes();

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    final storageReference = _storage.ref().child('resumes/$userId/$fileName');

    await storageReference.putData(
      bytes,
      SettableMetadata(contentType: _getContentType(file.extension)),
    );

    return await storageReference.getDownloadURL();
  }

  /// Uploads user profile image to Firebase Storage
  Future<String> uploadProfileImage({
    required PlatformFile file,
    required String userId,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final String extension = (file.extension ?? 'jpg').toLowerCase();
    final String fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final Reference storageReference = _storage.ref().child(
      'profile_images/$userId/$fileName',
    );

    final UploadTask uploadTask = storageReference.putData(
      bytes,
      SettableMetadata(contentType: _getImageContentType(extension)),
    );

    final TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  String _getImageContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';

      case 'doc':
        return 'application/msword';

      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

      default:
        return 'application/octet-stream';
    }
  }
}
