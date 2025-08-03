import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<String> ownedItemIds = [];
  String? selectedPetId;
  List<String> _customBackgrounds = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchCustomFiles(); // önce özel arka planları çek
    await _loadInventory();    // sonra envanter verilerini yükle
  }

  Future<void> _loadInventory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final data = userDoc.data() ?? {};
    ownedItemIds = List<String>.from(data['ownedItems'] ?? []);
    selectedPetId = data['selectedPet'];
    setState(() {});
  }

  Future<void> _deleteCustomBackground(String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      // 1. Storage’tan sil
      await FirebaseStorage.instance.refFromURL(url).delete();

      // 2. Firestore'dan çıkar
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'customBackgrounds': FieldValue.arrayRemove([url]),
        'ownedItems': FieldValue.arrayRemove([url]),
      });

      // 3. Local listeyi güncelle
      setState(() {
        _customBackgrounds.remove(url);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Arka plan silindi."), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      print("Silme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silme işlemi başarısız."), duration: Duration(seconds: 2)),
      );
    }
  }


  Future<void> _uploadCustomBackground() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_customBackgrounds.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("En fazla 3 özel arka plan yükleyebilirsiniz."),duration:Duration(seconds: 2)),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true, // 🚨 Bu satır gerekli!
      );
      if (result == null) return;

      final file = result.files.first;
      final fileBytes = file.bytes;
      if (fileBytes == null) {
        print("Dosya içeriği null.");
        return;
      }

      final fileName = 'backgrounds/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Storage’a yükle
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await ref.putData(fileBytes);

      // 2. URL al
      final downloadUrl = await ref.getDownloadURL();
      print("Yüklenen arka plan URL: $downloadUrl");

      // 3. Firestore’a customBackgrounds listesine ekle
      final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
      await userDoc.update({
        'customBackgrounds': FieldValue.arrayUnion([downloadUrl]),
        'ownedItems': FieldValue.arrayUnion([downloadUrl]),
      });

      print("Firestore'a eklendi");
      await _fetchCustomFiles();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Arka plan başarıyla yüklendi."),duration:Duration(seconds: 2)),
      );
    } catch (e) {
      print("Yükleme hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yükleme başarısız."),duration:Duration(seconds: 2)),
      );
    }
  }

  Future<void> _fetchCustomFiles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    _customBackgrounds = List<String>.from(doc.data()?['customBackgrounds'] ?? []);
  }


  Future<Map<String, Map<String, dynamic>>> _fetchOwnedItems() async {
    final Map<String, Map<String, dynamic>> results = {};
    final ownedItemIdsSet = ownedItemIds.toSet();
    const List<String> subcollections = ['music_wind', 'pet_fox', 'backgrounds'];

    for (final sub in subcollections) {
      final query = await FirebaseFirestore.instance.collectionGroup(sub).get();
      for (final doc in query.docs) {
        if (ownedItemIdsSet.contains(doc.id) && !_customBackgrounds.contains(doc.id)) {
          results[doc.id] = doc.data();
        }
      }
    }

    // Özel arka planları manuel ekle
    for (final url in _customBackgrounds) {
      results[url] = {
        'name': 'Özel Arka Plan',
        'assetUrl': url,
        'type': 'backgrounds',
      };
    }

    return results;
  }



  Future<void> _selectPet(String itemId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    if (selectedPetId == itemId) {
      // Seçimi kaldır
      await userRef.update({'selectedPet': FieldValue.delete()});
      setState(() => selectedPetId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pet seçimi kaldırıldı."),duration:Duration(seconds: 2)),
      );
    } else {
      // Yeni pet seç
      await userRef.update({'selectedPet': itemId});
      setState(() => selectedPetId = itemId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pet başarıyla seçildi!"),duration:Duration(seconds: 2)),
      );
    }
  }

  Widget _buildCustomBackgroundCard(String imageUrl, int index) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Özel Arka Plan (${index + 1})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          TextButton.icon(
            onPressed: () => _deleteCustomBackground(imageUrl),
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }



  Future<Widget> _buildAssetWidget(Map<String, dynamic> data) async {
    final asset = data['asset'];
    final assetUrl = data['assetUrl'];

    try {
      if (asset != null && asset.toString().endsWith('.json')) {
        debugPrint("Lottie asset yüklendi: $asset");
        return Lottie.asset(
          asset,
          fit: BoxFit.contain,
        );
      }

      if (assetUrl != null && assetUrl.toString().contains('.json')) {
        debugPrint("Lottie URL'den yüklenecek: $assetUrl");
        final response = await http.get(Uri.parse(assetUrl));
        if (response.statusCode == 200) {
          return Lottie.memory(
            response.bodyBytes,
            fit: BoxFit.contain,
          );
        } else {
          debugPrint("Lottie yüklenemedi, HTTP durum: ${response.statusCode}");
          return const Icon(Icons.broken_image);
        }
      }

      if (assetUrl != null) {
        debugPrint("Görsel yüklenecek: $assetUrl");
        return Image.network(
          assetUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("Görsel yüklenemedi: $error");
            return const Icon(Icons.broken_image);
          },
        );
      }

      if (asset != null) {
        debugPrint("Yerel görsel yüklenecek: $asset");
        return Image.asset(
          asset,
          fit: BoxFit.cover,
        );
      }

      debugPrint("Desteklenmeyen format: asset: $asset, assetUrl: $assetUrl");
      return const Icon(Icons.image_not_supported);
    } catch (e) {
      debugPrint("ASSET ERROR: $e");
      return const Icon(Icons.broken_image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Envanter"),
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, Map<String, dynamic>>>(
        future: _fetchOwnedItems(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final items = snapshot.data!;
            final sounds = items.entries.where((e) => e.value['type'] == 'sounds').toList();
            final backgrounds = items.entries.where((e) => e.value['type'] == 'backgrounds').toList();
            final pets = items.entries.where((e) => e.value['type'] == 'pet_fox').toList();
            int customIndex = 0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 💡 Info + Buton her zaman gösterilir
                  Row(
                    children: const [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "En fazla 3 özel arka plan yükleyebilirsiniz. Yüklediklerinizi silebilirsiniz.",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploadCustomBackground,
                        icon: const Icon(Icons.image),
                        label: const Text("Arka Plan Yükle"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7f32a8),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (items.isEmpty)
                    const Center(child: Text("Hiç ürününüz yok."))
                  else ...[
                    const Text("🎵 Sesler", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (sounds.isEmpty)
                      const Text("Ses bulunamadı.")
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sounds.map((entry) {
                          final name = entry.value['name'] ?? 'Ses';
                          return Chip(
                            avatar: const Icon(Icons.music_note, color: Colors.white),
                            label: Text(name, style: const TextStyle(fontSize: 16)),
                            backgroundColor: const Color(0xFF7f32a8),
                            labelStyle: const TextStyle(color: Colors.white),
                          );
                        }).toList(),
                      ),

                    const SizedBox(height: 24),
                    const Text("🖼️ Arka Planlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (backgrounds.isEmpty)
                      const Text("Ürün bulunmamaktadır."),
                    if (backgrounds.isNotEmpty)
                      Column(
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: backgrounds.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemBuilder: (context, index) {
                              final entry = backgrounds[index];
                              final data = entry.value;
                              final assetUrl = data['assetUrl'];

                              final isCustom = _customBackgrounds.contains(assetUrl);

                              if (isCustom) {
                                final thisIndex = customIndex;
                                customIndex++;
                                return _buildCustomBackgroundCard(assetUrl, thisIndex);
                              }

                              // Normal marketten alınan arka plan
                              return FutureBuilder<Widget>(
                                future: _buildAssetWidget(data),
                                builder: (context, snapshot) {
                                  final assetWidget = snapshot.data ?? const SizedBox(height: 100);
                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                            child: assetWidget,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            data['name'] ?? "Arka Plan",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        ],
                      ),
                    const SizedBox(height: 24),
                    const Text("🐾 Sanal Hayvanlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (pets.isEmpty)
                      const Text("Ürün bulunmamaktadır.")
                    else
                      _buildGrid(pets, isPet: true),
                  ],
                  const SizedBox(height: 14),
                ],

              ),
            );
          }
      ),
    );
  }

  Widget _buildGrid(List<MapEntry<String, Map<String, dynamic>>> entries, {bool isPet = false}) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
      children: entries.map((entry) {
        final itemId = entry.key;
        final data = entry.value;
        final name = data['name'] ?? 'İsimsiz';
        final asset = data['asset'];
        final assetUrl = data['assetUrl'];

        return FutureBuilder<Widget>(
          future: _buildAssetWidget(data),
          builder: (context, snapshot) {
            final assetWidget = snapshot.data ?? const SizedBox(height: 100);
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      height: 100,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: assetWidget,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    if (isPet)
                      ElevatedButton(
                        onPressed: () => _selectPet(itemId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedPetId == itemId ? Colors.green : const Color(0xFF7f32a8),
                        ),
                        child: Text(
                          selectedPetId == itemId ? "Seçildi" : "Pet Olarak Ayarla",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
