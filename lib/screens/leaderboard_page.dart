import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2c1e3f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
        title: const Text("En Çalışkan 20 Üye"),
      ),
      body: Column(
        children: [

          Center(
            child: Image.asset(
              'assets/images/ribbon.png',
              height: 180,
              fit: BoxFit.contain,
            ),
          ),

          Expanded(
            child:FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .orderBy("totalWorkSeconds", descending: true)
                  .limit(20)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Hiç kullanıcı verisi bulunamadı."));
                }

                final users = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = user['name'] ?? 'İsimsiz';

                    final rawSeconds = user.data().toString().contains('totalWorkSeconds')
                        ? user['totalWorkSeconds']
                        : 0;

                    final seconds = rawSeconds is int
                        ? rawSeconds
                        : (rawSeconds is String ? int.tryParse(rawSeconds) ?? 0 : 0);

                    final level = (seconds / 28800).floor();
                    final hours = seconds ~/ 3600;
                    final minutes = (seconds % 3600) ~/ 60;

                    final photoUrl = user.data().toString().contains('photoUrl')
                        ? user['photoUrl']
                        : null;

                    final isTop = index == 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isTop
                            ? Colors.amber[200]
                            : Colors.blueGrey[100 + (index % 4) * 100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : const AssetImage('assets/images/default_profile.jpg')
                            as ImageProvider,
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16)),
                                Text("Seviye: $level  Süre: ${hours}sa ${minutes}dk"),
                              ],
                            ),
                          ),
                          if (isTop)
                            const Icon(Icons.emoji_events,
                                color: Colors.orange, size: 30)
                          else
                            Text("#${index + 1}",
                                style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
