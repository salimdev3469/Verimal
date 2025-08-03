import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  int _coin = 0;
  List<String> _ownedItems = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final data = snapshot.data();
    if (data == null) return;

    setState(() {
      _coin = data['coins'] ?? 0;
      _ownedItems = List<String>.from(data['ownedItems'] ?? []);
    });
  }

  Future<void> _buyItem(BuildContext context, String itemId, int cost, String type) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);
    final userSnapshot = await userRef.get();
    final currentCoins = userSnapshot.data()?['coins'] ?? 0;

    if (currentCoins >= cost) {
      await userRef.update({
        'coins': FieldValue.increment(-cost),
        'ownedItems': FieldValue.arrayUnion([itemId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Satın alma başarılı!"),duration:Duration(seconds: 2)),
      );

      await _loadUserData(); // satın alma sonrası coin ve ownedItems güncelle
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Yetersiz coin!"),duration:Duration(seconds: 2)),
      );
    }
  }


  Future<Widget> _buildAssetWidget(Map<String, dynamic> data) async {
    final asset = data['asset'];
    final assetUrl = data['assetUrl'];

    try {
      if (asset != null && asset.toString().endsWith('.json')) {
        debugPrint("Lottie asset yüklendi: $asset");
        return Lottie.asset(
          asset,
          width: 150,
          height: 100,
          fit: BoxFit.contain,
        );
      } else if (assetUrl != null && assetUrl.toString().contains('.json')) {
        debugPrint("Lottie URL'den yüklenecek: $assetUrl");
        final response = await http.get(Uri.parse(assetUrl));
        if (response.statusCode == 200) {
          return Lottie.memory(
            response.bodyBytes,
            width: 180,
            height: 120,
            fit: BoxFit.contain,
          );
        } else {
          debugPrint("Lottie yüklenemedi, HTTP durum: ${response.statusCode}");
          return const Icon(Icons.broken_image);
        }
      } else if (assetUrl != null) {
        debugPrint("Görsel yüklenecek: $assetUrl");
        return Image.network(
          assetUrl,
          width: 180,
          height: 130,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("Görsel yüklenemedi: $error");
            return const Icon(Icons.broken_image);
          },
        );
      } else if (asset != null) {
        debugPrint("Yerel görsel yüklenecek: $asset");
        return Image.asset(
          asset,
          width: 160,
          height: 120,
          fit: BoxFit.cover,
        );
      } else {
        debugPrint("Desteklenmeyen format: asset: $asset, assetUrl: $assetUrl");
        return const Icon(Icons.image_not_supported, size: 100);
      }
    } catch (e) {
      debugPrint("ASSET ERROR: $e");
      return const Icon(Icons.broken_image);
    }
  }

  Widget _buildItemCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final name = data['name'] ?? 'İsimsiz Ürün';
    final cost = data['cost'] ?? 0;
    final id = doc.id;
    final alreadyOwned = _ownedItems.contains(id);

    return FutureBuilder<Widget>(
      future: _buildAssetWidget(data),
      builder: (context, snapshot) {
        Widget assetWidget;

        if (snapshot.connectionState == ConnectionState.waiting) {
          assetWidget = Lottie.asset(
            'assets/lottie/hourglass.json', // varsa özel bir Lottie animasyonu kullan
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          );
        } else if (snapshot.hasError) {
          assetWidget = const Icon(Icons.broken_image, size: 80);
        } else {
          assetWidget = snapshot.data ?? const SizedBox(height: 100);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      height: constraints.maxHeight * 0.45,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: assetWidget,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text("💰 $cost coin", style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: alreadyOwned
                          ? const Text(
                        "Zaten Sahipsiniz",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      )
                          : ElevatedButton(
                        onPressed: () => _buyItem(context, id, cost, data['type']),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7f32a8),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Satın Al", style: TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mağaza"),
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              avatar: const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
              label: Text("$_coin", style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xff520075),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 8),
                Expanded(
                  child: Text("Coin kazanmak için çok çalışmalısın! Çalıştıkça coinlerin hesabına aktarılır. Çalışırken evcil hayvanlarını sevmeyi unutma. Böylece daha çok coin kazanabilirsin !", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text("🎵 Sesler", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collectionGroup("music_wind").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final name = data['name'] ?? "İsimsiz Ürün";
                    final cost = data['cost'] ?? 0;
                    final id = doc.id;
                    final alreadyOwned = _ownedItems.contains(id);

                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(name),
                        subtitle: Text("💰 $cost coin"),
                        trailing: alreadyOwned
                            ? const Text("Zaten Sahipsiniz", style: TextStyle(color: Colors.grey))
                            : ElevatedButton(
                          onPressed: () => _buyItem(context, id, cost, data['type']),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7f32a8)),
                          child: const Text("Satın Al", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),
            const Text("🖼️ Arka Planlar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collectionGroup("backgrounds").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    return _buildItemCard(docs[index]);
                  },
                );
              },
            ),

            const SizedBox(height: 12),
            const Text("🐾 Sanal Hayvanlar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collectionGroup("pet_fox").snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    return _buildItemCard(docs[index]);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}