// room controller WiFi Configurator - Flutter app
//
// Talks to the room controller's REST API over the ESP's own Access Point
// (default http://192.168.4.1). Flow:
//   1. User connects their phone to the ESP's "LY-HOME" WiFi first
//      (from the phone's normal WiFi settings, or via the helper button
//      below on Android).
//   2. App calls GET /scan to list nearby networks.
//   3. User picks one, enters a password, taps Connect.
//   4. App calls POST /connect and shows the result.
//
// Dependencies (add to pubspec.yaml):
//   http: ^1.2.0
//
// Android: allow cleartext HTTP to the ESP's local IP. Add to
// android/app/src/main/AndroidManifest.xml, inside <application ...>:
//   android:usesCleartextTraffic="true"
// (The room controller only serves plain HTTP, not HTTPS.)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WifiNetwork {
  final String ssid;
  final int rssi;
  final bool secure;

  WifiNetwork({required this.ssid, required this.rssi, required this.secure});

  factory WifiNetwork.fromJson(Map<String, dynamic> json) {
    return WifiNetwork(
      ssid: json['ssid'] ?? '',
      rssi: json['rssi'] ?? -100,
      secure: json['secure'] ?? true,
    );
  }

  // Rough signal bars from RSSI (dBm).
  int get bars {
    if (rssi >= -55) return 4;
    if (rssi >= -65) return 3;
    if (rssi >= -75) return 2;
    return 1;
  }
}

class WifiConfigPage extends StatefulWidget {
  const WifiConfigPage({super.key});

  @override
  State<WifiConfigPage> createState() => _WifiConfigPageState();
}

class _WifiConfigPageState extends State<WifiConfigPage> {
  // Change this if you set a different softAP IP on the ESP.
  static const String espBaseUrl = 'http://192.168.4.1';
  static const Duration requestTimeout = Duration(seconds: 8);
  static const Duration connectTimeout = Duration(seconds: 20);

  bool _scanning = false;
  bool _connecting = false;
  String? _errorMessage;
  List<WifiNetwork> _networks = [];
  String? _lastKnownIp;
  bool? _lastConnectSuccess;

  Future<void> _scanNetworks() async {
    setState(() {
      _scanning = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .get(Uri.parse('$espBaseUrl/scan'))
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = (data['networks'] as List)
            .map((e) => WifiNetwork.fromJson(e as Map<String, dynamic>))
            .toList();
        // Sort strongest signal first, drop duplicate SSIDs.
        list.sort((a, b) => b.rssi.compareTo(a.rssi));
        final seen = <String>{};
        final deduped = <WifiNetwork>[];
        for (final n in list) {
          if (n.ssid.isEmpty || seen.contains(n.ssid)) continue;
          seen.add(n.ssid);
          deduped.add(n);
        }
        if (!mounted) return;
        setState(() => _networks = deduped);
      } else {
        if (!mounted) return;
        setState(
          () => _errorMessage = 'Couldn’t find networks. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Could not reach the room controller. Make sure your phone is connected '
            'to the "LY-HOME" WiFi network, then try again.',
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _resetWifi() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset WiFi credentials?'),
        content: const Text(
          'This clears the saved network on the room controller and restarts it '
          'into setup mode (the "LY-HOME" hotspot). You\'ll need to '
          'reconnect your phone to that hotspot to set it up again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      String espBaseUrl2 = 'http://192.168.10.11';
      final response = await http
          .post(Uri.parse('$espBaseUrl2/reset'))
          .timeout(requestTimeout);

      final success = response.statusCode == 200;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'WiFi credentials cleared. Device is restarting into setup mode.'
                  : 'Couldn’t reset the controller. Please try again.',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }

      if (success) {
        if (!mounted) return;
        setState(() {
          _networks = [];
          _lastConnectSuccess = null;
          _lastKnownIp = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Could not reach the room controller to reset it. Make sure your phone '
            'is connected to the same network the device is currently on '
            '(its config AP if unconfigured, or your home WiFi if already set up).',
      );
    } finally {}
  }

  Future<void> _connect(String ssid, String password) async {
    setState(() {
      _connecting = true;
      _errorMessage = null;
      _lastConnectSuccess = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$espBaseUrl/connect'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'ssid': ssid, 'password': password}),
          )
          .timeout(connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final success = data['success'] == true;

      if (!mounted) return;
      setState(() {
        _lastConnectSuccess = success;
        _lastKnownIp = data['ip'] as String?;
        if (!success) {
          _errorMessage = data['message'] ?? 'Failed to connect.';
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Connected! Device IP: ${data['ip']}'
                  : (data['message'] ?? 'Failed to connect.'),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastConnectSuccess = false;
        _errorMessage =
            'No response from room controller. It may have dropped its AP while '
            'switching networks — check your phone\'s WiFi list for the '
            'device on your home network.';
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _openPasswordDialog(WifiNetwork network) {
    final passwordController = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Connect to "${network.ssid}"'),
          content: TextField(
            controller: passwordController,
            obscureText: obscure,
            autofocus: network.secure,
            enabled: network.secure,
            decoration: InputDecoration(
              labelText: network.secure ? 'Password' : 'Open network',
              suffixIcon: network.secure
                  ? IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    )
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _connect(network.ssid, passwordController.text);
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scanNetworks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect your controller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.reset_tv),
            tooltip: 'Reset WiFi',
            onPressed: _resetWifi,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rescan',
            onPressed: _scanning ? null : _scanNetworks,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scanNetworks,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'A more connected home.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text('Let’s get your room controller on Wi-Fi.'),
            const SizedBox(height: 28),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'First, connect your phone to the "LY-HOME" '
                        'WiFi network in your phone\'s WiFi settings. Then '
                        'come back here and tap Scan.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_lastConnectSuccess == true)
              Card(
                color: Colors.green.shade50,
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Connected successfully'),
                  subtitle: Text('Device IP: ${_lastKnownIp ?? 'unknown'}'),
                ),
              ),
            const SizedBox(height: 8),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_networks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No networks found yet.'),
                      TextButton(
                        onPressed: _scanNetworks,
                        child: const Text('Tap to scan'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._networks.map(
                (network) => Card(
                  child: ListTile(
                    leading: Icon(
                      _wifiIconFor(network.bars),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(network.ssid),
                    subtitle: Text('${network.rssi} dBm'),
                    trailing: network.secure
                        ? const Icon(Icons.lock, size: 18)
                        : const Icon(Icons.lock_open, size: 18),
                    enabled: !_connecting,
                    onTap: () => _openPasswordDialog(network),
                  ),
                ),
              ),
            if (_connecting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Sending credentials to device...'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _wifiIconFor(int bars) {
    switch (bars) {
      case 4:
        return Icons.wifi;
      case 3:
        return Icons.wifi_2_bar;
      case 2:
        return Icons.wifi_1_bar;
      default:
        return Icons.wifi_off;
    }
  }
}
