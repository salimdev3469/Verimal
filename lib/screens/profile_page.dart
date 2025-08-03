import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isEditing = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? "";
    _loadProfileData();
  }

  void _loadProfileData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final data = userDoc.data();
    if (data != null) {
      _nameController.text = data["name"] ?? "";
      _phoneController.text = data["phone"] ?? "";
      _imageUrl = data["photoUrl"];
      setState(() {});
    }
  }


  Future<void> _removeProfilePhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Firebase Storage'dan sil
      final storageRef = FirebaseStorage.instance.ref().child("profile_photos/$uid.jpg");
      await storageRef.delete();

      // 2. Firestore'dan 'photoUrl' alanını kaldır
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoUrl": FieldValue.delete(),
      });

      setState(() => _imageUrl = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil fotoğrafı başarıyla silindi."),duration:Duration(seconds: 2)),
      );
    } on FirebaseException catch (e) {
      debugPrint("Fotoğraf silinirken hata: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fotoğraf silinemedi: ${e.message}"),duration:Duration(seconds: 2)),
      );
    }
  }

  Future<bool> _requestImagePermission() async {
    if (await Permission.photos.request().isGranted) {
      return true;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Galeri erişimi reddedildi."),duration:Duration(seconds: 2)),
      );
      return false;
    }
  }

  Future<void> _pickAndUploadImage() async {
    bool status = await _requestImagePermission();

    if (!status) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Galeri erişim izni verilmedi!"),duration:Duration(seconds: 2)),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final storageRef = FirebaseStorage.instance.ref().child("profile_photos/$uid.jpg");
      await storageRef.putFile(File(picked.path));
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoUrl": downloadUrl,
      });

      setState(() => _imageUrl = downloadUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil fotoğrafı yüklendi!"),duration:Duration(seconds: 2)),
      );
    } catch (e) {
      debugPrint("Fotoğraf yüklenirken hata oluştu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fotoğraf yüklenemedi."),duration:Duration(seconds: 2)),
      );
    }
  }

  Future<void> _updateProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final user = FirebaseAuth.instance.currentUser;
    if (uid == null || user == null) return;



    try {
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
      });

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil başarıyla güncellendi."),duration:Duration(seconds: 2)),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("Email güncellenemedi: $e");
      String message = "Profil güncellenemedi.";
      if (e.code == 'requires-recent-login') {
        message = "Bu işlemi yapmak için yeniden giriş yapmanız gerekiyor.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message),duration:Duration(seconds: 2)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text("Profil"),
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: Lottie.asset('assets/lottie/hourglass.json', width: 120));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final coins = userData["coins"] ?? 0;
          final totalSeconds = userData["totalWorkSeconds"] ?? 0;
          final level = (totalSeconds / 28800).floor(); // 8 saat = 28800 saniye
          final photoUrl = userData["photoUrl"];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isEditing ? _pickAndUploadImage : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 80,
                          backgroundColor: const Color(0xFFe0c5f5),
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? const Icon(Icons.person, size: 50, color: Colors.white)
                              : null,
                        ),
                        if (_isEditing)
                          const Positioned(
                            bottom: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFF7f32a8),
                              child: Icon(Icons.edit, size: 16, color: Colors.white),
                            ),
                          ),

                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_imageUrl != null && _isEditing)
                    TextButton.icon(
                      onPressed: _removeProfilePhoto,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text("Fotoğrafı Kaldır", style: TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: _nameController,
                    readOnly: !_isEditing,
                    style: TextStyle(fontSize: 17),
                    decoration: const InputDecoration(labelText: "Ad Soyad"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    readOnly: !_isEditing,
                    style: TextStyle(fontSize: 17),
                    decoration: const InputDecoration(labelText: "Telefon"),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    readOnly: true,
                    style: TextStyle(fontSize: 17),
                    decoration: const InputDecoration(
                      labelText: "E-Posta",
                      helperText: "E-posta yalnızca görüntülenebilir, değiştirilemez.",
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isEditing
                          ? () async {
                        await _updateProfile();
                        setState(() => _isEditing = false); // Güncelle sonrası düzenleme kapansın
                      }
                          : () => setState(() => _isEditing = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isEditing ? Colors.green : const Color(0xFF7f32a8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_isEditing ? "Güncelle" : "Düzenle", style:TextStyle(fontSize: 17)),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildInfoCard(Icons.monetization_on, "Coin", coins.toString()),
                  const SizedBox(height: 16),
                  _buildInfoCard(Icons.track_changes, "Level", level.toString()),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return FractionallySizedBox(
      widthFactor: 0.75,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF7f32a8), size: 32),
              const SizedBox(width: 20),
              Text("$label: $value", style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}


