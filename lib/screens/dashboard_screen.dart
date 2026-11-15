import 'dart:async';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/room.dart';
import '../services/firestore_service.dart';
import '../services/home_repository.dart';
import '../services/display_preferences.dart';
import '../widgets/add_device_dialog.dart';
import '../widgets/device_tile.dart';
import '../widgets/name_dialog.dart';
import '../widgets/rooms_row.dart' show kRoomIcons;
import 'wifi.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.repository,
    this.preview = false,
    this.preferences,
  });
  final HomeRepository? repository;
  final bool preview;
  final DisplayPreferences? preferences;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final HomeRepository _service = widget.repository ?? FirestoreService();
  late final Stream<List<Room>> _rooms = _service.roomsStream();
  Timer? _clock;
  int _tab = 0;
  String? _selected;
  late final DisplayPreferences _preferences =
      widget.preferences ?? DisplayPreferences();
  final Map<String, Stream<List<Device>>> _deviceStreams = {};

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    if (widget.preferences == null) _preferences.dispose();
    super.dispose();
  }

  bool _online(Room r) =>
      r.lastSeen > 0 &&
      DateTime.now().millisecondsSinceEpoch - r.lastSeen < 30000;
  String _status(Room r) => r.lastSeen == 0
      ? 'Status unknown'
      : _online(r)
      ? 'Online'
      : 'Offline';
  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn’t save your changes. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _addRoom() async {
    final name = await showNameDialog(
      context,
      title: 'Make room for comfort',
      hintText: 'Room name',
      confirmLabel: 'Add room',
    );
    if (name != null) await _perform(() => _service.addRoom(name));
  }

  Future<void> _addDevice(Room room) async {
    final input = await showAddDeviceDialog(context);
    if (input != null) {
      await _perform(() => _service.addDevice(room.id, input.name, input.type));
    }
  }

  Future<void> _renameDevice(Room room, Device device) async {
    final name = await showNameDialog(
      context,
      title: 'Rename device',
      initialValue: device.name,
    );
    if (name != null) {
      await _perform(() => _service.renameDevice(room.id, device.id, name));
    }
  }

  Future<void> _removeDevice(Room room, Device device) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      title: 'Remove ${device.name}?',
      message:
          'This removes the device from the app. It does not disconnect its wiring.',
    );
    if (confirmed) {
      await _perform(() => _service.deleteDevice(room.id, device.id));
    }
  }

  Future<void> _manageRoom(Room room) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(room.name, style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, 'rename'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Rename room'),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx, 'remove'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove room'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'rename') {
      final name = await showNameDialog(
        context,
        title: 'Rename room',
        initialValue: room.name,
      );
      if (name != null) {
        await _perform(() => _service.renameRoom(room.id, name));
      }
    } else if (choice == 'remove') {
      final confirmed = await showDeleteConfirmDialog(
        context,
        title: 'Remove ${room.name}?',
        message:
            'The room and all its devices will be removed from the app. Wiring is not affected.',
      );
      if (confirmed) await _perform(() => _service.deleteRoom(room.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: _preferences.large
            ? TextScaler.linear(media.textScaler.scale(1) * 1.25)
            : media.textScaler,
        disableAnimations: media.disableAnimations || _preferences.reduceMotion,
      ),
      child: Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (v) => setState(() {
            _tab = v;
            _selected = null;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.door_front_door_outlined),
              selectedIcon: Icon(Icons.door_front_door),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded),
              label: 'Settings',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: StreamBuilder<List<Room>>(
                stream: _rooms,
                builder: (context, snapshot) {
                  final rooms = snapshot.data ?? [];
                  final matches = rooms.where((r) => r.id == _selected);
                  final selected = matches.isEmpty ? null : matches.first;
                  return ListView(
                    key: ValueKey('$_tab/$_selected'),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    children: [
                      _brand(context),
                      if (widget.preview)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                            'PREVIEW · Sample home · No real devices connected',
                          ),
                        ),
                      const SizedBox(height: 32),
                      if (snapshot.hasError)
                        _notice(
                          context,
                          Icons.cloud_off_outlined,
                          'Your home couldn’t be loaded',
                          'Check your internet connection and try opening the app again.',
                        ),
                      if (!snapshot.hasData && !snapshot.hasError) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 24),
                        const Text('Loading your home…'),
                      ] else if (_tab == 3)
                        ..._settings(context)
                      else if (selected != null)
                        ..._roomDetail(context, selected)
                      else if (_tab == 2)
                        ..._alerts(context, rooms)
                      else if (_tab == 1) ...[
                        _heading(
                          context,
                          'Your rooms',
                          'A little control. A lot of comfort.',
                        ),
                        const SizedBox(height: 24),
                        ...rooms.map((r) => _roomCard(context, r)),
                        OutlinedButton.icon(
                          onPressed: _addRoom,
                          icon: const Icon(Icons.add),
                          label: const Text('Add room'),
                        ),
                      ] else
                        ..._home(context, rooms),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openWifi() {
    if (widget.preview) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Controller setup'),
          content: const Text(
            'This sample home does not connect to real controllers. Open LY Homes in live mode to set up your controller’s Wi-Fi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const WifiConfigPage()),
    );
  }

  Widget _brand(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.roofing_rounded,
          color: Theme.of(context).colorScheme.onPrimary,
          size: 28,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text('LY Homes', style: Theme.of(context).textTheme.titleLarge),
      ),
      IconButton.outlined(
        tooltip: 'Set up a controller',
        onPressed: _openWifi,
        icon: const Icon(Icons.wifi_rounded),
      ),
    ],
  );
  Widget _heading(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
  List<Widget> _home(BuildContext context, List<Room> rooms) {
    final hour = DateTime.now().hour;
    final online = rooms.where(_online).length;
    return [
      _heading(
        context,
        hour < 12
            ? 'Good morning.'
            : hour < 17
            ? 'Good afternoon.'
            : 'Good evening.',
        'Welcome to your everyday calm.',
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cottage_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Home at a glance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rooms.isEmpty
                        ? 'Start with your first room.'
                        : '$online of ${rooms.length} rooms responding',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      if (rooms.isNotEmpty) ...[
        Text('Favourites', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('One tap for your everyday essentials.'),
        const SizedBox(height: 20),
        ...rooms.map(
          (room) => StreamBuilder<List<Device>>(
            stream: _deviceStreams.putIfAbsent(
              room.id,
              () => _service.devicesStream(room.id),
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Couldn’t load favourites in ${room.name}.');
              }
              final favorites = (snapshot.data ?? <Device>[])
                  .where((d) => d.isFavorite)
                  .toList();
              return Column(
                children: favorites
                    .map((device) => _deviceTile(room, device, showRoom: true))
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
      Row(
        children: [
          Expanded(
            child: Text(
              'Your rooms',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          TextButton.icon(
            onPressed: _addRoom,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (rooms.isEmpty)
        _notice(
          context,
          Icons.door_front_door_outlined,
          'A fresh start for your home',
          'Add your first room to organise lights, fans and everyday essentials.',
        ),
      ...rooms.map((r) => _roomCard(context, r)),
      const SizedBox(height: 8),
      _notice(
        context,
        Icons.touch_app_outlined,
        'Simple by design',
        'Open a room to control its devices. Choose “Show on Home” in a device’s menu to keep it close.',
      ),
    ];
  }

  Widget _deviceTile(Room room, Device device, {bool showRoom = false}) =>
      DeviceTile(
        key: ValueKey('${room.id}/${device.id}'),
        device: device,
        roomName: showRoom ? room.name : null,
        available: _online(room),
        onFavorite: () => _perform(
          () => _service.setFavorite(room.id, device.id, !device.isFavorite),
        ),
        onToggle: (v) => _service.toggleDevice(room.id, device.id, v),
        onRename: () => _renameDevice(room, device),
        onDelete: () => _removeDevice(room, device),
      );
  Widget _roomCard(BuildContext context, Room room) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selected = room.id),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  kRoomIcons[room.icon] ?? Icons.home_outlined,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    _pill(context, room),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, Room r) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _online(r)
              ? Icons.check_circle_outline
              : r.lastSeen == 0
              ? Icons.help_outline
              : Icons.cloud_off_outlined,
          size: 20,
          color: _online(r) ? colors.primary : colors.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _status(r),
            style: TextStyle(
              color: _online(r) ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _roomDetail(BuildContext context, Room room) => [
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _selected = null),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Back'),
      ),
    ),
    const SizedBox(height: 16),
    _heading(context, room.name, 'Your everyday essentials, in one place.'),
    const SizedBox(height: 16),
    _pill(context, room),
    const SizedBox(height: 24),
    if (!_online(room)) ...[
      _notice(
        context,
        Icons.cloud_off_outlined,
        'Controller isn’t responding',
        'Check its power and Wi-Fi. Device controls will be available when it responds.',
      ),
      const SizedBox(height: 24),
    ],
    StreamBuilder<List<Device>>(
      stream: _deviceStreams.putIfAbsent(
        room.id,
        () => _service.devicesStream(room.id),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _notice(
            context,
            Icons.error_outline,
            'Devices couldn’t be loaded',
            'Check your connection and open this room again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return _notice(
            context,
            Icons.lightbulb_outline,
            'Ready for your first device',
            'Add a light, fan or socket to this room.',
          );
        }
        return Column(
          children: snapshot.data!
              .map((device) => _deviceTile(room, device))
              .toList(),
        );
      },
    ),
    const SizedBox(height: 24),
    FilledButton.icon(
      onPressed: () => _addDevice(room),
      icon: const Icon(Icons.add),
      label: const Text('Add device'),
    ),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      onPressed: () => _manageRoom(room),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('Manage room'),
    ),
    const SizedBox(height: 24),
    const Text(
      'Switch commands are saved to your home. Physical operation has not been verified by a sensor.',
    ),
  ];
  List<Widget> _alerts(BuildContext context, List<Room> rooms) {
    final issues = rooms.where((r) => !_online(r)).toList();
    return [
      _heading(context, 'Needs attention', 'Current room controller status.'),
      const SizedBox(height: 24),
      if (issues.isEmpty)
        _notice(
          context,
          Icons.check_circle_outline,
          rooms.isEmpty ? 'No rooms to check yet' : 'Rooms are responding',
          rooms.isEmpty
              ? 'Add a room to see its controller status here.'
              : 'There are no current controller issues.',
        ),
      ...issues.map((r) => _roomCard(context, r)),
      const SizedBox(height: 16),
      const Text(
        'This view shows current status. Past alerts are not recorded yet.',
      ),
    ];
  }

  List<Widget> _settings(BuildContext context) => [
    _heading(context, 'Make yourself at home', 'A few thoughtful adjustments.'),
    const SizedBox(height: 28),
    Text('DISPLAY & COMFORT', style: Theme.of(context).textTheme.labelLarge),
    if (!_preferences.persistent)
      const Text('Display changes apply for this session.'),
    const SizedBox(height: 12),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text('Larger text'),
      subtitle: const Text('Extra breathing room for reading'),
      value: _preferences.large,
      onChanged: (v) => setState(() {
        _preferences.setLarge(v);
      }),
    ),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text('Reduce motion'),
      subtitle: const Text('Keep transitions still and simple'),
      value: _preferences.reduceMotion,
      onChanged: (v) => setState(() {
        _preferences.setReduceMotion(v);
      }),
    ),
    SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: const Text('Dark appearance'),
      subtitle: const Text('A softer glow for the evening'),
      value: _preferences.dark,
      onChanged: widget.preferences == null
          ? null
          : (v) => _preferences.setDark(v),
    ),
    const SizedBox(height: 28),
    Text('YOUR HOME', style: Theme.of(context).textTheme.labelLarge),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      onPressed: _openWifi,
      icon: const Icon(Icons.wifi_rounded),
      label: const Text('Set up controller Wi-Fi'),
    ),
    const SizedBox(height: 24),
    _notice(
      context,
      Icons.shield_outlined,
      'Electrical safety',
      'The app shows what the switch was told to do. It is not a safety device. Always switch off at the wall or main board before touching wiring.',
    ),
    const SizedBox(height: 32),
    const Center(child: Text('LY Homes · A little more ease, every day.')),
  ];
  Widget _notice(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 30),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body),
      ],
    ),
  );
}
