import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../mock_data.dart';
import '../services/firebase_service.dart';

class FloorMapWidget extends StatefulWidget {
  final String incidentId;
  const FloorMapWidget({Key? key, required this.incidentId}) : super(key: key);

  @override
  State<FloorMapWidget> createState() => _FloorMapWidgetState();
}

class _FloorMapWidgetState extends State<FloorMapWidget> {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  Map<dynamic, dynamic> _fallbackRooms = {};
  int _selectedFloor = 3;

  @override
  void initState() {
    super.initState();
    if (widget.incidentId.isEmpty) return;
    if (widget.incidentId.startsWith('mock_')) {
      MockDataStore.generate(widget.incidentId);
      if (mounted) setState(() => _fallbackRooms = MockDataStore.rooms);
      return;
    }
    try {
      _rtdb.ref('muster/${widget.incidentId}/rooms').onValue.listen((event) {
        if (event.snapshot.value != null && mounted) {
          setState(() {
            _fallbackRooms = event.snapshot.value as Map<dynamic, dynamic>;
          });
        }
      });
    } catch (e) {
      print('RTDB Staff listener error: $e');
    }
  }

  Color _getRoomColor(String roomNumber, Map<dynamic, dynamic> roomsMapping) {
    if (roomsMapping.containsKey(roomNumber)) {
      final status = roomsMapping[roomNumber]['status'];
      if (status == 'safe') return Colors.green[600]!;
      if (status == 'needs_rescue') return Colors.red[900]!;
      return Colors.amber[700]!;
    }
    return Colors.grey[300]!;
  }

  Widget _buildGrid(Map<dynamic, dynamic> roomsMapping) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 24, // 4x6 grid equals 24 possible rooms
      itemBuilder: (context, index) {
        String roomNumber = '$_selectedFloor${(index + 1).toString().padLeft(2, "0")}';
        return Container(
          decoration: BoxDecoration(
            color: _getRoomColor(roomNumber, roomsMapping),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
          child: Center(
            child: Text(roomNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 2)])),
          ),
        );
      },
    );
  }

  List<int> _getActiveFloors(Map<dynamic, dynamic> roomsMapping) {
    if (roomsMapping.isEmpty) return [3, 4, 5];
    final floors = roomsMapping.values.map((r) => r['floor'] as int?).where((f) => f != null).cast<int>().toSet().toList();
    floors.sort();
    return floors.isNotEmpty ? floors : [3, 4, 5];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.incidentId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Unable to load floor map\nNo incident selected', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamFirestoreRooms(widget.incidentId),
      builder: (context, snapshot) {
        Map<dynamic, dynamic> displayRooms = _fallbackRooms;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
           displayRooms = {};
           for (var room in snapshot.data!) {
             String roomId = room['roomNumber']?.toString() ?? room['id']?.toString() ?? '';
             if (roomId.isNotEmpty) {
               displayRooms[roomId] = room;
             }
           }
        }

        final floorList = _getActiveFloors(displayRooms);
        if (!floorList.contains(_selectedFloor)) {
          _selectedFloor = floorList.first;
        }

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: floorList.map((f) => _buildTab(f)).toList(),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _buildGrid(displayRooms),
            ),
        const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.green[600]!, 'Safe'),
                _legendItem(Colors.amber[700]!, 'Unaccounted'),
                _legendItem(Colors.red[900]!, 'Needs Rescue'),
                _legendItem(Colors.grey[300]!, 'Empty/Unknown'),
              ],
            )
          ],
        );
      }
    );
  }

  Widget _buildTab(int floorValue) {
    bool isSelected = _selectedFloor == floorValue;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text('Floor $floorValue'),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) setState(() => _selectedFloor = floorValue);
        },
        selectedColor: Colors.deepPurple,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
