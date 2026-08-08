class Device {
  final String id;
  final String name;
  final String type; // e.g. light, plug, thermostat, fan, lock, speaker
  final bool isOn;

  Device({
    required this.id,
    required this.name,
    this.type = 'device',
    this.isOn = false,
  });

  factory Device.fromMap(String id, Map<String, dynamic> map) {
    return Device(
      id: id,
      name: (map['name'] ?? '') as String,
      type: (map['type'] ?? 'device') as String,
      isOn: (map['isOn'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'isOn': isOn,
    };
  }

  Device copyWith({String? name, String? type, bool? isOn}) {
    return Device(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      isOn: isOn ?? this.isOn,
    );
  }
}
