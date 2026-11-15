import 'package:flutter/material.dart';

const Map<String, IconData> kDeviceTypeIcons = {
  'light': Icons.lightbulb_outline,
  'plug': Icons.power_outlined,
  'thermostat': Icons.thermostat_outlined,
  'fan': Icons.mode_fan_off_rounded,
  'lock': Icons.lock_outline,
  'speaker': Icons.speaker_outlined,
  'camera': Icons.videocam_outlined,
  'device': Icons.devices_other_outlined,
};

class DeviceInput {
  final String name;
  final String type;
  DeviceInput(this.name, this.type);
}

/// Shows a dialog to collect a device name + type. Returns null if cancelled.
Future<DeviceInput?> showAddDeviceDialog(BuildContext context) {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String selectedType = 'light';

  return showDialog<DeviceInput>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Add device'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: controller,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Device name',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kDeviceTypeIcons.entries.map((entry) {
                        final isSelected = entry.key == selectedType;
                        return ChoiceChip(
                          label: Text(entry.key),
                          avatar: Icon(entry.value, size: 18),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => selectedType = entry.key);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(
                      ctx,
                    ).pop(DeviceInput(controller.text.trim(), selectedType));
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}
