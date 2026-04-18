import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../mock_data.dart';

class AccountabilitySummaryWidget extends StatelessWidget {
  final String incidentId;
  const AccountabilitySummaryWidget({Key? key, required this.incidentId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    Map<dynamic, dynamic> counts = appState.guestCounts;
    if (incidentId.startsWith('mock_')) {
      MockDataStore.generate(incidentId);
      counts = MockDataStore.counts;
    }
    
    int safe = counts['safe'] ?? 0;
    int unaccounted = counts['unaccounted'] ?? 0;
    int needsRescue = counts['needs_rescue'] ?? 0;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard('Safe', safe, Colors.green),
        _buildStatCard('Unaccounted', unaccounted, Colors.amber),
        _buildStatCard('Needs Rescue', needsRescue, Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, int value, MaterialColor color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: color, width: 6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value.toDouble()),
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Text(val.toInt().toString(), style: TextStyle(color: color[800], fontWeight: FontWeight.bold, fontSize: 36));
              },
            ),
          ],
        ),
      ),
    );
  }
}
