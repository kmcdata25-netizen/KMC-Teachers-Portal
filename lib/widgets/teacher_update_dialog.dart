import 'dart:io';

import 'package:flutter/material.dart';

import '../services/teacher_update_service.dart';
import '../theme/app_theme.dart';

/// Modal dialog that informs the teacher about a new portal update and provides
/// one-tap downloading and seamless in-place installation.
class TeacherUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const TeacherUpdateDialog({super.key, required this.updateInfo});

  /// Displays the update dialog modally.
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !updateInfo.forceUpdate,
        child: TeacherUpdateDialog(updateInfo: updateInfo),
      ),
    );
  }

  @override
  State<TeacherUpdateDialog> createState() => _TeacherUpdateDialogState();
}

class _TeacherUpdateDialogState extends State<TeacherUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  File? _downloadedApk;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    final file = await TeacherUpdateService.instance.downloadApk(
      widget.updateInfo.apkUrl,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
          });
        }
      },
    );

    if (!mounted) return;

    if (file != null && await file.exists()) {
      setState(() {
        _isDownloading = false;
        _downloadedApk = file;
      });
      // Immediately launch Android system installer
      await _install();
    } else {
      setState(() {
        _isDownloading = false;
        _errorMessage =
            'Failed to download update. Please verify your internet connection and try again.';
      });
    }
  }

  Future<void> _install() async {
    if (_downloadedApk == null) return;
    final success = await TeacherUpdateService.instance.installApk(_downloadedApk!);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not launch installer. Ensure "Install unknown apps" permission is allowed for KMC Teacher Portal.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderOutline, width: 1),
      ),
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with Portal Icon
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.brandGreen.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppTheme.brandGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Portal Update Available',
                        style: TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'KMC Faculty Portal v${info.latestVersion}',
                        style: const TextStyle(
                          color: AppTheme.brandGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Version diff pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOutline),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Installed: v${info.currentVersion}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppTheme.brandGreen, size: 14),
                  Text(
                    'Latest: v${info.latestVersion}',
                    style: const TextStyle(
                      color: AppTheme.brandGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Release Notes
            if (info.releaseNotes.isNotEmpty) ...[
              const Text(
                'WHAT\'S NEW',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderOutline),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Error display
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Progress or Action Buttons
            if (_isDownloading) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Downloading update package...',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: AppTheme.brandGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: AppTheme.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.brandGreen,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_totalBytes > 0)
                    Text(
                      '${_formatBytes(_receivedBytes)} of ${_formatBytes(_totalBytes)}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ] else if (_downloadedApk != null) ...[
              ElevatedButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.install_mobile_rounded, size: 18),
                label: const Text(
                  'Install Now',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandGreen,
                  foregroundColor: const Color(0xFF061C2D),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  if (!info.forceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textMuted,
                          side: const BorderSide(color: AppTheme.borderOutline),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: info.forceUpdate ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandGreen,
                        foregroundColor: const Color(0xFF061C2D),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Update Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
