import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:async';


class WorkPage extends StatefulWidget {
  final String topic;
  final String background;
  final String sound;

  const WorkPage({
    super.key,
    required this.topic,
    required this.background,
    required this.sound,
  });

  @override
  State<WorkPage> createState() => _WorkPageState();
}

class _WorkPageState extends State<WorkPage> {
  bool _isRunning = false;
  String _selectedPetAsset = 'assets/lottie/cat.json'; // default pet
  bool _isMusicPlaying = true;
  int _seconds = 0;
  late final AudioPlayer _player;
  late final String _backgroundImage;
  bool _showCoin = false;
  bool _showDream=false;
  late final AudioPlayer _effectPlayer;
  late String _currentSound;
  late Future<Widget> _petWidgetFuture;
  late DateTime _startTime;
  Timer? _timer;


  @override
  void initState() {
    super.initState();

    _petWidgetFuture = _loadPetWidget();
    _player = AudioPlayer();
    _effectPlayer = AudioPlayer();
    _isMusicPlaying = true;
    _seconds = 0;

    _fetchSelectedPet();
    _setBackgroundImage();
    _startBackgroundSound(widget.sound);

    // 🔽 Ses ismini çözümle ve dropdown için hazırla
    _resolveSoundName(widget.sound);
    _startTimer();
  }

  Future<void> _resolveSoundName(String soundUrlOrAsset) async {
    if (soundUrlOrAsset.startsWith('http')) {
      final snapshot = await FirebaseFirestore.instance.collectionGroup("music_wind").get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'];
        final assetUrl = data['assetUrl'];
        final asset = data['asset'];

        if (assetUrl == soundUrlOrAsset || asset == soundUrlOrAsset) {
          setState(() {
            _currentSound = name;
          });
          return;
        }
      }

      // eşleşme yoksa fallback
      setState(() {
        _currentSound = 'Bilinmeyen';
      });
    } else if (soundUrlOrAsset.startsWith('assets/')) {
      final name = _getNameFromAssetPath(soundUrlOrAsset);
      setState(() {
        _currentSound = name;
      });
    } else {
      // zaten isim verilmiş
      setState(() {
        _currentSound = soundUrlOrAsset;
      });
    }
  }

  String _getNameFromAssetPath(String assetPath) {
    final fileName = assetPath.split('/').last;
    return fileName.replaceAll('.mp3', '').replaceAll('_', ' ').capitalize();
  }



  Future<Widget> _buildAssetWidget(String? asset, String? assetUrl) async {
    try {
      if (assetUrl != null && assetUrl.contains('.json')) {
        debugPrint("🌐 Uzak Lottie animasyonu yüklenecek: $assetUrl");
        final response = await http.get(Uri.parse(assetUrl));
        if (response.statusCode == 200) {
          return Lottie.memory(
            response.bodyBytes,
            width: 160,
            height: 160,
            fit: BoxFit.contain,
          );
        } else {
          debugPrint("Lottie HTTP yükleme hatası: ${response.statusCode}");
          return const Icon(Icons.broken_image);
        }
      } else if (asset != null && asset.endsWith('.json')) {
        debugPrint("📦 Yerel Lottie animasyonu yüklenecek: $asset");
        return Lottie.asset(
          asset,
          width: 160,
          height: 160,
          fit: BoxFit.contain,
        );
      } else if (assetUrl != null && (assetUrl.endsWith('.png') || assetUrl.endsWith('.jpg') || assetUrl.endsWith('.jpeg'))) {
        debugPrint("🖼️ Uzak görsel yüklenecek: $assetUrl");
        return Image.network(
          assetUrl,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("Görsel yüklenemedi: $error");
            return const Icon(Icons.broken_image);
          },
        );
      } else if (asset != null && (asset.endsWith('.png') || asset.endsWith('.jpg') || asset.endsWith('.jpeg'))) {
        debugPrint("📦 Yerel görsel yüklenecek: $asset");
        return Image.asset(
          asset,
          width: 160,
          height: 160,
          fit: BoxFit.cover,
        );
      } else {
        debugPrint("❗ Desteklenmeyen asset: $asset / $assetUrl");
        return const Icon(Icons.image_not_supported);
      }
    } catch (e) {
      debugPrint("ASSET WIDGET EXCEPTION: $e");
      return const Icon(Icons.broken_image);
    }
  }

  Future<Widget> _loadPetWidget() async {
    final asset = _selectedPetAsset;
    final cleanAsset = asset.split('?').first; // 🔥 sadece uzantıyı kontrol et

    if (cleanAsset.endsWith('.json')) {
      if (asset.startsWith('http')) {
        return _buildAssetWidget(null, asset);
      } else {
        return _buildAssetWidget(asset, null);
      }
    } else if (cleanAsset.endsWith('.png') || cleanAsset.endsWith('.jpg') || cleanAsset.endsWith('.jpeg')) {
      if (asset.startsWith('http')) {
        return _buildAssetWidget(null, asset);
      } else {
        return _buildAssetWidget(asset, null);
      }
    } else {
      debugPrint("⚠️ Gerçek uzantı belirlenemedi: $cleanAsset");
      return const Icon(Icons.image_not_supported);
    }
  }

  Widget _buildPetAnimation() {
    return FutureBuilder<Widget>(
      future: _petWidgetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError || !snapshot.hasData) {
          return const Icon(Icons.broken_image, size: 120);
        } else {
          return SizedBox(width: 160, height: 160, child: snapshot.data!);
        }
      },
    );
  }

  void _fetchSelectedPet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final selectedPetId = userDoc.data()?['selectedPet'];

    if (selectedPetId != null) {
      final query = await FirebaseFirestore.instance.collectionGroup('pet_fox').get();
      for (final doc in query.docs) {
        if (doc.id == selectedPetId) {
          final data = doc.data();
          final asset = data['asset'];
          final assetUrl = data['assetUrl'];

          final newAsset = assetUrl ?? asset;
          if (newAsset != null && newAsset != _selectedPetAsset) {
            debugPrint("📄 Yeni seçilen pet: $newAsset");

            setState(() {
              _selectedPetAsset = newAsset;
              _petWidgetFuture = _loadPetWidget(); // ✅ GÜNCELLENDİ
            });
          }
          debugPrint("🔥 asset: $asset");
          debugPrint("🔥 assetUrl: $assetUrl");
          debugPrint("🔥 newAsset: $newAsset");
          return;
        }
      }
    }
  }

  void _pauseMusic() async {
    await _player.pause();
    setState(() => _isMusicPlaying = false);
  }

  Future<void> _saveSession(int durationInSeconds) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);
    final sessionRef = userRef.collection("sessions");

    // 1. Session'ı kaydet
    await sessionRef.add({
      'timestamp': Timestamp.now(),
      'duration': durationInSeconds,
      'topic': widget.topic,
    });

    // 2. Kullanıcının toplam süresine ekle (güvenli biçimde)
    await userRef.update({
      'totalWorkSeconds': FieldValue.increment(durationInSeconds),
    });
  }

  String _getSoundFileName(String sound) {
    return sound.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('ı', 'i') + ".mp3";
  }

  void _setBackgroundImage() {
    if (widget.background.startsWith('http')) {
      _backgroundImage = widget.background; // Firebase URL
    } else if (widget.background.startsWith('assets/')) {
      _backgroundImage = widget.background; // Local asset
    } else {
      // Geriye dönük uyumluluk için:
      final builtIn = {
        'Ev': 'assets/images/library2.jpg',
        'Kütüphane': 'assets/images/library.jpg',
        'Orman': 'assets/images/orman.jpg',
        'Gece Orman': 'assets/images/orman2.jpg',
        'Kumsal': 'assets/images/kumsal.jpg',
      };
      _backgroundImage = builtIn[widget.background] ?? 'assets/images/default.jpg';
    }
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _isRunning = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning) return;

      final elapsed = DateTime.now().difference(_startTime).inSeconds;
      setState(() {
        _seconds = elapsed;

        if (_seconds > 0 && _seconds % 1200 == 0) {
          _showDream = true;
        }
      });
    });
  }


  void _onCatPet() async {
    if (!_showDream) return; // sadece rüyadayken
    setState(() => _showDream = false);

    // Ses çal
    _effectPlayer.play(AssetSource("sounds/mrr.mp3"));

    // Coin animasyonu göster
    setState(() => _showCoin = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _showCoin = false);

    // Firestore’a 1 coin ekle
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseFirestore.instance.collection("users").doc(user.uid);
        await userRef.update({
          "coins": FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint("Coin eklenemedi: $e");
    }
  }

  void _toggleTimer() {
    setState(() => _isRunning = !_isRunning);
    if (_isRunning) {
      _startTime = DateTime.now().subtract(Duration(seconds: _seconds));
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }


  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF7f32a8),
        title: const Text("Çıkmak istiyor musunuz?", style: TextStyle(color: Colors.white)),
        content: const Text("Çalışma oturumunu durdurmak üzeresiniz.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              _player.stop();
              _isRunning = false;

              // 🔥 Session kaydet
              await _saveSession(_seconds);

              if (mounted) {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // sayfa
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text("Çık", style: TextStyle(color: Color(0xFF7f32a8))),
          ),
        ],
      ),
    );
  }

  void _resumeMusic() async {
    await _player.resume();
    setState(() => _isMusicPlaying = true);
  }

  String toUpperCaseTr(String input) {
    return input
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ç', 'Ç')
        .replaceAll('ş', 'Ş')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ö', 'Ö')
        .toUpperCase(); // İngilizce karakterleri de büyük yapar
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    _effectPlayer.dispose();
    _isRunning = false;
    super.dispose();
  }


  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  Future<List<String>> _fetchAvailableSounds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final List<String> customSounds = List<String>.from(userDoc.data()?['customSounds'] ?? []);
    final List<String> ownedItemIds = List<String>.from(userDoc.data()?['ownedItems'] ?? []);

    // Marketten alınan sesleri çek
    final snapshot = await FirebaseFirestore.instance.collectionGroup("music_wind").get();

    final ownedMarketSounds = snapshot.docs.where((doc) => ownedItemIds.contains(doc.id)).map((doc) {
      final data = doc.data();
      return data['name'] as String? ?? 'Bilinmeyen';
    }).toList();

    // Varsayılan sesler
    const defaultSounds = [
      'Yağmur',
      'Yazma',
      'Sessizlik',
      'Kütüphane',
    ];

    return [...defaultSounds, ...ownedMarketSounds, ...customSounds];
  }

  Future<void> _startBackgroundSound(String sound) async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);

      if (sound.startsWith('http')) {
        // 🔹 Firebase Storage URL
        await _player.play(UrlSource(sound));
      } else if (sound.contains('firebase')) {
        // 🔹 Bazı URL'ler http yazmadan geliyor olabilir
        await _player.play(UrlSource('https://$sound'));
      } else if (sound.contains('/')) {
        // 🔹 assets yolu gönderildiyse
        await _player.play(AssetSource(sound.replaceFirst('assets/', '')));
      } else {
        // 🔹 isim geldiyse, dönüştür ve asset çal
        String fileName = _getSoundFileName(sound);
        await _player.play(AssetSource('sounds/$fileName'));
      }

      _isMusicPlaying = true;
    } catch (e) {
      debugPrint("Ses çalma hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _backgroundImage.startsWith('http')
              ? Image.network(_backgroundImage, fit: BoxFit.cover)
              : Image.asset(_backgroundImage, fit: BoxFit.cover),

          Container(color: Colors.black.withOpacity(0.4)),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                toUpperCaseTr(widget.topic),
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _formatTime(_seconds),
                  style: const TextStyle(fontSize: 48, color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<List<String>>(
                future: _fetchAvailableSounds(), // bunu aşağıda tanımlıyoruz
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: Lottie.asset('assets/lottie/hourglass.json', width: 120));
                  }
                  final soundOptions = snapshot.data!;
                  final uniqueOptions = <String>[];
                  final seen = <String>{};

                  for (final sound in soundOptions) {
                    if (!seen.contains(sound)) {
                      seen.add(sound);
                      uniqueOptions.add(sound);
                    }
                  }

// Eğer _currentSound uniqueOptions içinde yoksa, null olarak ayarla ki hata vermesin
                  if (!uniqueOptions.contains(_currentSound)) {
                    setState(() {
                      _currentSound = uniqueOptions.isNotEmpty ? uniqueOptions.first : '';
                    });
                  }
                  return Column(
                    children: [
                      const Text("Müzik Seç:", style: TextStyle(color: Colors.white)),
                      DropdownButton<String>(
                        dropdownColor: Colors.deepPurple,
                        value: _currentSound, // ilk yükleneni seçili göster
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        items: uniqueOptions.map((sound) {
                          return DropdownMenuItem<String>(
                            value: sound,
                            child: Text(sound, style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                          onChanged: (newSound) async {
                            if (newSound == null) return;
                            await _player.stop();

                            setState(() {
                              _currentSound = newSound;
                            });

                            // 🔥 Eğer bu bir özel sesse, assetUrl ile çöz
                            final uid = FirebaseAuth.instance.currentUser?.uid;
                            final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
                            final owned = List<String>.from(userDoc.data()?['ownedItems'] ?? []);

                            final snapshot = await FirebaseFirestore.instance.collectionGroup("music_wind").get();

                            for (final doc in snapshot.docs) {
                              if (doc.data()['name'] == newSound && owned.contains(doc.id)) {
                                final url = doc.data()['assetUrl'] ?? doc.data()['asset'];
                                if (url != null) {
                                  _startBackgroundSound(url);
                                  return;
                                }
                              }
                            }

                            // Yoksa default fallback
                            _startBackgroundSound(newSound);
                          }
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleTimer,
                    icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(_isRunning ? "Durdur" : "Başlat"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7f32a8),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showExitDialog,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text("Çık"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Text(
                    "Çalan müzik: $_currentSound",
                    style: const TextStyle(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: _isMusicPlaying ? _pauseMusic : _resumeMusic,
                    child: Text(
                      _isMusicPlaying ? "Müziği Durdur" : "Müziği Devam Ettir",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )

            ],
          ),
          // Kedili animasyon + coin
          Positioned(
            bottom: 20,
            left: MediaQuery.of(context).size.width / 2 - 80,
            child: GestureDetector(
              onTap: _onCatPet,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildPetAnimation(),
                  if (_showDream)
                    Positioned(
                      top: 0,
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: Lottie.asset('assets/lottie/dream.json'),
                      ),
                    ),
                  if (_showCoin)
                    Positioned(
                      bottom: 0,
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Lottie.asset('assets/lottie/coin.json'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension CapExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
