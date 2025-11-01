import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/env_config.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  
  factory EmailService() => _instance;
  
  static EmailService get shared => _instance;

  final String apiKey;
  final String apiURL = "https://api.brevo.com/v3/smtp/email";

  EmailService._internal() : apiKey = EnvConfig.brevoApiKey {
    if (apiKey.isEmpty) {
      print("⚠️ EmailService: No se encontró BREVO_API_KEY");
    } else {
      print("✅ EmailService inicializado");
    }
  }

  Future<void> sendPasswordResetEmail({
    required String to,
    required String resetToken,
  }) async {
    const subject = "Recuperación de contraseña - EDF Catálogo";
    final htmlContent = """
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h2 style="color: #333;">Recuperación de contraseña</h2>
            <p>Has solicitado recuperar tu contraseña para EDF Catálogo.</p>
            <p>Tu token de recuperación es:</p>
            <div style="background-color: #f0f0f0; padding: 15px; border-radius: 5px; font-family: monospace; font-size: 18px; text-align: center; margin: 20px 0;">
                <strong>$resetToken</strong>
            </div>
            <p>Copia este código e introdúcelo en la aplicación para restablecer tu contraseña.</p>
            <p style="color: #666; font-size: 14px; margin-top: 30px;">Este token es válido por 1 hora.</p>
            <p style="color: #999; font-size: 12px; margin-top: 20px;">Si no solicitaste este cambio, ignora este mensaje.</p>
        </div>
    </body>
    </html>
    """;

    await sendEmail(
      to: to,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  Future<void> sendWelcomeEmail({
    required String to,
    required String name,
  }) async {
    const subject = "Bienvenido a EDF Catálogo";
    final htmlContent = """
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h2 style="color: #333;">¡Bienvenido, $name!</h2>
            <p>Tu cuenta en EDF Catálogo ha sido creada exitosamente.</p>
            <p>Ya puedes comenzar a crear y gestionar tus catálogos.</p>
            <p style="color: #666; font-size: 14px; margin-top: 30px;">Gracias por confiar en nosotros.</p>
        </div>
    </body>
    </html>
    """;

    await sendEmail(
      to: to,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  Future<void> sendContactMessage({
    required String from,
    required String name,
    required String message,
  }) async {
    const adminEmail = "edfrutos@gmail.com";
    final subject = "Nuevo mensaje de contacto - $name";
    final htmlContent = """
    <html>
    <body style="font-family: Arial, sans-serif; padding: 20px;">
        <h2>Nuevo mensaje de contacto</h2>
        <p><strong>De:</strong> $name ($from)</p>
        <p><strong>Mensaje:</strong></p>
        <div style="background-color: #f5f5f5; padding: 15px; border-left: 4px solid #007bff; margin: 10px 0;">
            ${message.replaceAll('\n', '<br>')}
        </div>
    </body>
    </html>
    """;

    await sendEmail(
      to: adminEmail,
      subject: subject,
      htmlContent: htmlContent,
      replyTo: from,
    );
  }

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    String? replyTo,
  }) async {
    if (apiKey.isEmpty) {
      throw EmailError("No se encontró la clave API de Brevo");
    }

    final url = Uri.parse(apiURL);

    final emailData = <String, dynamic>{
      "sender": {
        "name": "EDF Catálogo",
        "email": "noreply@edefrutos2025.xyz"
      },
      "to": [
        {"email": to}
      ],
      "subject": subject,
      "htmlContent": htmlContent,
    };

    if (replyTo != null) {
      emailData["replyTo"] = {"email": replyTo};
    }

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "api-key": apiKey,
      },
      body: jsonEncode(emailData),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage = response.body.isNotEmpty 
          ? response.body 
          : "Unknown error";
      print("❌ Error al enviar email: $errorMessage");
      throw EmailError(
        "Error al enviar email (código ${response.statusCode}): $errorMessage",
      );
    }

    print("✅ Email enviado exitosamente a $to");
  }
}

class EmailError implements Exception {
  final String message;

  EmailError(this.message);

  @override
  String toString() => message;
}

