
class Room {
  final String id;
  final String name;
  final String icon; 
  final bool isOn;
  final int lastSeen; // stored as a simple key, mapped to IconData in UI

  Room({
    required this.id,
    required this.name,
    this.icon = 'home',
    this.isOn = false,
    this.lastSeen = 0,
  });

  factory Room.fromMap(String id, Map<String, dynamic> map) {
    return Room(
      id: id,
      name: (map['name'] ?? '') as String,
      icon: (map['icon'] ?? 'home') as String,
      isOn: (map['isOn'] ?? false) as bool,
      lastSeen: (map['lastSeen'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'isOn': isOn,
      'lastSeen': lastSeen,
    };
  }

  Room copyWith({String? name, String? icon, bool? isOn, int? lastSeen}) {
    return Room(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isOn: isOn ?? this.isOn,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
