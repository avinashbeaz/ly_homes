import 'package:flutter/material.dart';

import '../../models/device.dart';
import '../../models/room.dart';
import '../../services/firestore_service.dart';
import '../../widgets/add_device_dialog.dart';
import '../../widgets/device_tile.dart';
import '../../widgets/name_dialog.dart';
import '../../widgets/rooms_row.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedRoomId;

  Future<void> _addDevice(BuildContext context, String roomId) async {
    final input = await showAddDeviceDialog(context);
    if (input != null && input.name.isNotEmpty) {
      await _firestoreService.addDevice(roomId, input.name, input.type);
    }
  }

  Future<void> _renameDevice(
      BuildContext context, String roomId, Device device) async {
    final name = await showNameDialog(
      context,
      title: 'Rename device',
      initialValue: device.name,
      confirmLabel: 'Save',
    );
    if (name != null && name.isNotEmpty && name != device.name) {
      await _firestoreService.renameDevice(roomId, device.id, name);
    }
  }

  Future<void> _deleteDevice(
      BuildContext context, String roomId, Device device) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: 'Delete device?',
      message: 'This will remove "${device.name}" from this room.',
    );
    if (confirmed) {
      await _firestoreService.deleteDevice(roomId, device.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LY Home'),
        centerTitle: false,
      ),
      body: StreamBuilder<List<Room>>(
        stream: _firestoreService.roomsStream(),
        builder: (context, roomSnapshot) {
          if (roomSnapshot.hasError) {
            return Center(child: Text('Error: ${roomSnapshot.error}'));
          }
          if (!roomSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = roomSnapshot.data!;

          // Keep the selected room valid; default to the first room.
          if (rooms.isEmpty) {
            _selectedRoomId = null;
          } else if (_selectedRoomId == null ||
              !rooms.any((r) => r.id == _selectedRoomId)) {
            _selectedRoomId = rooms.first.id;
          }
          

          return Column(
            children: [
              RoomsRow(
                rooms: rooms,
                selectedRoomId: _selectedRoomId,
                onRoomSelected: (id) => setState(() => _selectedRoomId = id),
                firestoreService: _firestoreService,
              ),
              const Divider(height: 1),
              Expanded(
                child: rooms.isEmpty
                    ? const _EmptyState(
                        message:
                            'No rooms yet.\nTap "Add room" above to get started.',
                      )
                    : _DeviceList(
                        roomId: _selectedRoomId!,
                        firestoreService: _firestoreService,
                        onRename: (device) => _renameDevice(
                            context, _selectedRoomId!, device),
                        onDelete: (device) => _deleteDevice(
                            context, _selectedRoomId!, device),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _selectedRoomId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addDevice(context, _selectedRoomId!),
              icon: const Icon(Icons.add),
              label: const Text('Add device'),
            ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.roomId,
    required this.firestoreService,
    required this.onRename,
    required this.onDelete,
  });

  final String roomId;
  final FirestoreService firestoreService;
  final ValueChanged<Device> onRename;
  final ValueChanged<Device> onDelete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Device>>(
      stream: firestoreService.devicesStream(roomId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final devices = snapshot.data!;
        if (devices.isEmpty) {
          return const _EmptyState(
            message: 'No devices in this room yet.\nTap "Add device" below.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return DeviceTile(
              device: device,
              onToggle: (value) =>
                  firestoreService.toggleDevice(roomId, device.id, value),
              onRename: () => onRename(device),
              onDelete: () => onDelete(device),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.grey),
        ),
      ),
    );
  }
}
