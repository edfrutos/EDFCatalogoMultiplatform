import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../utils/app_theme.dart';
import 'admin_users_list_view.dart';
import 'admin_catalogs_list_view.dart';
import 'admin_statistics_view.dart';
import 'admin_backups_view.dart';

enum AdminTab { users, catalogs, statistics, backups }

class AdminPanelView extends StatefulWidget {
  final User currentUser;

  const AdminPanelView({super.key, required this.currentUser});

  @override
  State<AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<AdminPanelView> {
  AdminTab _selectedTab = AdminTab.users;

  static const _tabs = [
    (tab: AdminTab.users,      icon: Icons.people_rounded,       label: 'Usuarios'),
    (tab: AdminTab.catalogs,   icon: Icons.library_books_rounded, label: 'Catálogos'),
    (tab: AdminTab.statistics, icon: Icons.bar_chart_rounded,    label: 'Estadísticas'),
    (tab: AdminTab.backups,    icon: Icons.cloud_upload_rounded,  label: 'Backups'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20, isWide ? 20 : 14, 20, isWide ? 20 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  cs.primary.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    width: isWide ? 44 : 36,
                    height: isWide ? 44 : 36,
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded,
                        size: isWide ? 24 : 20, color: cs.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Panel de Administración',
                          style: GoogleFonts.inter(
                            fontSize: isWide ? 20 : 17,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.currentUser.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: cs.onPrimary.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Tab bar ────────────────────────────────────────────────
          Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: isWide
                ? SegmentedButton<AdminTab>(
                    segments: _tabs.map((t) => ButtonSegment<AdminTab>(
                      value: t.tab,
                      label: Text(t.label,
                          style: GoogleFonts.inter(fontSize: 13)),
                      icon: Icon(t.icon, size: 18),
                    )).toList(),
                    selected: {_selectedTab},
                    onSelectionChanged: (s) =>
                        setState(() => _selectedTab = s.first),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _tabs.map((t) {
                        final sel = _selectedTab == t.tab;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            avatar: Icon(t.icon,
                                size: 16,
                                color: sel
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface.withValues(alpha: 0.6)),
                            label: Text(t.label,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                            selected: sel,
                            onSelected: (_) =>
                                setState(() => _selectedTab = t.tab),
                            showCheckmark: false,
                            selectedColor: cs.primaryContainer,
                            side: BorderSide(
                                color: sel
                                    ? cs.primary
                                    : cs.outlineVariant),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // ── Contenido ──────────────────────────────────────────────
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return switch (_selectedTab) {
      AdminTab.users      => const AdminUsersListView(),
      AdminTab.catalogs   => const AdminCatalogsListView(),
      AdminTab.statistics => const AdminStatisticsView(),
      AdminTab.backups    => const AdminBackupsView(),
    };
  }
}
