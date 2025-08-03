import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('contactMessages').add({
        'uid': user.uid,
        'email': user.email,
        'message': _messageController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
    }

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color:Colors.white),
        title: const Text('Bize Ulaşın',style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF7f32a8),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _messageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Mesajınızı buraya yazın...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Lütfen bir mesaj girin';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSending ? null : _sendMessage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7f32a8),
                          ),
                          icon: const Icon(Icons.send,color: Colors.white,),
                          label: _isSending
                              ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                              : const Text('Gönder',style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Divider(thickness: 1),
          Padding(padding: const EdgeInsets.only(left:10),
          child:Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text("Mesajları sola kaydırarak silebilirsiniz.", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text("Tarafınızdan Gönderilen Mesajlar", style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Giriş yapmalısınız'))
                : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('contactMessages')
                  .where('uid', isEqualTo: uid)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Henüz mesajınız yok."));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      return Dismissible(
                        key: Key(doc.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await doc.reference.delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mesaj silindi'),duration:Duration(seconds: 2)),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            title: Text(data['message'] ?? ''),
                            subtitle: Text(
                              data['timestamp'] != null
                                  ? (data['timestamp'] as Timestamp).toDate().toString()
                                  : '',
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Mesaj Detayı'),
                                  content: Text(data['message'] ?? ''),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Kapat'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }

                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
