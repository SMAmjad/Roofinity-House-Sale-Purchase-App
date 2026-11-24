import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config/payment_config.dart';
import '../services/firestore_service.dart';
import '../utils/cloudinary_service.dart';
import '../utils/image_authenticity_service.dart';
import '../utils/image_utils.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class SellerUploadAd extends StatefulWidget {
  const SellerUploadAd({super.key});

  @override
  State<SellerUploadAd> createState() => _SellerUploadAdState();
}

class _SellerUploadAdState extends State<SellerUploadAd> {
  static const int _minImages = 3;
  static const int _maxImages = 10;

  final _title = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final List<File> _images = [];
  File? _paymentSlip;

  bool _busy = false;
  String _busyMessage = '';

  @override
  void initState() {
    super.initState();
    // Load the AI model in the background so the check is fast later.
    ImageAuthenticityService.instance.warmUp();
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    final room = _maxImages - _images.length;
    if (picked.length > room) {
      _showSnack('You can add up to $_maxImages images.');
    }
    final files = <File>[];
    for (final f in picked.take(room)) {
      try {
        files.add(await ensureReadableImage(File(f.path)));
      } catch (_) {
        _showSnack('One image could not be read. Please choose a JPG or PNG photo.');
      }
    }
    if (!mounted) return;
    setState(() => _images.addAll(files));
  }

  Future<void> _pickPaymentSlip() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _paymentSlip = File(picked.path));
    }
  }

  String? _validate() {
    if (_title.text.trim().length < 5) {
      return 'Please enter an ad title (at least 5 characters).';
    }
    final price = int.tryParse(_price.text.trim());
    if (price == null || price <= 0) {
      return 'Please enter a valid price.';
    }
    if (_description.text.trim().length < 20) {
      return 'Please write a description (at least 20 characters).';
    }
    if (_images.length < _minImages) {
      return 'Please select at least $_minImages property images.';
    }
    if (_paymentSlip == null) {
      return 'Please upload the payment slip.';
    }
    return null;
  }

  void _setBusy(bool busy, [String message = '']) {
    if (!mounted) return;
    setState(() {
      _busy = busy;
      _busyMessage = message;
    });
  }

  Future<void> _uploadAd() async {
    FocusScope.of(context).unfocus();

    final validationError = _validate();
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showSnack('You must be logged in to upload an ad.');
      return;
    }

    // 1. AI authenticity check (runs on-device, before anything is uploaded).
    _setBusy(true, 'Checking images with AI...');
    final aiResult =
        await ImageAuthenticityService.instance.checkImages(List.of(_images));
    if (!mounted) return;

    if (aiResult.verdict == AuthenticityVerdict.error) {
      _setBusy(false);
      await _showAiErrorDialog(aiResult);
      return;
    }
    if (aiResult.verdict == AuthenticityVerdict.fake) {
      _setBusy(false);
      await _showFakeDialog(aiResult);
      return;
    }

    // 2. Upload images + slip, then save the ad.
    try {
      _setBusy(true, 'Uploading images...');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final sellerName = (userDoc.data()?['name'] as String?) ?? 'Agent';

      final cloudinary = CloudinaryService();
      Future<String?> upload(File file) async =>
          cloudinary.uploadImage(await _compressOrOriginal(file));

      final results = await Future.wait([
        ..._images.map(upload),
        upload(_paymentSlip!),
      ]);
      if (results.any((url) => url == null)) {
        throw Exception('Some images could not be uploaded. Check your internet and try again.');
      }
      final imageUrls = results.take(_images.length).cast<String>().toList();
      final paymentSlipUrl = results.last!;

      _setBusy(true, 'Saving your ad...');
      await FirestoreService().addPropertyAd(
        sellerId: currentUser.uid,
        sellerName: sellerName,
        title: _title.text.trim(),
        price: _price.text.trim(),
        description: _description.text.trim(),
        imageUrls: imageUrls,
        paymentSlipUrl: paymentSlipUrl,
        aiCheck: aiResult.toFirestore(),
      );

      if (!mounted) return;
      _title.clear();
      _price.clear();
      _description.clear();
      setState(() {
        _images.clear();
        _paymentSlip = null;
      });
      _setBusy(false);
      await _showSuccessDialog();
    } catch (e) {
      _setBusy(false);
      _showSnack('Upload failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<File> _compressOrOriginal(File file) async {
    try {
      return await compressImage(file);
    } catch (_) {
      return file;
    }
  }

  Future<void> _showFakeDialog(AuthenticityResult result) {
    final flagged = result.flaggedIndexes.map((i) => '#${i + 1}').join(', ');
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.gpp_bad_outlined, color: Colors.red, size: 40),
        title: const Text('Image Authenticity Check Failed'),
        content: Text(
          'Our AI model found that image $flagged may be fake or AI-generated '
          '(highest fake score: ${(result.maxFakeScore * 100).toStringAsFixed(1)}%).\n\n'
          'Please remove the flagged image(s) and upload real photos of the property.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAiErrorDialog(AuthenticityResult result) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.orange, size: 40),
        title: const Text('Could Not Verify Images'),
        content: const Text(
          'The AI image check could not run, so the ad was not uploaded. '
          'Please make sure the images are JPG or PNG and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _uploadAd();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified, color: Color(0xFF1E8E3E), size: 40),
        title: const Text('Ad Submitted'),
        content: const Text(
          'Your images passed the AI authenticity check.\n\n'
          'Your ad will go live once the admin approves your payment slip.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _imageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_images[index], fit: BoxFit.cover),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: _circleLabel('${index + 1}'),
            ),
            if (!_busy)
              Positioned(
                right: 2,
                top: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(index)),
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _circleLabel(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _paymentInfo() {
    const style = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recipient: ${PaymentConfig.recipient}', style: style),
        SizedBox(height: 4),
        Text('Bank Name: ${PaymentConfig.method}', style: style),
        SizedBox(height: 4),
        Text('Account No: ${PaymentConfig.accountNumber}', style: style),
        SizedBox(height: 4),
        Text('Payment Amount: ${PaymentConfig.adFeePkr} Rs', style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Property')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomTextField(controller: _title, hintText: 'Ad Title'),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _price,
                hintText: 'Price (PKR)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _description,
                hintText: 'Property Description',
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _images.length >= _maxImages ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Select Images'),
                  ),
                  const Spacer(),
                  Text(
                    '${_images.length} selected (min $_minImages)',
                    style: TextStyle(
                      color: _images.length >= _minImages ? Colors.green : Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'All images are checked by our AI model for fake or AI-generated photos before upload.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              if (_images.isNotEmpty) _imageGrid(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),
              const Text(
                'Upload Payment Slip',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _paymentInfo(),
              const SizedBox(height: 10),
              if (_paymentSlip == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickPaymentSlip,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Select Slip'),
                  ),
                )
              else
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_paymentSlip!, height: 150),
                    ),
                    TextButton.icon(
                      onPressed: _pickPaymentSlip,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Change Slip'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(_busyMessage, textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              CustomButton(
                text: _busy ? 'Please wait...' : 'Upload Ad',
                onPressed: _busy ? null : _uploadAd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
