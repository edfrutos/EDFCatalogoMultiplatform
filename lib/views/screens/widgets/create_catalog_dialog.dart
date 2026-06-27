import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/app_theme.dart';

class CreateCatalogDialog extends StatefulWidget {
  final Function(String name, String description, List<String> columns) onCreate;

  const CreateCatalogDialog({super.key, required this.onCreate});

  @override
  State<CreateCatalogDialog> createState() => _CreateCatalogDialogState();
}

class _CreateCatalogDialogState extends State<CreateCatalogDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _colsCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _colsCtrl.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (!_formKey.currentState!.validate()) return;

    final columns = _colsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (!columns.any((c) => c.toLowerCase() == 'fecha')) {
      columns.insert(0, 'Fecha');
    }

    widget.onCreate(
      _nameCtrl.text.trim(),
      _descCtrl.text.trim(),
      columns,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.library_add_rounded, color: cs.primary, size: 28),
      title: Text('Nuevo catálogo',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.label_rounded, size: 18),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  prefixIcon: Icon(Icons.description_rounded, size: 18),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _colsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Columnas separadas por comas',
                  hintText: 'Ej: Nombre, Precio, Categoría',
                  prefixIcon: Icon(Icons.view_column_rounded, size: 18),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleCreate(),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La columna "Fecha" se añade automáticamente si no la incluyes.',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.55)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _handleCreate,
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Crear catálogo'),
        ),
      ],
    );
  }
}
