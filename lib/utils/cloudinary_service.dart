import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final cloudinary = CloudinaryPublic(
    'drv1nkp1r', // 🔧 Replace with your Cloudinary cloud name
    'uploadpreset', // 🔧 Replace with upload preset
    cache: false,
  );

  Future<String?> uploadImage(File image) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(image.path, folder: 'roofinity_ads'),
      );
      return response.secureUrl;
    } catch (e) {
      print("Cloudinary upload error: $e");
      return null;
    }
  }
}
