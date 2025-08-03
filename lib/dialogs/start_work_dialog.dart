import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:verimal/screens/work_page.dart';

class StartWorkDialog extends StatefulWidget {
  const StartWorkDialog({super.key});

  @override
  State<StartWorkDialog> createState() => _StartWorkDialogState();
}

class _StartWorkDialogState extends State<StartWorkDialog> {
  Map<String, Map<String, String>> _ownedSoundMap = {}; // name: {asset, assetUrl}
  final _topicController = TextEditingController();
  String _selectedBackground = 'Ev';
  String _selectedSound = 'Yağmur';
  List<String> _savedTopics = [];
  List<String> _ownedSoundsFromMarket = [];
  List<String> _ownedBackgroundsFromMarket = [];
  bool _loadingTopics = true;
  String? _selectedTopic;
  final List<String> backgrounds = ['Ev', 'Kütüphane', 'Orman', 'Gece Orman', 'Kumsal'];
  final List<String> sounds = ['Yağmur', 'Yazma', 'Sessizlik', 'Kütüphane'];
  List<String> _customBackgrounds = [];

  // Yükleme fonksiyonları kaldırıldı. _fetchCustomFiles() sadece Firestore'dan veri çeker.
  Future<void> _fetchCustomFiles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _customBackgrounds = List<String>.from(doc.data()?['customBackgrounds'] ?? []);
    });
  }


  InputDecoration _customInputDecoration(String? label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFF7f32a8), // şeffaf mor
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7f32a8), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7f32a8), width: 2),
      ),
      labelStyle: const TextStyle(color: Color(0xFF7f32a8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _fetchOwnedSoundMap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final ownedItemIds = List<String>.from(userDoc.data()?['ownedItems'] ?? []);

    final snapshot = await FirebaseFirestore.instance.collectionGroup("music_wind").get();

    final Map<String, Map<String, String>> result = {};
    for (final doc in snapshot.docs) {
      if (ownedItemIds.contains(doc.id)) {
        final data = doc.data();
        final name = data['name'] ?? 'Bilinmeyen';
        final asset = data['asset'];
        final assetUrl = data['assetUrl'];

        result[name] = {
          if (asset != null) 'asset': asset,
          if (assetUrl != null) 'assetUrl': assetUrl,
        };
      }
    }

    setState(() {
      _ownedSoundMap = result;
      _ownedSoundsFromMarket = result.keys.toList();
    });
  }


  @override
  void initState() {
    super.initState();
    _fetchSavedTopics();
    _fetchCustomFiles();
    _fetchOwnedSoundMap(); // <-- sesleri assetUrl ile getir
    _fetchOwnedBackgroundNames().then((value) {
      setState(() {
        _ownedBackgroundsFromMarket = value;
      });
    });
  }

  Future<List<String>> _fetchOwnedBackgroundNames() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final ownedItemIds = List<String>.from(userDoc.data()?['ownedItems'] ?? []);

    final snapshot = await FirebaseFirestore.instance.collectionGroup("backgrounds").get();

    final ownedBackgrounds = snapshot.docs.where((doc) => ownedItemIds.contains(doc.id)).map((doc) {
      final data = doc.data();
      return data['name'] as String? ?? 'Bilinmeyen';
    }).toList();

    return ownedBackgrounds;
  }

  Future<void> _fetchSavedTopics() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final topics = data?['topics'] as List<dynamic>?;

      if (topics != null) {
        setState(() {
          _savedTopics = List<String>.from(topics);
          _loadingTopics = false;
        });
      }
    } catch (e) {
      debugPrint("Konu listesi alınamadı: $e");
      setState(() => _loadingTopics = false);
    }
  }

  Future<void> _handleStart() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !_savedTopics.contains(topic)) {
      final ref = FirebaseFirestore.instance.collection("users").doc(uid);
      await ref.update({
        "topics": FieldValue.arrayUnion([topic])
      });
    }

    // 🔹 Arka Plan çözümlemesi
    String? resolvedBackground = _selectedBackground;

    if (_ownedBackgroundsFromMarket.contains(_selectedBackground)) {
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup("backgrounds")
          .where("name", isEqualTo: _selectedBackground)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docData = snapshot.docs.first.data();
        final asset = docData['asset'] as String?;
        final assetUrl = docData['assetUrl'] as String?;

        resolvedBackground = assetUrl ?? asset ?? _selectedBackground;
      } else {
        debugPrint("⚠️ Arka plan bulunamadı: $_selectedBackground");
      }
    } else if (_selectedBackground.startsWith("http")) {
      resolvedBackground = _selectedBackground;
    }

    // 🔒 Eğer null kalırsa default değer ata
    resolvedBackground ??= 'assets/images/default.jpg';

    // 🔹 Ses çözümlemesi
    String? resolvedSound = _selectedSound;

    final matchedEntry = _ownedSoundMap.entries.firstWhere(
          (entry) => entry.key.toLowerCase().trim() == _selectedSound.toLowerCase().trim(),
      orElse: () => MapEntry('', {}),
    );

    if (matchedEntry.value.isNotEmpty) {
      resolvedSound = matchedEntry.value['assetUrl'] ??
          matchedEntry.value['asset'] ??
          _selectedSound;
    }

    // 🔒 Eğer null kalırsa default sessizlik sesi ata
    resolvedSound ??= 'Sessizlik';

    debugPrint("🎯 Konu: $topic");
    debugPrint("🎨 Arka plan: $resolvedBackground");
    debugPrint("🎧 Ses: $resolvedSound");

    if (context.mounted) {
      Navigator.pop(context); // dialog'u kapat
      Future.microtask(() {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkPage(
              topic: topic,
              background: resolvedBackground!,
              sound: resolvedSound!,
            ),
          ),
        );
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF7f32a8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Çalışmaya Başla",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // 🧠 Konu Dropdown + Silme
              DropdownButtonFormField<String>(
                value: _savedTopics.contains(_topicController.text) ? _topicController.text : null,
                dropdownColor: const Color(0xFF7f32a8),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Konu Seçimi",
                  labelStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _savedTopics.map((topic) {
                  return DropdownMenuItem<String>(
                    value: topic,
                    child: StatefulBuilder(
                      builder: (context, setInnerState) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(topic, style: const TextStyle(color: Colors.white))),
                            GestureDetector(
                              onTap: () async {
                                final uid = FirebaseAuth.instance.currentUser?.uid;
                                if (uid != null) {
                                  await FirebaseFirestore.instance
                                      .collection("users")
                                      .doc(uid)
                                      .update({
                                    "topics": FieldValue.arrayRemove([topic])
                                  });

                                  // Asıl setState'e erişim
                                  if (mounted) {
                                    setState(() {
                                      _savedTopics.remove(topic);
                                    });
                                  }

                                  // Dropdown'u zorla kapat
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Icon(Icons.close, size: 18, color: Colors.white54),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _topicController.text = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              // ✍️ Yeni Konu Girişi
              TextField(
                controller: _topicController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Yeni Konu (Opsiyonel)",
                  hintStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedBackground,
                dropdownColor: const Color(0xFF7f32a8),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Arka Plan",
                  labelStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: [
                  ...backgrounds,
                  ..._ownedBackgroundsFromMarket,
                  ..._customBackgrounds
                ].toSet().map((bg) {
                  return DropdownMenuItem<String>(
                    value: bg,
                    child: Tooltip(
                      message: bg,
                      child: Row(
                        children: [
                          Icon(
                            bg.startsWith('http')
                                ? Icons.image_outlined
                                : Icons.landscape_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            bg.startsWith('http') ? '🖼️ Özel Arka Plan' : bg,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );

                }).toList(),
                onChanged: (val) => setState(() => _selectedBackground = val!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedSound,
                dropdownColor: const Color(0xFF7f32a8),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Ses",
                  labelStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  ...sounds,
                  ..._ownedSoundsFromMarket,
                ].toSet().map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.startsWith('http') ? '🎵 Özel Ses' : s,
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedSound = val!),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("İptal", style: TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _handleStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text("Başla"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
