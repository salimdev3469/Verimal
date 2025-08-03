import 'package:flutter/material.dart';
import 'package:verimal/screens/details_page.dart';
import 'package:verimal/dialogs/start_work_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<HourlyWorkData> _hourlyData = [];
  bool _isChartLoading = true;
  bool _isFirstLoad = true;


  @override
  void initState() {
    super.initState();
    _fetchHourlyWorkData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (ModalRoute.of(context)?.isCurrent ?? false) {
      if (_isFirstLoad) {
        _isFirstLoad = false;
      } else {
        // Sayfaya geri dönüldüğünde yeniden fetch et
        _fetchHourlyWorkData();
        setState(() {}); // Pie chart ve diğer FutureBuilder'ları da yenilemek için
      }
    }
  }


  Future<void> _fetchHourlyWorkData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final from = now.subtract(const Duration(hours: 24));
    final ref = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("sessions");

    final snapshot = await ref.where("timestamp", isGreaterThan: from).get();

    Map<int, double> hourMap = {};
    for (var doc in snapshot.docs) {
      final date = (doc['timestamp'] as Timestamp).toDate();
      final hour = date.hour;
      final duration = (doc['duration'] ?? 0) as int;
      hourMap[hour] = (hourMap[hour] ?? 0) + (duration / 60); // dakikaya çevir
    }

    List<HourlyWorkData> data = List.generate(24, (i) {
      final h = (now.subtract(Duration(hours: 23 - i)).hour) % 24;
      return HourlyWorkData("${h.toString().padLeft(2, '0')}:00", hourMap[h] ?? 0);
    });

    setState(() {
      _hourlyData = data;
      _isChartLoading = false;
    });
  }

  String formatDuration(double minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = (minutes % 60).toStringAsFixed(1);

    if (hours > 0) {
      if (remainingMinutes == '0.0') {
        return "$hours sa";
      } else {
        return "$hours sa $remainingMinutes dk";
      }
    } else {
      return "$remainingMinutes dk";
    }
  }

  Future<List<MapEntry<String, double>>> _fetchTodayTopicDurations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];

    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));

    final snapshot = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("sessions")
        .where("timestamp", isGreaterThanOrEqualTo: last24h)
        .get();

    final Map<String, double> topicDurations = {};
    for (var doc in snapshot.docs) {
      final topic = doc['topic'] ?? 'Bilinmeyen';
      final durationSec = (doc['duration'] ?? 0).toDouble();
      topicDurations[topic] = (topicDurations[topic] ?? 0) + durationSec;
    }

    // saniyeyi dakikaya ondalıklı çevir
    return topicDurations.entries
        .map((e) => MapEntry(e.key, e.value / 60))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }



  Widget buildDailyPieChart() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final now = DateTime.now();
    final last24h = now.subtract(const Duration(hours: 24));

    final stream = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("sessions")
        .where("timestamp", isGreaterThanOrEqualTo: last24h)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: Lottie.asset('assets/lottie/hourglass.json', width: 120));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text("   Son 24 saatte çalışma verisi bulunamadı.");
        }

        final Map<String, double> topicDurations = {};
        for (var doc in docs) {
          final topic = doc['topic'] ?? 'Bilinmeyen';
          final durationSec = (doc['duration'] ?? 0).toDouble();
          topicDurations[topic] = (topicDurations[topic] ?? 0) + durationSec;
        }

        final entries = topicDurations.entries
            .map((e) => MapEntry(e.key, e.value / 60))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final totalMinutes = entries.fold<double>(0, (sum, e) => sum + e.value);

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart, color: Color(0xFF7f32a8)),
                    SizedBox(width: 8),
                    Text(
                      "Son 24 Saat İş Dağılımı",
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SfCircularChart(
                  legend: const Legend(isVisible: true),
                  series: <DoughnutSeries<MapEntry<String, double>, String>>[
                    DoughnutSeries<MapEntry<String, double>, String>(
                      dataSource: entries,
                      xValueMapper: (entry, _) => entry.key,
                      yValueMapper: (entry, _) => entry.value,
                      pointColorMapper: (entry, _) =>
                          generateDistinctColorFromString(entry.key),
                      dataLabelMapper: (entry, _) =>
                      "${(entry.value / totalMinutes * 100).toStringAsFixed(0)}%",
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        textStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      radius: '80%',
                      innerRadius: '55%',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...entries.map((e) {
                  final color = generateDistinctColorFromString(e.key);
                  final percent = ((e.value / totalMinutes) * 100).toStringAsFixed(1);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(e.key, style: const TextStyle(fontSize: 15)),
                        ),
                        Text(
                          "$percent%  •  ${formatDuration(e.value.toDouble())}",
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _fetchFavoriteTopic() async {
    final topics = await _fetchTodayTopicDurations();
    if (topics.isEmpty) return 'Yok';
    return topics.first.key;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
        title: Image.asset(
          'assets/images/verimalWhite.png',
          width: 140,
          height: 120,
          fit: BoxFit.contain,
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: Lottie.asset('assets/lottie/hourglass.json', width: 120));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = userData['name'] ?? '';
          final totalSeconds = userData['totalWorkSeconds'] ?? 0;
          final level = (totalSeconds / 28800).floor().toString();
          final totalHours = (totalSeconds / 3600).floor().toString();
          final ownedItems = List<String>.from(userData['ownedItems'] ?? []);
          final petCount = ownedItems.where((id) => id.startsWith('pet_')).length.toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Image.asset("assets/images/person.png", width: 35),
                  const SizedBox(width: 5),
                  Text(name, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatChip(
                        label: " Level $level",
                        assetPath: 'assets/images/level.png',
                        backgroundColor: const Color(0xFFE0D4F5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection("users")
                            .doc(FirebaseAuth.instance.currentUser?.uid)
                            .collection("sessions")
                            .where("timestamp", isGreaterThanOrEqualTo: DateTime.now().subtract(const Duration(days: 1)))
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return StatChip(
                              label: "Favorin: Yükleniyor...",
                              assetPath: 'assets/images/tick.png',
                              backgroundColor: const Color(0xFFF8D9E0),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          if (docs.isEmpty) {
                            return StatChip(
                              label: "Favorin: Yok",
                              assetPath: 'assets/images/tick.png',
                              backgroundColor: const Color(0xFFF8D9E0),
                            );
                          }

                          final Map<String, double> topicDurations = {};

                          for (var doc in docs) {
                            final topic = doc['topic'] ?? 'Bilinmeyen';
                            final duration = (doc['duration'] ?? 0).toDouble();

                            topicDurations[topic] = (topicDurations[topic] ?? 0) + duration;
                          }

                          String favoriteTopic = 'Yok';
                          if (topicDurations.isNotEmpty) {
                            favoriteTopic = topicDurations.entries
                                .reduce((a, b) => a.value > b.value ? a : b)
                                .key;
                          }

                          return StatChip(
                            label: " Favorin: $favoriteTopic",
                            assetPath: 'assets/images/tick.png',
                            backgroundColor: const Color(0xFFF8D9E0),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatChip(
                        label: " Pet Sayısı: $petCount",
                        assetPath: 'assets/images/pet.png',
                        backgroundColor: const Color(0xFFDFF4E5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatChip(
                        label: " Toplam: $totalHours saat",
                        assetPath: 'assets/images/clock.png',
                        backgroundColor: const Color(0xFFFBE7C6),
                      ),
                    ),
                  ],
                ),
                Image.asset("assets/images/quote.png"),
                const SizedBox(height: 12),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const StartWorkDialog(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Çalışmaya Başla !",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bar_chart),
                    label: const Text(
                      "Detaylı İstatistikleri Görüntüle",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7f32a8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                buildDailyPieChart(),
                const SizedBox(height: 24),
                if (_isChartLoading)
                  Center(child: Lottie.asset('assets/lottie/hourglass.json', width: 120))
                else
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timelapse, color: Color(0xFF7f32a8)),
                              SizedBox(width: 8),
                              Text(
                                "Son 24 Saat Oturumları",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 280,
                            child: SfCartesianChart(
                              backgroundColor: Colors.white,
                              plotAreaBorderWidth: 0,
                              tooltipBehavior: TooltipBehavior(
                                enable: true,
                                format: 'Saat: point.x\nSüre: point.y dk',
                              ),
                              primaryXAxis: CategoryAxis(
                                labelRotation: -45,
                                majorGridLines: const MajorGridLines(width: 0),
                                labelStyle: const TextStyle(fontSize: 12),
                                title: AxisTitle(
                                  text: "Saat",
                                  textStyle: TextStyle(color: Colors.black54),
                                ),
                              ),
                              primaryYAxis: NumericAxis(
                                minimum: 0,
                                labelFormat: '{value} dk',
                                axisLine: const AxisLine(width: 0),
                                majorGridLines: const MajorGridLines(width: 0.5),
                                labelStyle: const TextStyle(fontSize: 12),
                                title: AxisTitle(
                                  text: "Çalışma Süresi",
                                  textStyle: TextStyle(color: Colors.black54),
                                ),
                              ),
                              series: <CartesianSeries>[
                                ColumnSeries<HourlyWorkData, String>(
                                  dataSource: _hourlyData
                                      .where((d) => d.durationInMinutes > 0)
                                      .toList(),
                                  xValueMapper: (data, _) => data.hour,
                                  yValueMapper: (data, _) => double.parse(data.durationInMinutes.toStringAsFixed(1)),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF7f32a8), Color(0xFFb45eff)],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.top,
                                    textStyle: TextStyle(color: Colors.black, fontSize: 13),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 34),
              ],
            ),
          );

        },
      ),

    );
  }

  final List<Color> _vibrantColorPalette = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.indigoAccent,
    Colors.cyanAccent,
    Colors.amberAccent,
    Colors.deepOrangeAccent,
    Colors.lightGreenAccent,
    Colors.deepPurpleAccent,
    Colors.limeAccent,
    Colors.yellowAccent,
    Colors.brown,
    Colors.blueGrey,
    Color(0xFF00BFA5), // Turkuaz
    Color(0xFFFF6D00), // Parlak turuncu
    Color(0xFFAA00FF), // Parlak mor
    Color(0xFF00C853), // Canlı yeşil
    Color(0xFF6200EA), // Koyu mor
    Color(0xFFFF1744), // Pembe kırmızı
    Color(0xFF1DE9B6), // Nane yeşili
    Color(0xFF3D5AFE), // Parlak mavi
    Color(0xFFFFEA00), // Parlak sarı
  ];

  Color generateDistinctColorFromString(String input) {
    final hash = input.codeUnits.fold(0, (prev, curr) => (prev + curr)) % _vibrantColorPalette.length;
    return _vibrantColorPalette[hash];
  }

  Future<Map<String, dynamic>> _getUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final userDoc = await FirebaseFirestore.instance.collection("users").doc(uid).get();
    final userData = userDoc.data() ?? {};
    final ownedItems = List<String>.from(userData['ownedItems'] ?? []);

    final sessions = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("sessions")
        .get();

    final Map<String, num> topicDurations = {};
    for (var doc in sessions.docs) {
      final topic = doc['topic'] ?? 'Bilinmeyen';
      final duration = doc['duration'] as num;
      topicDurations[topic] = (topicDurations[topic] ?? 0) + duration;
    }

    String favoriteTopic = 'Yok';
    if (topicDurations.isNotEmpty) {
      final sorted = topicDurations.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      favoriteTopic = sorted.first.key;
    }

    final totalSeconds = userData['totalWorkSeconds'] ?? 0;
    final level = (totalSeconds / 28800).floor();

    final petQuery = await FirebaseFirestore.instance.collectionGroup('pet_fox').get();
    int petCount = 0;
    for (var doc in petQuery.docs) {
      if (ownedItems.contains(doc.id)) {
        petCount++;
      }
    }

    return {
      'name': userData['name'] ?? '',
      'level': level,
      'favorite': favoriteTopic,
      'petCount': petCount,
      'totalHours': (totalSeconds / 3600).floor(),
    };
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF7f32a8)),
            child: Center(
              child: Image.asset(
                'assets/images/verimalWhite.png',
                width: 220,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profilim"),
            onTap: () {
              Navigator.pop(context); // önce drawer'ı kapat
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text("Market"),
            onTap: () {
              Navigator.pop(context); // önce drawer'ı kapat
              Navigator.pushNamed(context, '/market');
            },
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text("Lider Tablosu"),
            onTap: () {
              Navigator.pop(context); // önce drawer'ı kapat
              Navigator.pushNamed(context, '/leaderboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.flag),
            title: const Text("Hedefler Listesi"),
            onTap: () {
              Navigator.pop(context); // önce drawer'ı kapat
              Navigator.pushNamed(context, '/goals');
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text("Envanter"),
            onTap: () {
              Navigator.pop(context); // önce drawer'ı kapat
              Navigator.pushNamed(context, '/inventory');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Çıkış Yap"),
            onTap: () async {
              Navigator.pop(context); // önce drawer'ı kapat
              await FirebaseAuth.instance.signOut();
              if (context.mounted){
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) =>false);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail),
            title: const Text("Bize Ulaşın"),
            onTap: () {
              Navigator.pop(context); // önce drawer'ı kapat
              Navigator.pushNamed(context, '/contact');
            },
          ),
        ],
      ),
    );
  }
}

class StatChip extends StatelessWidget {
  final String label;
  final String assetPath;
  final Color backgroundColor;

  const StatChip({
    super.key,
    required this.label,
    required this.assetPath,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Image.asset(assetPath, fit: BoxFit.cover),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class HourlyWorkData {
  final String hour;
  final double durationInMinutes;

  HourlyWorkData(this.hour, this.durationInMinutes);
}