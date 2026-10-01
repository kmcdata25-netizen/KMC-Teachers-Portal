import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Information regarding an available remote update for KMC Teacher Portal
class AppUpdateInfo {
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String apkUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.apkUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.hasUpdate,
  });

  factory AppUpdateInfo.noUpdate({
    required String currentVersion,
    required int currentBuildNumber,
  }) {
    return AppUpdateInfo(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      latestVersion: currentVersion,
      latestBuildNumber: currentBuildNumber,
      apkUrl: '',
      releaseNotes: '',
      forceUpdate: false,
      hasUpdate: false,
    );
  }
}

/// Service that handles checking remote version manifests, downloading update APKs,
/// and launching the native Android system installer for seamless in-place updates.
class TeacherUpdateService {
  TeacherUpdateService._();
  static final TeacherUpdateService instance = TeacherUpdateService._();

  static const MethodChannel _installPermChannel =
      MethodChannel('ke.ac.kasaranimusic.kmc_teacher_app/install_permission');

  /// Default update manifest URL on GitHub.
  static String updateManifestUrl =
      'https://raw.githubusercontent.com/kmcdata25-netizen/KMC-Teachers-Portal/main/version.json';

  /// Check whether the app currently has permission to install unknown APKs on Android.
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? canInstall =
          await _installPermChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } catch (e) {
      debugPrint('[TeacherUpdateService] canRequestPackageInstalls notice: $e');
      return true;
    }
  }

  /// Opens the system Settings page directly to KMC Teacher Portal's
  /// "Allow from this source" / "Install unknown apps" toggle.
  Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? result = await _installPermChannel
          .invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (e) {
      debugPrint('[TeacherUpdateService] openInstallPermissionSettings error: $e');
      return false;
    }
  }

  /// Proactively prompts the user to grant "Install unknown apps" on first launch
  /// so in-app updates work seamlessly without permission barriers.
  Future<void> promptInstallPermissionOnFirstLaunch(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      final canInstall = await canRequestPackageInstalls();
      if (canInstall) return; // Already granted!

      final prefs = await SharedPreferences.getInstance();
      final alreadyPrompted =
          prefs.getBool('kmc_teacher_install_perm_prompted') ?? false;
      if (alreadyPrompted) return;
      await prefs.setBool('kmc_teacher_install_perm_prompted', true);

      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.borderOutline, width: 1),
          ),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.brandGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.security_update_good_rounded,
                  color: AppTheme.brandGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Seamless Updates',
                  style: TextStyle(
                    color: AppTheme.textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'To receive future Kasarani Music Center Teacher Portal feature updates, studio timetables, and security patches directly without reinstalling, please allow "Install unknown apps".',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Later',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openInstallPermissionSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: const Color(0xFF061C2D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Allow in Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[TeacherUpdateService] promptInstallPermissionOnFirstLaunch notice: $e');
    }
  }

  /// Check whether a newer version of KMC Teacher Portal is available remotely.
  Future<AppUpdateInfo?> checkForUpdate({String? customManifestUrl}) async {
    try {
      final targetUrl = customManifestUrl ?? updateManifestUrl;
      final uri = Uri.parse(targetUrl);

      String currentVersion = '1.0.0';
      int currentBuildNumber = 1;

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        currentVersion = packageInfo.version;
        currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      } catch (_) {}

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
          '[TeacherUpdateService] Remote version check returned ${response.statusCode}',
        );
        return null;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final latestVersion = data['latest_version']?.toString() ?? currentVersion;
      final latestBuildNumber = int.tryParse(
            data['latest_build_number']?.toString() ?? '',
          ) ??
          0;
      final apkUrl = data['apk_url']?.toString() ?? '';
      final releaseNotes = data['release_notes']?.toString() ??
          'Bug fixes and performance improvements.';
      final forceUpdate = data['force_update'] == true;

      final bool hasUpdate =
          latestBuildNumber > currentBuildNumber && apkUrl.isNotEmpty;

      return AppUpdateInfo(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        latestVersion: latestVersion,
        latestBuildNumber: latestBuildNumber,
        apkUrl: apkUrl,
        releaseNotes: releaseNotes,
        forceUpdate: forceUpdate,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      debugPrint('[TeacherUpdateService] Failed to check for update: $e');
      return null;
    }
  }

  /// Downloads the remote APK file to the app's cache directory while broadcasting progress.
  Future<File?> downloadApk(
    String apkUrl, {
    void Function(double progress, int receivedBytes, int totalBytes)?
        onProgress,
  }) async {
    http.Client? client;
    IOSink? sink;
    try {
      client = http.Client();
      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 14; Mobile) KasaraniTeacherPortalApp/1.0';
      request.headers['Accept'] =
          'application/vnd.android.package-archive, application/octet-stream, */*';

      final response =
          await client.send(request).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw HttpException(
            'Download failed with status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final saveFile = File('${tempDir.path}/kmc_teacher_portal_update.apk');

      if (await saveFile.exists()) {
        try {
          await saveFile.delete();
        } catch (_) {}
      }

      sink = saveFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, receivedBytes, totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (await saveFile.exists() && await saveFile.length() > 0) {
        debugPrint(
            '[TeacherUpdateService] APK download complete (${await saveFile.length()} bytes)');
        return saveFile;
      }
      return null;
    } catch (e) {
      debugPrint('[TeacherUpdateService] APK download failed: $e');
      return null;
    } finally {
      try {
        if (sink != null) {
          await sink.flush();
          await sink.close();
        }
      } catch (_) {}
      client?.close();
    }
  }

  /// Launches the Android system package installer to update the app in-place.
  Future<bool> installApk(File apkFile) async {
    try {
      if (!await apkFile.exists()) {
        debugPrint('[TeacherUpdateService] APK file does not exist at ${apkFile.path}');
        return false;
      }

      final canInstall = await canRequestPackageInstalls();
      if (!canInstall) {
        debugPrint(
            '[TeacherUpdateService] Install unknown apps permission not granted. Prompting user...');
        await openInstallPermissionSettings();
      }

      final result = await OpenFilex.open(
        apkFile.path,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint(
          '[TeacherUpdateService] OpenFilex result: ${result.message} (${result.type})');
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('[TeacherUpdateService] Error triggering APK installer: $e');
      return false;
    }
  }
}
