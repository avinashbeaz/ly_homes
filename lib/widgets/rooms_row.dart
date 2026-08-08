import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../services/firestore_service.dart';
import 'name_dialog.dart';

const Map<String, IconData> kRoomIcons = {
  'home': Icons.home_outlined,
  'living_room': Icons.weekend_outlined,
  'bedroom': Icons.bed_outlined,
  'kitchen': Icons.kitchen_outlined,
  'bathroom': Icons.bathtub_outlined,
  'garage': Icons.garage_outlined,
  'office': Icons.chair_outlined,
  'garden': Icons.yard_outlined,
};

class RoomsRow extends StatelessWidget {
  const RoomsRow({
    super.key,
    required this.rooms,
    required this.selectedRoomId,
    required this.onRoomSelected,
    required this.firestoreService,
  });

  final List<Room> rooms;
  final String? selectedRoomId;
  final ValueChanged<String> onRoomSelected;
  final FirestoreService firestoreService;

  Future<void> _addRoom(BuildContext context) async {
    final name = await showNameDialog(
      context,
      title: 'Add room',
      hintText: 'e.g. Living Room',
      confirmLabel: 'Add',
    );
    if (name != null && name.isNotEmpty) {
      await firestoreService.addRoom(name);
    }
  }

  Future<void> _renameRoom(BuildContext context, Room room) async {
    final name = await showNameDialog(
      context,
      title: 'Rename room',
      initialValue: room.name,
      confirmLabel: 'Save',
    );
    if (name != null && name.isNotEmpty && name != room.name) {
      await firestoreService.renameRoom(room.id, name);
    }
  }

  Future<void> _deleteRoom(BuildContext context, Room room) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: 'Delete room?',
      message:
          'This will delete "${room.name}" and all of its devices. This cannot be undone.',
    );
    if (confirmed) {
      await firestoreService.deleteRoom(room.id);
    }
  }

  void _showRoomOptions(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename room'),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameRoom(context, room);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete room',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteRoom(context, room);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: rooms.length + 1,
        // ignore: unnecessary_underscores
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == rooms.length) {
            return _AddRoomCard(onTap: () => _addRoom(context));
          }
          final room = rooms[index];
          final isSelected = room.id == selectedRoomId;
          return _RoomCard(
            room: room,
            isSelected: isSelected,
            onTap: () => onRoomSelected(room.id),
            onLongPress: () => _showRoomOptions(context, room),
            onEditTap: () => _showRoomOptions(context, room),
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onEditTap,
  });

  final Room room;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = kRoomIcons[room.icon] ?? Icons.home_outlined;
    final bg = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;
        final now = DateTime.now().millisecondsSinceEpoch;
        final diff = now - (room.lastSeen );
        final bool isOnline = diff < 20000;


    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
         Align(
          alignment: Alignment.topLeft,
           child: CircleAvatar(
                   radius: 5,
                   backgroundColor: isOnline ? Colors.green : Colors.grey,
                 ),
         ),
    
                Icon(icon, color: fg, size: 26),
                const SizedBox(height: 6),
                Text(
                  room.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Positioned(
              top: -6,
              right: -6,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onEditTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_vert, size: 16, color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRoomCard extends StatelessWidget {
  const _AddRoomCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: theme.colorScheme.primary, size: 26),
            const SizedBox(height: 6),
            Text(
              'Add room',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
