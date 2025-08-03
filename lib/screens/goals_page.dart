import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final TextEditingController _goalController = TextEditingController();
  DateTime? _selectedDate;

  Future<void> _addGoal() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _goalController.text.trim().isEmpty || _selectedDate == null) return;

    await FirebaseFirestore.instance.collection("users").doc(uid).collection("goals").add({
      "title": _goalController.text.trim(),
      "date": _selectedDate,
      "done": false,
      "createdAt": FieldValue.serverTimestamp(),
    });

    _goalController.clear();
    _selectedDate = null;
    Navigator.of(context).pop();
  }

  Future<void> _deleteGoal(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection("users").doc(uid).collection("goals").doc(id).delete();
  }

  Future<void> _toggleGoal(String id, bool newValue) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection("users").doc(uid).collection("goals").doc(id).update({
      "done": newValue,
    });
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFf9f5ff),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Yeni Hedef", style: TextStyle(color: Color(0xFF7f32a8))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _goalController,
                decoration: const InputDecoration(
                  labelText: "Hedef Başlığı",
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7f32a8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _selectedDate != null
                      ? DateFormat("dd MMMM yyyy", "tr").format(_selectedDate!)
                      : "Tarih Seç",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7f32a8),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: _addGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Giriş yapmalısınız."));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hedefler Listesi"),
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            onPressed: _openAddDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(uid)
            .collection("goals")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("Henüz bir hedef eklenmedi."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data["title"] ?? "Hedef";
              final isDone = data["done"] ?? false;
              final date = (data["date"] as Timestamp?)?.toDate();
              final dateText = date != null ? DateFormat("dd MMM yyyy", "tr").format(date) : "Tarih Yok";

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Checkbox(
                    value: isDone,
                    onChanged: (val) => _toggleGoal(doc.id, val ?? false),
                    activeColor: const Color(0xFF7f32a8),
                  ),
                  title: Text(title, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
                  subtitle: Text("Son Tarih: $dateText"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteGoal(doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
