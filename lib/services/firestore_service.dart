import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/device.dart';
import '../../models/room.dart';

/// Firestore layout:
/// rooms (collection)
///   {roomId} (doc): { name, icon, createdAt }
///     devices (subcollection)
///       {deviceId} (doc): { name, type, isOn, createdAt }
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _roomsRef =>
      _db.collection('rooms');

  CollectionReference<Map<String, dynamic>> _devicesRef(String roomId) =>
      _roomsRef.doc(roomId).collection('devices');

  // ---------------- Rooms ----------------

  Stream<List<Room>> roomsStream() {
    return _roomsRef.orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Room.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addRoom(String name, {String icon = 'home'}) {
    return _roomsRef.add({
      'name': name.trim(),
      'icon': icon,
      'isOn': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameRoom(String roomId, String newName) {
    return _roomsRef.doc(roomId).update({'name': newName.trim()});
  }

  /// Deletes a room and all devices nested under it.
  Future<void> deleteRoom(String roomId) async {
    final devicesSnap = await _devicesRef(roomId).get();
    final batch = _db.batch();
    for (final doc in devicesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_roomsRef.doc(roomId));
    await batch.commit();
  }

  // ---------------- Devices ----------------

  Stream<List<Device>> devicesStream(String roomId) {
    return _devicesRef(roomId).orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Device.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<void> addDevice(String roomId, String name, String type) {
    return _devicesRef(roomId).add({
      'name': name.trim(),
      'type': type,
      'isOn': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> renameDevice(String roomId, String deviceId, String newName) {
    return _devicesRef(roomId).doc(deviceId).update({'name': newName.trim()});
  }

  Future<void> deleteDevice(String roomId, String deviceId) {
    return _devicesRef(roomId).doc(deviceId).delete();
  }

  Future<void> toggleDevice(String roomId, String deviceId, bool isOn) {
    return _devicesRef(roomId).doc(deviceId).update({'isOn': isOn});
  }
   Future<void> toggleOnline(String roomId) {
    return _roomsRef.doc(roomId).update({'isOn': false});
  }
}
