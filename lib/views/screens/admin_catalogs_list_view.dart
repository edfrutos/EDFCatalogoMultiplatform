import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/catalog.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../services/mongo_service.dart';
import 'catalog_detail_view.dart';

class AdminCatalogsListView extends StatefulWidget {
  const AdminCatalogsListView({super.key});

  @override
  State<AdminCatalogsListView> createState() => _AdminCatalogsListViewState();
}

class _AdminCatalogsListViewState extends State<AdminCatalogsListView> {
  final _searchController = TextEditingController();
  String _searchText = '';
  List<Catalog> _catalogs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthViewModel>().currentUser;
      if (user != null) {
        _catalogs = await MongoService().getCatalogs(
          user.id,
          isAdmin: user.isAdmin,
          userEmail: user.email,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar catálogos: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Catalog> _getFiltered() {
    if (_searchText.isEmpty) return _catalogs;
    final q = _searchText.toLowerCase();
    return _catalogs
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _getFiltered();

    return Column(
      children: [
        // ── Toolbar ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Catálogos',
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${_catalogs.length} en total',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: cs.primary,
                onPressed: _isLoading ? null : _load,
                tooltip: 'Recargar',
              ),
            ],
          ),
        ),

        // ── Búsqueda ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o descripción...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _searchText = v),
          ),
        ),
        const SizedBox(height: 8),

        // ── Lista ─────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: cs.primary),
                      const SizedBox(height: 14),
                      Text('Cargando catálogos...',
                          style: GoogleFonts.inter(
                              color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge),
                            ),
                            child: Icon(
                                _searchText.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.library_books_rounded,
                                size: 36,
                                color: cs.onSurface.withValues(alpha: 0.35)),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchText.isNotEmpty
                                ? 'Sin resultados'
                                : 'Sin catálogos',
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final cat = filtered[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CatalogDetailView(catalog: cat),
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLarge),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: cs.primaryContainer,
                                        borderRadius:
                                            BorderRadius.circular(
                                                AppTheme.radiusMedium),
                                      ),
                                      child: Icon(
                                          Icons.library_books_rounded,
                                          size: 22,
                                          color: cs.onPrimaryContainer),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cat.name,
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14),
                                          ),
                                          if (cat.description.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              cat.description,
                                              style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.55)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              _InfoChip(
                                                  icon: Icons.table_rows_rounded,
                                                  label: '${cat.rows.length} filas',
                                                  cs: cs),
                                              const SizedBox(width: 6),
                                              _InfoChip(
                                                  icon: Icons.view_column_rounded,
                                                  label: '${cat.columns.length} cols',
                                                  cs: cs),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded,
                                        color: cs.onSurface.withValues(alpha: 0.35)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  const _InfoChip(
      {required this.icon, required this.label, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: cs.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}
