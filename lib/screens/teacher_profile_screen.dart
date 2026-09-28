import 'package:flutter/material.dart';
import '../data/mock_teacher_data.dart';
import '../theme/app_theme.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final profile = MockTeacherData.currentTeacher;
  bool _availableForBookings = true;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Faculty Profile & Portal'),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Faculty profile changes saved.')),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Profile Card
            _buildProfileCard(context),
            const SizedBox(height: 20),

            // Teaching Hours & Compensation Ledger
            _buildCompensationCard(context),
            const SizedBox(height: 20),

            // Studio Availability & Preferences
            _buildStudioPreferencesCard(context),
            const SizedBox(height: 20),

            // School Resources & Faculty Tools
            _buildFacultyResourcesCard(context),
            const SizedBox(height: 20),

            // Logout & Version Info
            _buildFooter(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.brandBlue, AppTheme.surfaceElevated],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: AppTheme.brandGreen, width: 2),
                ),
                child: Center(
                  child: Text(
                    profile.avatarInitials,
                    style: const TextStyle(
                      color: AppTheme.textWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: AppTheme.textWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.title,
                      style: const TextStyle(
                        color: AppTheme.accentSky,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FACULTY ID: ${profile.facultyId}',
                        style: const TextStyle(
                          color: AppTheme.brandGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderOutline),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.business_rounded, 'Department', profile.department),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.piano_rounded, 'Assigned Studio', profile.studio),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.email_outlined, 'Institutional Email', profile.email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_outlined, 'Contact', profile.phone),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.brandGreen),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textWhite,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompensationCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Teaching Hours & Earnings',
                style: TextStyle(
                  color: AppTheme.textWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.brandGold.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'PROCESSING PAYOUT',
                  style: TextStyle(
                    color: AppTheme.brandGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('September Hours', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      SizedBox(height: 4),
                      Text(
                        '38.5 hrs',
                        style: TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('38 sessions taught', style: TextStyle(color: AppTheme.brandGreen, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Total', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      SizedBox(height: 4),
                      Text(
                        'KES 69,300',
                        style: TextStyle(color: AppTheme.brandGreen, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text('@ KES 1,800/hr faculty rate', style: TextStyle(color: AppTheme.accentSky, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Generating PDF compensation voucher with KMC official seal...'),
                ),
              );
            },
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Download Monthly Statement (PDF)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudioPreferencesCard(BuildContext context) {
    return Material(
      color: AppTheme.surfaceCard,
      borderRadius: BorderRadius.circular(14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Studio Preferences & Working Hours',
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Accept Student Makeup Bookings',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Allow admin to schedule makeup lessons in Studio 3',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            value: _availableForBookings,
            activeThumbColor: AppTheme.brandGreen,
            onChanged: (val) {
              setState(() => _availableForBookings = val);
            },
          ),
          const Divider(color: AppTheme.borderOutline),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Drill Submission Push Alerts',
              style: TextStyle(color: AppTheme.textWhite, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Receive instant notifications when students upload video/audio',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            value: _notificationsEnabled,
            activeThumbColor: AppTheme.brandGreen,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFacultyResourcesCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderOutline),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KMC Faculty Resources',
            style: TextStyle(
              color: AppTheme.textWhite,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildResourceTile(
            Icons.menu_book_rounded,
            'Curriculum Syllabus & Rubrics',
            'ABRSM & Contemporary Grading guidelines',
          ),
          const SizedBox(height: 8),
          _buildResourceTile(
            Icons.library_music_rounded,
            'Sheet Music & Backing Tracks',
            'Cloudflare R2 Master repository',
          ),
          const SizedBox(height: 8),
          _buildResourceTile(
            Icons.support_agent_rounded,
            'Contact School Administration',
            'Direct line to KMC Academic Office',
          ),
        ],
      ),
    );
  }

  Widget _buildResourceTile(IconData icon, String title, String subtitle) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $title...')),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.brandGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Faculty logged out successfully.')),
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 16, color: AppTheme.danger),
            label: const Text(
              'Sign Out of Faculty Portal',
              style: TextStyle(color: AppTheme.danger),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.danger),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Kasarani Music Center — Teacher Portal v1.0.0 (Build 1)\nBuilt with Flutter & Material Design 3',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
