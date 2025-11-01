import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminUserDetailView extends StatefulWidget {
  final User user;

  const AdminUserDetailView({
    super.key,
    required this.user,
  });

  @override
  State<AdminUserDetailView> createState() => _AdminUserDetailViewState();
}

class _AdminUserDetailViewState extends State<AdminUserDetailView> {
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _nameController;
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late TextEditingController _occupationController;

  late bool _isAdmin;
  late bool _isActive;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _emailController = TextEditingController(text: widget.user.email);
    _usernameController = TextEditingController(text: widget.user.username);
    _nameController = TextEditingController(text: widget.user.name);
    _fullNameController = TextEditingController(text: widget.user.fullName ?? '');
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _companyController = TextEditingController(text: widget.user.company ?? '');
    _addressController = TextEditingController(text: widget.user.address ?? '');
    _occupationController = TextEditingController(text: widget.user.occupation ?? '');
    _isAdmin = widget.user.isAdmin;
    _isActive = widget.user.isActive ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _emailController.text != widget.user.email ||
        _usernameController.text != widget.user.username ||
        _nameController.text != widget.user.name ||
        _fullNameController.text != (widget.user.fullName ?? '') ||
        _phoneController.text != (widget.user.phone ?? '') ||
        _companyController.text != (widget.user.company ?? '') ||
        _addressController.text != (widget.user.address ?? '') ||
        _occupationController.text != (widget.user.occupation ?? '') ||
        _isAdmin != widget.user.isAdmin ||
        _isActive != (widget.user.isActive ?? true);
  }

  Future<void> _handleSave() async {
    if (!_hasChanges) {
      setState(() {
        _isEditing = false;
      });
      return;
    }

    final viewModel = context.read<AdminViewModel>();
    final updatedUser = User(
      id: widget.user.id,
      email: _emailController.text.trim(),
      username: _usernameController.text.trim(),
      name: _nameController.text.trim(),
      isAdmin: _isAdmin,
      fullName: _fullNameController.text.trim().isEmpty
          ? null
          : _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      company: _companyController.text.trim().isEmpty
          ? null
          : _companyController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      isActive: _isActive,
      profileImageUrl: widget.user.profileImageUrl,
      createdAt: widget.user.createdAt,
      lastLoginAt: widget.user.lastLoginAt,
    );

    await viewModel.updateUser(updatedUser);
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detalles del Usuario'),
            Text(
              widget.user.email,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: () {
                _initializeControllers();
                setState(() {
                  _isEditing = false;
                });
              },
              child: const Text('Cancelar'),
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _handleSave : () {
              setState(() {
                _isEditing = true;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                widget.user.name.isNotEmpty
                    ? widget.user.name[0].toUpperCase()
                    : 'U',
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            // Edit/View Toggle
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Ver')),
                ButtonSegment(value: true, label: Text('Editar')),
              ],
              selected: {_isEditing},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _isEditing = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            // Form Fields
            if (_isEditing) ...[
              _buildEditableSection('Rol', Icons.admin_panel_settings, [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Usuario Normal')),
                    ButtonSegment(value: true, label: Text('Administrador')),
                  ],
                  selected: {_isAdmin},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _isAdmin = selection.first;
                    });
                  },
                ),
              ]),
              const SizedBox(height: 16),
              _buildEditableSection('Estado', Icons.circle, [
                SwitchListTile(
                  title: const Text('Usuario Activo'),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ]),
            ] else ...[
              _buildReadOnlySection('Rol', Icons.admin_panel_settings, [
                Chip(
                  label: Text(_isAdmin ? 'Administrador' : 'Usuario Normal'),
                  avatar: Icon(_isAdmin ? Icons.admin_panel_settings : Icons.person),
                ),
              ]),
              const SizedBox(height: 16),
              _buildReadOnlySection('Estado', Icons.circle, [
                Chip(
                  label: Text(_isActive ? 'Activo' : 'Inactivo'),
                  avatar: Icon(_isActive ? Icons.check_circle : Icons.circle_notifications),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            _buildTextField('Email', Icons.email, _emailController, enabled: _isEditing),
            const SizedBox(height: 16),
            _buildTextField('Usuario', Icons.person, _usernameController, enabled: _isEditing),
            const SizedBox(height: 16),
            _buildTextField('Nombre', Icons.badge, _nameController, enabled: _isEditing),
            const SizedBox(height: 16),
            _buildTextField('Nombre Completo', Icons.account_box, _fullNameController, enabled: _isEditing, optional: true),
            const SizedBox(height: 16),
            _buildTextField('Teléfono', Icons.phone, _phoneController, enabled: _isEditing, optional: true, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField('Empresa', Icons.business, _companyController, enabled: _isEditing, optional: true),
            const SizedBox(height: 16),
            _buildTextField('Ocupación', Icons.work, _occupationController, enabled: _isEditing, optional: true),
            const SizedBox(height: 16),
            _buildTextField('Dirección', Icons.location_on, _addressController, enabled: _isEditing, optional: true, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool enabled = true,
    bool optional = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label${optional ? ' (Opcional)' : ''}',
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildEditableSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlySection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

