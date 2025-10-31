import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/mongo_service.dart';

/// ViewModel para gestionar las operaciones administrativas
class AdminViewModel extends ChangeNotifier {
  final MongoService _mongoService = MongoService();

  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  User? _editingUser;
  bool _showEditForm = false;
  bool _showDeleteConfirmation = false;
  User? _userToDelete;

  List<User> get users => _users;
  User? get selectedUser => _selectedUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  User? get editingUser => _editingUser;
  bool get showEditForm => _showEditForm;
  bool get showDeleteConfirmation => _showDeleteConfirmation;
  User? get userToDelete => _userToDelete;

  /// Cargar la lista completa de usuarios
  Future<void> loadUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _users = await _mongoService.getAllUsers();
      print('✅ Usuarios cargados: ${_users.length}');
    } catch (e) {
      _errorMessage = 'Error al cargar usuarios: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seleccionar un usuario
  void selectUser(User user) {
    _selectedUser = user;
    _editingUser = user;
    notifyListeners();
  }

  /// Abrir el formulario de edición
  void openEditForm() {
    _showEditForm = true;
    notifyListeners();
  }

  /// Cerrar el formulario de edición
  void closeEditForm() {
    _showEditForm = false;
    _editingUser = null;
    notifyListeners();
  }

  /// Abrir el diálogo de confirmación de eliminación
  void openDeleteConfirmation(User user) {
    _userToDelete = user;
    _showDeleteConfirmation = true;
    notifyListeners();
  }

  /// Cerrar el diálogo de confirmación
  void closeDeleteConfirmation() {
    _showDeleteConfirmation = false;
    _userToDelete = null;
    notifyListeners();
  }

  /// Actualizar la información completa de un usuario
  Future<void> updateUser(User user) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updates = <String, dynamic>{
        'Email': user.email,
        'Username': user.username,
        'Name': user.name,
        if (user.fullName != null) 'FullName': user.fullName,
        if (user.phone != null) 'Phone': user.phone,
        if (user.company != null) 'Company': user.company,
        if (user.address != null) 'Address': user.address,
        if (user.occupation != null) 'Occupation': user.occupation,
        if (user.profileImageUrl != null) 'ProfileImageUrl': user.profileImageUrl,
        'Role': user.isAdmin ? 'admin' : 'user',
        'IsActive': user.isActive ?? true,
      };

      final success = await _mongoService.updateUser(user.id, updates);

      if (success) {
        _successMessage = 'Usuario actualizado correctamente';
        await loadUsers();
        closeEditForm();
      } else {
        _errorMessage = 'Error al actualizar usuario';
      }
    } catch (e) {
      _errorMessage = 'Error al actualizar usuario: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar un usuario
  Future<void> deleteUser(User user) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // Por ahora, desactivamos el usuario en lugar de eliminarlo
      final updates = {'IsActive': false};
      final success = await _mongoService.updateUser(user.id, updates);

      if (success) {
        _successMessage = 'Usuario desactivado correctamente';
        await loadUsers();
        closeDeleteConfirmation();
      } else {
        _errorMessage = 'Error al eliminar usuario';
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar usuario: $e';
      print('❌ Error: $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Limpiar mensajes
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}

