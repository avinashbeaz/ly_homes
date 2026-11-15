import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';
import 'add_device_dialog.dart';

class DeviceTile extends StatefulWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    this.available = true,
    this.onFavorite,
    this.roomName,
  });
  final Device device;
  final Future<void> Function(bool) onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool available;
  final VoidCallback? onFavorite;
  final String? roomName;
  @override
  State<DeviceTile> createState() => _DeviceTileState();
}

class _DeviceTileState extends State<DeviceTile> {
  bool _pending = false;
  bool _failed = false;
  bool? _retryValue;
  Future<void> _toggle() async {
    if (_pending || !widget.available) return;
    final target = _failed
        ? (_retryValue ?? !widget.device.isOn)
        : !widget.device.isOn;
    _retryValue = target;
    setState(() {
      _pending = true;
      _failed = false;
    });
    try {
      await widget.onToggle(target).timeout(const Duration(seconds: 5));
      _retryValue = null;
      if (mounted) HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = d.isOn && widget.available;
    final bg = _pending
        ? (theme.brightness == Brightness.dark
              ? const Color(0xFF4A3919)
              : const Color(0xFFFFF3D6))
        : _failed
        ? colors.errorContainer
        : active
        ? colors.primary
        : colors.surface;
    final fg = _pending
        ? (theme.brightness == Brightness.dark
              ? const Color(0xFFFFE1A1)
              : const Color(0xFF754D00))
        : _failed
        ? colors.onErrorContainer
        : active
        ? colors.onPrimary
        : colors.onSurface;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      button: true,
      enabled: widget.available && !_pending,
      onTap: widget.available && !_pending ? _toggle : null,
      hint: widget.available && !_pending
          ? (_failed
                ? 'Try the same command again'
                : 'Double tap to turn ${d.isOn ? 'off' : 'on'}')
          : null,
      label:
          '${d.name}, ${!widget.available
              ? 'room unavailable'
              : _pending
              ? 'saving command'
              : d.isOn
              ? 'last set on'
              : 'last set off'}',
      child: AnimatedContainer(
        duration: duration,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: widget.available && !_pending ? _toggle : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 8, 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      kDeviceTypeIcons[d.type] ?? Icons.devices_other_outlined,
                      size: 30,
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: fg,
                          ),
                        ),
                        if (widget.roomName != null)
                          Text(
                            widget.roomName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: fg,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          !widget.available
                              ? 'Room unavailable'
                              : _pending
                              ? 'Saving command…'
                              : _failed
                              ? 'Couldn’t save. Tap to retry'
                              : 'Last set to ${d.isOn ? 'On' : 'Off'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: fg,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              _pending
                                  ? Icons.hourglass_top_rounded
                                  : Icons.power_settings_new_rounded,
                              size: 22,
                              color: fg,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _pending
                                    ? 'Please wait'
                                    : widget.available
                                    ? d.isOn
                                          ? 'ON'
                                          : 'OFF'
                                    : 'Unavailable',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    constraints: const BoxConstraints(
                      minWidth: 64,
                      minHeight: 64,
                    ),
                    tooltip: 'Manage ${d.name}',
                    iconColor: fg,
                    onSelected: (v) => v == 'favorite'
                        ? widget.onFavorite?.call()
                        : v == 'rename'
                        ? widget.onRename()
                        : widget.onDelete(),
                    itemBuilder: (_) => [
                      if (widget.onFavorite != null)
                        PopupMenuItem(
                          value: 'favorite',
                          child: Text(
                            d.isFavorite
                                ? 'Remove from favourites'
                                : 'Show on Home',
                          ),
                        ),
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename device'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove device'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
