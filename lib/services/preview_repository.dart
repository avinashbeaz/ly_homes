import 'dart:async';
import '../models/device.dart';
import '../models/room.dart';
import 'home_repository.dart';

/// Explicit opt-in, in-memory sample home; never communicates with Firebase.
class PreviewRepository implements HomeRepository {
  PreviewRepository() {
    _heartbeat = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _changes.add(null),
    );
  }
  Timer? _heartbeat;
  final _changes = StreamController<void>.broadcast();
  final _rooms = <Room>[
    Room(id: 'living', name: 'Living room', icon: 'living_room'),
    Room(id: 'bed', name: 'Bedroom', icon: 'bedroom'),
    Room(id: 'kitchen', name: 'Kitchen', icon: 'kitchen'),
  ];
  final _devices = <String, List<Device>>{
    'living': [
      Device(
        id: 'light',
        name: 'Ceiling light',
        type: 'light',
        isOn: true,
        isFavorite: true,
      ),
      Device(id: 'fan', name: 'Ceiling fan', type: 'fan', isFavorite: true),
      Device(id: 'socket', name: 'TV socket', type: 'plug', isOn: true),
    ],
    'bed': [
      Device(
        id: 'lamp',
        name: 'Night lamp',
        type: 'light',
        isOn: true,
        isFavorite: true,
      ),
    ],
    'kitchen': [
      Device(id: 'light', name: 'Kitchen light', type: 'light'),
      Device(id: 'fan', name: 'Exhaust fan', type: 'fan', isFavorite: true),
    ],
  };
  List<Room> get _current => _rooms
      .map(
        (r) => r.copyWith(
          lastSeen: DateTime.now()
              .subtract(Duration(minutes: r.id == 'bed' ? 4 : 0))
              .millisecondsSinceEpoch,
        ),
      )
      .toList();
  @override
  Stream<List<Room>> roomsStream() => Stream<List<Room>>.multi((sink) {
    sink.add(_current);
    final subscription = _changes.stream.listen((_) => sink.add(_current));
    sink.onCancel = subscription.cancel;
  }, isBroadcast: true);
  @override
  Stream<List<Device>> devicesStream(String roomId) =>
      Stream<List<Device>>.multi((sink) {
        sink.add(List.of(_devices[roomId] ?? []));
        final subscription = _changes.stream.listen(
          (_) => sink.add(List.of(_devices[roomId] ?? [])),
        );
        sink.onCancel = subscription.cancel;
      }, isBroadcast: true);
  @override
  Future<void> addRoom(String name, {String icon = 'home'}) async {
    _rooms.add(
      Room(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        icon: icon,
      ),
    );
    _changes.add(null);
  }

  @override
  Future<void> renameRoom(String roomId, String name) async {
    final i = _rooms.indexWhere((r) => r.id == roomId);
    _rooms[i] = _rooms[i].copyWith(name: name);
    _changes.add(null);
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    _rooms.removeWhere((r) => r.id == roomId);
    _devices.remove(roomId);
    _changes.add(null);
  }

  @override
  Future<void> addDevice(String roomId, String name, String type) async {
    (_devices[roomId] ??= []).add(
      Device(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        type: type,
      ),
    );
    _changes.add(null);
  }

  @override
  Future<void> renameDevice(String roomId, String deviceId, String name) async {
    final list = _devices[roomId]!;
    final i = list.indexWhere((d) => d.id == deviceId);
    list[i] = list[i].copyWith(name: name);
    _changes.add(null);
  }

  @override
  Future<void> deleteDevice(String roomId, String deviceId) async {
    _devices[roomId]?.removeWhere((d) => d.id == deviceId);
    _changes.add(null);
  }

  @override
  Future<void> toggleDevice(String roomId, String deviceId, bool value) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final list = _devices[roomId]!;
    final i = list.indexWhere((d) => d.id == deviceId);
    list[i] = list[i].copyWith(isOn: value);
    _changes.add(null);
  }

  @override
  Future<void> setFavorite(String roomId, String deviceId, bool value) async {
    final list = _devices[roomId]!;
    final i = list.indexWhere((d) => d.id == deviceId);
    list[i] = list[i].copyWith(isFavorite: value);
    _changes.add(null);
  }

  Future<void> dispose() {
    _heartbeat?.cancel();
    return _changes.close();
  }
}
