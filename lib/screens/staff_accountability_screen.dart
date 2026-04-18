import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_service.dart';
import '../widgets/accountability_summary_widget.dart';
import '../app_state.dart';

class StaffAccountabilityScreen extends StatefulWidget {
  final String incidentId;
  const StaffAccountabilityScreen({Key? key, required this.incidentId}) : super(key: key);

  @override
  State<StaffAccountabilityScreen> createState() => _StaffAccountabilityScreenState();
}

class _StaffAccountabilityScreenState extends State<StaffAccountabilityScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedFloor = 0;

  void _updateStatus(String roomNumber, String status) async {
    if (widget.incidentId.isEmpty) return;
    try {
      await FirebaseDatabase.instance.ref('muster/${widget.incidentId}/rooms/$roomNumber').update({
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('RTDB Staff error: $e');
    }
  }

  List<Map<dynamic, dynamic>> _getFilteredAndSortedGuests(List<Map<dynamic, dynamic>> allGuests) {
    List<Map<dynamic, dynamic>> filtered = allGuests;
    if (_selectedFloor != 0) {
      filtered = filtered.where((g) => g['floor'] == _selectedFloor).toList();
    }

    filtered.sort((a, b) {
      bool aSpecial = _isSpecialNeeds(a['notes']);
      bool bSpecial = _isSpecialNeeds(b['notes']);
      if (aSpecial && !bSpecial) return -1;
      if (!aSpecial && bSpecial) return 1;

      int statusScore(String s) {
        if (s == 'needs_rescue') return 0;
        if (s == 'unaccounted') return 1;
        return 2; 
      }
      
      int aScore = statusScore(a['status'] ?? 'unaccounted');
      int bScore = statusScore(b['status'] ?? 'unaccounted');
      if (aScore != bScore) return aScore.compareTo(bScore);

      return (a['roomNumber'] ?? '').compareTo(b['roomNumber'] ?? '');
    });
    return filtered;
  }

  bool _isSpecialNeeds(dynamic notes) {
    if (notes == null || notes.toString().isEmpty) return false;
    String n = notes.toString().toLowerCase();
    return n.contains('elderly') || n.contains('mobility') || n.contains('infant') || n.contains('wheelchair');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.incidentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Accountability'),
          backgroundColor: const Color(0xFFF57F17),
          leading: Navigator.canPop(context) ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
        ),
        body: const Center(
          child: Text("No incident selected", style: TextStyle(fontSize: 20, color: Colors.grey)),
        ),
      );
    }

    final appState = Provider.of<AppState>(context);
    final allGuests = appState.allGuests;
    int safeCount = appState.guestCounts['safe'] ?? 0;

    String title = _selectedFloor == 0 ? 'All Floors' : 'Floor $_selectedFloor';
    
    bool isFloorCleared = false;
    if (_selectedFloor != 0) {
      final floorGuests = allGuests.where((g) => g['floor'] == _selectedFloor).toList();
      isFloorCleared = floorGuests.isNotEmpty && floorGuests.every((g) => g['status'] == 'safe' || g['status'] == 'needs_rescue');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$title Accountability — $safeCount/${allGuests.length} Safe'),
        backgroundColor: const Color(0xFFF57F17),
        leading: Navigator.canPop(context) ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AccountabilitySummaryWidget(incidentId: widget.incidentId),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTab(0, 'All'),
                _buildTab(3, 'Floor 3'),
                _buildTab(4, 'Floor 4'),
                _buildTab(5, 'Floor 5'),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _getFilteredAndSortedGuests(allGuests).length,
              itemBuilder: (ctx, i) => _buildGuestCard(_getFilteredAndSortedGuests(allGuests)[i]),
            ),
          )
        ],
      ),
      floatingActionButton: _selectedFloor != 0
          ? FloatingActionButton.extended(
              onPressed: isFloorCleared ? () async {
                await _firebaseService.logTimelineEvent(widget.incidentId, "Floor $_selectedFloor cleared by Staff ($safeCount safe)");
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Floor Cleared! Command Notified.')));
              } : null,
              backgroundColor: isFloorCleared ? Colors.green : Colors.grey,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Submit Floor Clear', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildGuestCard(Map<dynamic, dynamic> guest) {
    final status = guest['status'] ?? 'unaccounted';
    final notes = guest['notes'] ?? '';
    final hasNotes = notes.toString().isNotEmpty;
    final isSpecial = _isSpecialNeeds(notes);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        side: isSpecial ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(guest['roomNumber'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 15),
                    Text(guest['guestName'].toString(), style: const TextStyle(fontSize: 18)),
                  ],
                ),
                if (isSpecial) const Icon(Icons.warning, color: Colors.amber, size: 30),
              ],
            ),
            if (hasNotes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Notes: $notes', style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatusButton(guest['roomNumber'].toString(), 'safe', 'Safe ✓', Colors.green, status == 'safe'),
                _buildStatusButton(guest['roomNumber'].toString(), 'unaccounted', 'Unaccounted ?', Colors.grey, status == 'unaccounted'),
                _buildStatusButton(guest['roomNumber'].toString(), 'needs_rescue', 'Needs Rescue !', Colors.red, status == 'needs_rescue'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String roomNumber, String statusValue, String label, MaterialColor baseColor, bool isSelected) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? baseColor[700] : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 4 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => _updateStatus(roomNumber, statusValue),
      child: Text(label),
    );
  }

  Widget _buildTab(int floorValue, String label) {
    bool isSelected = _selectedFloor == floorValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) setState(() => _selectedFloor = floorValue);
        },
        selectedColor: const Color(0xFFF57F17),
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }
}
