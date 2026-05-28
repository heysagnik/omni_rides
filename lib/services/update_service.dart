import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static String get _backendUrl => dotenv.env['BACKEND_URL'] ?? '';

  /// Checks for updates and shows a dialog if needed.
  /// Returns false if a force update is required (caller should block navigation).
  static Future<bool> checkAndPrompt(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final uri = Uri.parse('$_backendUrl/api/app/version?app=user');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return true;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = data['latestVersion'] as String? ?? current;
      final min = data['minVersion'] as String? ?? current;
      final downloadUrl = data['downloadUrl'] as String? ?? '';
      final releaseNotes = data['releaseNotes'] as String? ?? '';

      final isForce = _isOlderThan(current, min);
      final isOptional = !isForce && _isOlderThan(current, latest);

      if (!isForce && !isOptional) return true;
      if (!context.mounted) return !isForce;

      await showDialog(
        context: context,
        barrierDismissible: !isForce,
        builder: (_) => _UpdateDialog(
          isForce: isForce,
          latestVersion: latest,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
        ),
      );

      return !isForce;
    } catch (_) {
      return true;
    }
  }

  static bool _isOlderThan(String current, String target) {
    final a = current.split('.').map(int.tryParse).toList();
    final b = target.split('.').map(int.tryParse).toList();
    for (var i = 0; i < 3; i++) {
      final av = (i < a.length ? a[i] : 0) ?? 0;
      final bv = (i < b.length ? b[i] : 0) ?? 0;
      if (av < bv) return true;
      if (av > bv) return false;
    }
    return false;
  }
}

class _UpdateDialog extends StatelessWidget {
  final bool isForce;
  final String latestVersion, releaseNotes, downloadUrl;

  const _UpdateDialog({
    required this.isForce,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForce,
      child: AlertDialog(
        title: Text(isForce ? 'Update Required' : 'Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isForce
                  ? 'You must update to version $latestVersion to continue.'
                  : 'Version $latestVersion is available.',
            ),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(releaseNotes, style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ],
          ],
        ),
        actions: [
          if (!isForce)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          TextButton(
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
