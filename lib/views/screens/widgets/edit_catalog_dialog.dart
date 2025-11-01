import 'package:flutter/material.dart';
import '../../../models/catalog.dart';

class EditCatalogDialog extends StatefulWidget {
  final Catalog catalog;
  final Function(String name, String description, List<String> columns) onSave;

  const EditCatalogDialog({
    super.key,
    required this.catalog,
    required this.onSave,
  });

  @override
  State<EditCatalogDialog> createState() => _EditCatalogDialogState();
}

class _EditCatalogDialogState extends State<EditCatalogDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _columnsController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.catalog.name);
    _descriptionController =
        TextEditingController(text: widget.catalog.description);
    _columnsController =
        TextEditingController(text: widget.catalog.columns.join(', '));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _columnsController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final columns = _columnsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim(),
      columns,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar catálogo'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'El nombre es obligatorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _columnsController,
                  decoration: const InputDecoration(
                    labelText: 'Columnas separadas por comas',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleSave(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

