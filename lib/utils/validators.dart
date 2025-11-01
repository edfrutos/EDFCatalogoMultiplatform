/// Utilidades para validación de datos
class Validators {
  /// Valida un email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return 'Por favor ingresa un email válido';
    }
    
    return null;
  }

  /// Valida una contraseña
  static String? validatePassword(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    
    if (value.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres';
    }
    
    return null;
  }

  /// Valida que las contraseñas coincidan
  static String? validatePasswordMatch(String? value, String? otherValue) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    
    if (value != otherValue) {
      return 'Las contraseñas no coinciden';
    }
    
    return null;
  }

  /// Valida un campo requerido
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Este campo'} es requerido';
    }
    return null;
  }

  /// Valida un número
  static String? validateNumber(String? value, {
    double? min,
    double? max,
    bool allowDecimal = true,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es requerido';
    }
    
    final number = allowDecimal 
        ? double.tryParse(value)
        : int.tryParse(value)?.toDouble();
    
    if (number == null) {
      return 'Por favor ingresa un número válido';
    }
    
    if (min != null && number < min) {
      return 'El valor debe ser mayor o igual a $min';
    }
    
    if (max != null && number > max) {
      return 'El valor debe ser menor o igual a $max';
    }
    
    return null;
  }

  /// Valida una fecha
  static String? validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'La fecha es requerida';
    }
    
    try {
      DateTime.parse(value);
      return null;
    } catch (e) {
      return 'Por favor ingresa una fecha válida';
    }
  }

  /// Valida una URL
  static String? validateUrl(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'La URL es requerida' : null;
    }
    
    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return 'Por favor ingresa una URL válida (debe comenzar con http:// o https://)';
      }
      return null;
    } catch (e) {
      return 'Por favor ingresa una URL válida';
    }
  }

  /// Valida el largo de un texto
  static String? validateLength(String? value, {
    int? minLength,
    int? maxLength,
    String? fieldName,
  }) {
    if (value == null) {
      return null;
    }
    
    if (minLength != null && value.length < minLength) {
      return '${fieldName ?? 'Este campo'} debe tener al menos $minLength caracteres';
    }
    
    if (maxLength != null && value.length > maxLength) {
      return '${fieldName ?? 'Este campo'} debe tener máximo $maxLength caracteres';
    }
    
    return null;
  }

  /// Valida un nombre de usuario
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre de usuario es requerido';
    }
    
    if (value.length < 3) {
      return 'El nombre de usuario debe tener al menos 3 caracteres';
    }
    
    if (value.length > 30) {
      return 'El nombre de usuario debe tener máximo 30 caracteres';
    }
    
    // Solo letras, números, guiones y guiones bajos
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!usernameRegex.hasMatch(value)) {
      return 'El nombre de usuario solo puede contener letras, números, guiones y guiones bajos';
    }
    
    return null;
  }

  /// Valida formato de teléfono (básico)
  static String? validatePhone(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'El teléfono es requerido' : null;
    }
    
    // Remover espacios, guiones, paréntesis
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Debe contener solo números y tener al menos 7 dígitos
    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'El teléfono solo puede contener números';
    }
    
    if (cleaned.length < 7) {
      return 'El teléfono debe tener al menos 7 dígitos';
    }
    
    if (cleaned.length > 15) {
      return 'El teléfono no puede tener más de 15 dígitos';
    }
    
    return null;
  }

  /// Valida formato de código de recuperación (6 dígitos)
  static String? validateResetCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El código es requerido';
    }
    
    if (value.length != 6) {
      return 'El código debe tener 6 dígitos';
    }
    
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'El código solo puede contener números';
    }
    
    return null;
  }

  /// Valida un valor de celda de catálogo según reglas personalizadas
  static String? validateCatalogCell(String? value, {
    required String columnName,
    String? dataType, // 'text', 'number', 'date', 'url', 'email'
    int? minLength,
    int? maxLength,
    double? minValue,
    double? maxValue,
    bool required = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return required ? '$columnName es requerido' : null;
    }
    
    switch (dataType?.toLowerCase()) {
      case 'number':
        return validateNumber(value, min: minValue, max: maxValue);
      case 'date':
        return validateDate(value);
      case 'url':
        return validateUrl(value, required: required);
      case 'email':
        return validateEmail(value);
      case 'text':
      default:
        return validateLength(
          value,
          minLength: minLength,
          maxLength: maxLength,
          fieldName: columnName,
        );
    }
  }

  /// Combina múltiples validadores
  static String? validateMultiple(List<String? Function()> validators) {
    for (final validator in validators) {
      final result = validator();
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

