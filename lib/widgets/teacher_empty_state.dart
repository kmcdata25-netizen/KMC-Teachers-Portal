import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standard, professional offline / empty state display for Kasarani Music Center Teacher Portal.
/// Accurately differentiates between:
/// 1. True offline/network errors: "Data not available. Please connect to the internet."
/// 2. Empty database records: "No records found in database."
class TeacherEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final VoidCallback? onAction;
  final String actionLabel;
  final bool isActionLoading;

  const TeacherEmptyState({
    super.key,
    this.title = 'Data Not Available',
    this.message = 'Data not available. Please connect to the internet.',
    this.icon = Icons.wifi_off_rounded,
    this.iconColor,
    this.iconBgColor,
    this.onAction,
    this.actionLabel = 'Retry Connection',
    this.isActionLoading = false,
  });

  /// Factory for when network or connection to Supabase fails
  factory TeacherEmptyState.offline({
    String title = 'Connection Error',
    String message = 'Data not available. Please connect to the internet.',
    VoidCallback? onRetry,
    bool isRetrying = false,
  }) {
    return TeacherEmptyState(
      title: title,
      message: message,
      icon: Icons.wifi_off_rounded,
      iconColor: AppTheme.accentCoral,
      iconBgColor: AppTheme.accentCoral.withValues(alpha: 0.12),
      onAction: onRetry,
      actionLabel: 'Retry Connection',
      isActionLoading: isRetrying,
    );
  }

  /// Factory for when connected successfully to Supabase, but the database table has 0 rows
  factory TeacherEmptyState.empty({
    required String title,
    required String message,
    IconData icon = Icons.inbox_outlined,
    VoidCallback? onRefresh,
    bool isRefreshing = false,
    String actionLabel = 'Refresh',
  }) {
    return TeacherEmptyState(
      title: title,
      message: message,
      icon: icon,
      iconColor: AppTheme.brandGold,
      iconBgColor: AppTheme.brandGold.withValues(alpha: 0.12),
      onAction: onRefresh,
      actionLabel: actionLabel,
      isActionLoading: isRefreshing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppTheme.accentCoral;
    final effectiveIconBgColor = iconBgColor ?? effectiveIconColor.withValues(alpha: 0.12);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.borderOutline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: effectiveIconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: effectiveIconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: isActionLoading ? null : onAction,
              icon: isActionLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
              label: Text(
                isActionLoading ? 'Loading...' : actionLabel,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.neonGreen,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
