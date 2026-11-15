import '../models/device.dart';
import '../models/room.dart';

abstract interface class HomeRepository {
  Future<void> setFavorite(String roomId, String deviceId, bool value);
  Stream<List<Room>> roomsStream();
  Stream<List<Device>> devicesStream(String roomId);
  Future<void> addRoom(String name, {String icon = 'home'});
  Future<void> renameRoom(String roomId, String name);
  Future<void> deleteRoom(String roomId);
  Future<void> addDevice(String roomId, String name, String type);
  Future<void> renameDevice(String roomId, String deviceId, String name);
  Future<void> deleteDevice(String roomId, String deviceId);
  Future<void> toggleDevice(String roomId, String deviceId, bool value);
}
