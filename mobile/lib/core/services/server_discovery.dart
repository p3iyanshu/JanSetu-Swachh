import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import 'server_config.dart';

/// Finds the JanSetu-Swachh backend on the local Wi-Fi so the app works on
/// any network without anyone typing an IP address.
///
/// 1. UDP broadcast "JANSETU_DISCOVER" to port 45678 - the backend answers
///    with its API port and we learn its IP from the reply.
/// 2. If broadcasts are blocked, probe `/health` on port 8000 across this
///    phone's /24 subnet.
class ServerDiscovery {
  static const int discoveryPort = 45678;
  static const int defaultApiPort = 8000;

  static Dio _probeClient() => Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 1500),
        receiveTimeout: const Duration(milliseconds: 1500),
      ));

  /// True when the currently configured server answers `/health`.
  static Future<bool> isCurrentServerReachable() => _isHealthy(AppConstants.apiRootUrl);

  static Future<bool> _isHealthy(String root) async {
    try {
      final response = await _probeClient().get('$root/health');
      return response.statusCode == 200 &&
          response.data is Map &&
          (response.data as Map)['status'] == 'healthy';
    } catch (_) {
      return false;
    }
  }

  /// Finds a server and saves it as the app's server address. Returns the
  /// server root (e.g. `http://192.168.1.5:8000`) or null if none was found.
  static Future<String?> discoverAndSave() async {
    if (kIsWeb) return null;
    final root = await _broadcastDiscovery() ?? await _subnetScan();
    if (root == null) return null;
    await ServerConfig.save('$root/api/v1');
    return root;
  }

  static Future<String?> _broadcastDiscovery() async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final completer = Completer<String?>();

      socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) return;
        final datagram = socket!.receive();
        if (datagram == null) return;
        try {
          final payload = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
          if (payload['service'] != 'jansetu-swachh') return;
          final port = payload['port'] as int? ?? defaultApiPort;
          completer.complete('http://${datagram.address.address}:$port');
        } catch (_) {}
      });

      final message = utf8.encode('JANSETU_DISCOVER');
      final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
      for (final address in await _localIPv4Addresses()) {
        final parts = address.split('.');
        targets.add(InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255'));
      }
      // Send a few times - a single UDP packet is easily dropped on busy Wi-Fi.
      for (var attempt = 0; attempt < 3 && !completer.isCompleted; attempt++) {
        for (final target in targets) {
          try {
            socket.send(message, target, discoveryPort);
          } catch (_) {}
        }
        await Future.any([completer.future, Future.delayed(const Duration(milliseconds: 700))]);
      }

      final root = await completer.future.timeout(const Duration(milliseconds: 800), onTimeout: () => null);
      if (root != null && await _isHealthy(root)) return root;
      return null;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }

  static Future<String?> _subnetScan() async {
    final addresses = await _localIPv4Addresses();
    for (final own in addresses) {
      final parts = own.split('.');
      final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
      final candidates = [
        for (var host = 1; host < 255; host++)
          if ('$prefix.$host' != own) '$prefix.$host',
      ];
      // Probe in batches so we don't open 254 sockets at once.
      for (var i = 0; i < candidates.length; i += 32) {
        final batch = candidates.skip(i).take(32);
        final results = await Future.wait(batch.map((ip) async {
          final root = 'http://$ip:$defaultApiPort';
          return await _isHealthy(root) ? root : null;
        }));
        final found = results.whereType<String>();
        if (found.isNotEmpty) return found.first;
      }
    }
    return null;
  }

  static Future<List<String>> _localIPv4Addresses() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final interface in interfaces)
          for (final address in interface.addresses)
            if (!address.isLoopback && !address.address.startsWith('169.254.')) address.address,
      ];
    } catch (_) {
      return [];
    }
  }
}
