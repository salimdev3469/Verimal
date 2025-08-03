import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  final List<String> _tabs = ['Hafta', 'Ay', 'Yıl', 'Tüm Zamanlar'];
  int _selectedIndex = 0;

  bool _loading = true;

  Map<String, double> topicDurations = {};
  Map<String, double> timeSeriesData = {};
  Map<int, int> hourlyDistribution = {};
  Map<int, double> _allTimeMonthTotals = {}; // 🔁 yeni eklendi

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
      _loading = true;
    });
    _fetchData();
  }

  Widget _buildAllTimeRibbon() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Image.asset(
          'assets/images/ribbon_stats.png',
          height: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Future<void> _fetchData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    late DateTime fromDate;

    switch (_selectedIndex) {
      case 0:
        fromDate = now.subtract(const Duration(days: 7));
        break;
      case 1:
        fromDate = DateTime(now.year, now.month, 1); // Ayın ilk günü
        break;
      case 2:
        fromDate = now.subtract(const Duration(days: 360));
        break;
      default:
        fromDate = DateTime(2000);
    }

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .where('timestamp', isGreaterThanOrEqualTo: fromDate)
        .get();

    Map<String, double> perTopic = {};
    Map<String, double> perTime = {};
    Map<int, int> perHour = {};
    Map<int, double> perMonth = {}; // 🔁 yeni

    for (final doc in query.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final topic = data['topic'] ?? 'Bilinmeyen';
      final durationSec = data['duration'] ?? 0;
      final durationMin = durationSec / 60;

      perTopic[topic] = (perTopic[topic] ?? 0) + durationMin;

      String key;
      if (_selectedIndex == 0) {
        key = _weekdayStr(timestamp.weekday);
      } else if (_selectedIndex == 1) {
        final weekIndex = ((timestamp.day - 1) * 4 / DateUtils.getDaysInMonth(timestamp.year, timestamp.month)).floor() + 1;
        key = '$weekIndex. Hafta';
      } else if (_selectedIndex == 2) {
        key = _monthName(timestamp.month);
      } else {
        key = 'Tümü';
        // 🔁 Ay toplamlarını doldur
        final month = timestamp.month;
        perMonth[month] = (perMonth[month] ?? 0) + durationMin;
      }

      perTime[key] =
          (perTime[key] ?? 0) + durationMin / (_selectedIndex == 2 ? 60 : 1);

      // 🔁 Saat dağılımı (7 gün + tüm zamanlar)
      if (_selectedIndex == 0 || _selectedIndex == 3) {
        final hour = timestamp.hour;
        perHour[hour] = ((perHour[hour] ?? 0) + durationMin).toInt();
      }
    }

    final sortedMap = Map.fromEntries(
      perTime.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    setState(() {
      topicDurations = perTopic;
      timeSeriesData = sortedMap;
      hourlyDistribution = perHour;
      _allTimeMonthTotals = perMonth; // 🔁
      _loading = false;
    });
  }

  String _weekdayStr(int day) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[day - 1];
  }

  String _monthName(int month) {
    const months = [
      "Ocak",
      "Şubat",
      "Mart",
      "Nisan",
      "Mayıs",
      "Haziran",
      "Temmuz",
      "Ağustos",
      "Eylül",
      "Ekim",
      "Kasım",
      "Aralık",
    ];
    return months[month - 1];
  }

  Color _generateColor(String input) {
    final hash = input.codeUnits.fold(0, (a, b) => a + b);
    final hue = (hash * 137) % 360;
    return HSLColor.fromAHSL(1.0, hue.toDouble(), 0.85, 0.45).toColor();
  }

  String _formatTime(double value, {bool hourFormat = false}) {
    final h = value ~/ 60;
    final m = value % 60;
    return hourFormat
        ? "${h}sa ${m.toStringAsFixed(1)}dk"
        : "${value.toStringAsFixed(1)}dk";
  }

  String _formatTotalDuration(double duration, {required bool isYear}) {
    final totalMinutes = isYear ? duration * 60 : duration;
    final hours = totalMinutes ~/ 60;
    final minutes = (totalMinutes % 60).round();
    if (hours > 0 && minutes > 0) return "${hours}sa ${minutes}dk";
    if (hours > 0) return "${hours}sa";
    return "${minutes}dk";
  }

  String _getMostFrequentHour(Map<int, int> hourMap) {
    if (hourMap.isEmpty) return "-";
    final top = hourMap.entries.reduce((a, b) => a.value > b.value ? a : b);
    return "${top.key.toString().padLeft(2, '0')}:00";
  }

  Widget _buildAllTimeInsights() {
    if (topicDurations.isEmpty) return const SizedBox();

    final topTopic = topicDurations.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final mostHour = _getMostFrequentHour(hourlyDistribution);

    String mostMonthName = "Tümü";
    if (_allTimeMonthTotals.isNotEmpty) {
      final maxMonth = _allTimeMonthTotals.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      mostMonthName = _monthName(maxMonth);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 1, right: 1),
      child: Column(
        children: [
          Row(
          children: [
            Image.asset("assets/images/star.png", width: 45),
            Text(
              "En çok çalıştığın iş: $topTopic",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],),

          const SizedBox(height: 12),
          Row(
            children: [
              Image.asset("assets/images/star.png", width: 45),
              Text(
                "En çok odaklandığın saat: $mostHour",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Image.asset("assets/images/star.png", width: 45),
              Text(
                "En yoğun ayın: $mostMonthName",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 66),
        ],
      ),

    );
  }

  Widget _buildBarChart() {
    final isYear = _selectedIndex == 2;
    final unit = isYear ? "saat" : "dk";
    final totalDuration = timeSeriesData.values.fold(0.0, (a, b) => a + b);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1C1C1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Toplam Süre: ${_formatTotalDuration(totalDuration, isYear: isYear)}",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedIndex == 1
                  ? "Zaman Bazlı Dağılım (${_monthName(DateTime.now().month)})"
                  : "Zaman Bazlı Dağılım",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                backgroundColor: const Color(0xFF1C1C1E),
                primaryXAxis: CategoryAxis(
                  labelStyle: const TextStyle(color: Colors.white),
                  labelRotation: -45,
                ),
                primaryYAxis: NumericAxis(
                  labelStyle: const TextStyle(color: Colors.white),
                  title: AxisTitle(
                    text: unit,
                    textStyle: const TextStyle(color: Colors.white70),
                  ),
                  decimalPlaces: 1,
                ),
                series: [
                  BarSeries<MapEntry<String, double>, String>(
                    dataSource: timeSeriesData.entries.toList(),
                    xValueMapper: (e, _) => e.key,
                    yValueMapper: (e, _) =>
                        double.parse(e.value.toStringAsFixed(1)),
                    pointColorMapper: (_, __) => Colors.orange,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> generateDistinctColors(int count) {
    final List<Color> colors = [];
    final double step = 360 / count;

    for (int i = 0; i < count; i++) {
      final hue = (i * step) % 360;
      final color = HSLColor.fromAHSL(1.0, hue, 0.85, 0.45).toColor();
      colors.add(color);
    }

    return colors;
  }

  Widget _buildPieChart() {
    final total = topicDurations.values.fold(0.0, (a, b) => a + b);
    final sorted = topicDurations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final distinctColors = generateDistinctColors(sorted.length);
    final Map<String, Color> colorMap = {
      for (int i = 0; i < sorted.length; i++) sorted[i].key: distinctColors[i]
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1C1C1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "İş Dağılımı",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (total == 0)
              const Center(
                child: Text(
                  "Veri yok.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else ...[
              SfCircularChart(
                backgroundColor: const Color(0xFF1C1C1E),
                series: [
                  DoughnutSeries<MapEntry<String, double>, String>(
                    dataSource: sorted,
                    xValueMapper: (e, _) => e.key,
                    yValueMapper: (e, _) => e.value,
                    pointColorMapper: (e, _) => colorMap[e.key],
                    dataLabelMapper: (e, _) =>
                    "${(e.value / total * 100).toStringAsFixed(0)}%",
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(color: Colors.white),
                    ),
                    radius: '80%',
                    innerRadius: '55%',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...sorted.map(
                    (e) {
                  final percent = (e.value / total * 100).toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: colorMap[e.key],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          "$percent%  •  ${_formatTime(e.value, hourFormat: _selectedIndex == 2)}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: const Text('İstatistikler'),
        backgroundColor: const Color(0xFF7f32a8),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1C1C1E),
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final selected = _selectedIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabChanged(index),
                    child: Container(
                      margin: EdgeInsets.only(left:2,right:2),
                      padding: const EdgeInsets.symmetric(vertical: 8,horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.orange : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        maxLines: 1,
                        _tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
              children: [
                if (_selectedIndex == 3) _buildAllTimeRibbon(),
                if (_selectedIndex != 3) _buildBarChart(),
                const SizedBox(height: 4),
                _buildPieChart(),
                const SizedBox(height: 48),
                if (_selectedIndex == 3) _buildAllTimeInsights(),
              ],

                  ),

          ),

        ],
      ),
    );
  }
}
