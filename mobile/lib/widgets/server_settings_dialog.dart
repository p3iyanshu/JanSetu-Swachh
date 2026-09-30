import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/services/server_config.dart';
import '../core/services/server_discovery.dart';

String _displayServer() {
  final uri = Uri.tryParse(AppConstants.apiBaseUrl);
  return uri == null ? AppConstants.apiBaseUrl : '${uri.host}:${uri.port}';
}

/// Shown when a request can't reach the backend at all.
Future<void> showServerUnreachableDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Can't reach the JanSetu server"),
      content: Text(
        'Tried ${_displayServer()}.\n\n'
        'Make sure the server is running on the laptop (Start-JanSetu-Server) and this phone is on the same Wi-Fi.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            showDialog(context: context, builder: (_) => const ServerSettingsDialog(autoSearch: true));
          },
          child: const Text('Fix connection'),
        ),
      ],
    ),
  );
}

/// Live connection status for the login screen. Checks the configured
/// server and, if it doesn't answer, searches the Wi-Fi for one.
class ServerStatusBanner extends StatefulWidget {
  /// Called whenever the server is (re)confirmed reachable, e.g. to reload
  /// data that failed to load while disconnected.
  final VoidCallback? onConnected;

  const ServerStatusBanner({super.key, this.onConnected});

  @override
  State<ServerStatusBanner> createState() => ServerStatusBannerState();
}

enum _Status { checking, searching, connected, notFound }

class ServerStatusBannerState extends State<ServerStatusBanner> {
  _Status _status = _Status.checking;

  @override
  void initState() {
    super.initState();
    recheck();
  }

  Future<void> recheck({bool search = true}) async {
    if (!mounted) return;
    setState(() => _status = _Status.checking);
    if (await ServerDiscovery.isCurrentServerReachable()) {
      if (mounted) setState(() => _status = _Status.connected);
      widget.onConnected?.call();
      return;
    }
    // A manually saved address that stopped working (e.g. an old laptop IP)
    // shouldn't hide the published default - try that before searching.
    final saved = AppConstants.serverOverride;
    if (saved != null) {
      AppConstants.serverOverride = null;
      if (await ServerDiscovery.isCurrentServerReachable()) {
        await ServerConfig.reset();
        if (mounted) setState(() => _status = _Status.connected);
        widget.onConnected?.call();
        return;
      }
      AppConstants.serverOverride = saved;
    }
    if (!search) {
      if (mounted) setState(() => _status = _Status.notFound);
      return;
    }
    if (mounted) setState(() => _status = _Status.searching);
    final found = await ServerDiscovery.discoverAndSave();
    if (mounted) setState(() => _status = found == null ? _Status.notFound : _Status.connected);
    if (found != null) widget.onConnected?.call();
  }

  Future<void> _openSettings() async {
    await showDialog(context: context, builder: (_) => const ServerSettingsDialog());
    recheck(search: false);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (_status) {
      _Status.checking => (Icons.sync, Colors.blueGrey, 'Checking server...'),
      _Status.searching => (Icons.wifi_find, Colors.blue.shade800, 'Searching for the server on this Wi-Fi...'),
      _Status.connected => (Icons.check_circle, Colors.green.shade800, 'Connected to ${_displayServer()}'),
      _Status.notFound => (Icons.error_outline, Colors.red.shade800, 'Server not found - tap to fix'),
    };
    final busy = _status == _Status.checking || _status == _Status.searching;
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: busy ? null : _openSettings,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              else
                Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
              ),
              if (!busy) Icon(Icons.settings_outlined, size: 18, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gear button that opens the server address setting - shown on the citizen
/// and worker login screens.
class ServerSettingsButton extends StatelessWidget {
  const ServerSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Server address',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => showDialog(context: context, builder: (_) => const ServerSettingsDialog()),
    );
  }
}

class ServerSettingsDialog extends StatefulWidget {
  /// Start searching the Wi-Fi for the server as soon as the dialog opens.
  final bool autoSearch;

  const ServerSettingsDialog({super.key, this.autoSearch = false});

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _controller;
  String? _status;
  bool _statusOk = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final host = Uri.tryParse(AppConstants.apiBaseUrl);
    _controller = TextEditingController(
      text: host == null ? AppConstants.apiBaseUrl : '${host.host}:${host.port}',
    );
    if (widget.autoSearch) _findAutomatically();
  }

  Future<void> _findAutomatically() async {
    setState(() {
      _busy = true;
      _status = 'Searching this Wi-Fi for the JanSetu server...';
      _statusOk = false;
    });
    final root = await ServerDiscovery.discoverAndSave();
    if (!mounted) return;
    if (root != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Found and connected to $root')));
      return;
    }
    setState(() {
      _busy = false;
      _status = 'No server found on this Wi-Fi. Check the server window on the laptop is open and '
          'both devices are on the same Wi-Fi, or type the address it shows.';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final baseUrl = ServerConfig.normalize(_controller.text);
    if (baseUrl == null) {
      setState(() {
        _status = 'Enter an address like 192.168.1.5 or 192.168.1.5:8000';
        _statusOk = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Connecting...';
      _statusOk = false;
    });
    final root = baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
    try {
      await Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)))
          .get('$root/health');
      await ServerConfig.save(baseUrl);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to $root')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Could not reach the server at $root. Check the address and that the phone is on the same Wi-Fi.';
        _statusOk = false;
      });
    }
  }

  Future<void> _reset() async {
    await ServerConfig.reset();
    if (!mounted) return;
    final host = Uri.tryParse(AppConstants.apiBaseUrl);
    setState(() {
      _controller.text = host == null ? AppConstants.apiBaseUrl : '${host.host}:${host.port}';
      _status = 'Reset to the built-in default.';
      _statusOk = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'IP address of the computer running the JanSetu-Swachh backend (same Wi-Fi as this phone).',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Server',
              hintText: '192.168.1.5:8000',
              border: OutlineInputBorder(),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(
              _status!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _statusOk ? Colors.green.shade800 : Colors.orange.shade900,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : _findAutomatically, child: const Text('Find automatically')),
        TextButton(onPressed: _busy ? null : _reset, child: const Text('Reset')),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _testAndSave, child: const Text('Test & Save')),
      ],
    );
  }
}
