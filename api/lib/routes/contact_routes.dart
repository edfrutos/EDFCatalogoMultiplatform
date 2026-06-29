import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../db/mongo_db.dart';
import '../config.dart';
import 'helpers.dart';

Router contactRoutes() {
  final router = Router();

  // POST /api/contact — guarda mensaje y envía email de notificación (sin auth)
  router.post('/', (Request req) async {
    try {
      final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final name = body['name']?.toString().trim() ?? '';
      final email = body['email']?.toString().trim() ?? '';
      final subject = body['subject']?.toString().trim() ?? '';
      final message = body['message']?.toString().trim() ?? '';

      if (name.isEmpty || email.isEmpty || message.isEmpty) {
        return error('name, email y message son requeridos', 400);
      }

      // Guardar en MongoDB
      final coll = await MongoDb.instance.collection('contacts');
      await coll.insertOne({
        'name': name,
        'email': email,
        'subject': subject.isEmpty ? '(sin asunto)' : subject,
        'message': message,
        'createdAt': DateTime.now().toUtc(),
        'read': false,
      });

      // Enviar email de notificación (no crítico — si falla el mensaje ya está guardado)
      try {
        if (Config.brevoApiKey.isNotEmpty) {
          // Opción A: Brevo API (si BREVO_API_KEY está configurada)
          await _sendBrevoNotification(
            name: name, email: email,
            subject: subject.isEmpty ? '(sin asunto)' : subject,
            message: message,
          );
        } else if (Config.smtpUser.isNotEmpty && Config.smtpPass.isNotEmpty) {
          // Opción B: SMTP (usa SMTP_USER / SMTP_PASS del .env — Gmail configurado)
          await _sendSmtpNotification(
            name: name, email: email,
            subject: subject.isEmpty ? '(sin asunto)' : subject,
            message: message,
          );
        } else {
          print('⚠️ contact_routes: sin BREVO_API_KEY ni credenciales SMTP — '
              'mensaje guardado en MongoDB sin notificación por email');
        }
      } catch (e) {
        print('⚠️ contact_routes: email falló (mensaje guardado igualmente): $e');
      }

      return ok({'saved': true});
    } catch (e) {
      return error('$e', 500);
    }
  });

  return router;
}

// ── SMTP — Gmail u otro servidor ──────────────────────────────────────────────

Future<void> _sendSmtpNotification({
  required String name,
  required String email,
  required String subject,
  required String message,
}) async {
  final user = Config.smtpUser;
  final pass = Config.smtpPass;
  final from = Config.smtpFrom.isNotEmpty ? Config.smtpFrom : user;
  final to = Config.notificationEmail;
  final host = Config.smtpHost;
  final port = Config.smtpPort;

  // Construir SmtpServer apropiado según el host
  final SmtpServer smtpServer;
  if (host.contains('gmail')) {
    smtpServer = gmail(user, pass);   // helper de mailer: SSL 465
  } else {
    smtpServer = SmtpServer(
      host,
      port: port,
      username: user,
      password: pass,
      ssl: port == 465,
    );
  }

  final htmlBody = _buildHtml(name: name, email: email,
      subject: subject, message: message);

  final msg = Message()
    ..from = Address(from, 'EDF Catálogo')
    ..recipients.add(to)
    ..replyTo = Address(email, name)
    ..subject = 'Contacto: $subject — $name'
    ..html = htmlBody;

  await send(msg, smtpServer);
  print('✅ Email de contacto (SMTP) enviado a $to');
}

// ── Brevo API — opcional, solo si BREVO_API_KEY está configurada ──────────────

Future<void> _sendBrevoNotification({
  required String name,
  required String email,
  required String subject,
  required String message,
}) async {
  final payload = {
    'sender': {'name': 'EDF Catálogo', 'email': 'noreply@edefrutos2025.xyz'},
    'to': [{'email': Config.notificationEmail}],
    'replyTo': {'email': email},
    'subject': 'Contacto: $subject — $name',
    'htmlContent': _buildHtml(name: name, email: email,
        subject: subject, message: message),
  };

  final res = await http.post(
    Uri.parse('https://api.brevo.com/v3/smtp/email'),
    headers: {
      'Content-Type': 'application/json',
      'api-key': Config.brevoApiKey,
    },
    body: jsonEncode(payload),
  );

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Brevo error ${res.statusCode}: ${res.body}');
  }
  print('✅ Email de contacto (Brevo) enviado a ${Config.notificationEmail}');
}

// ── HTML compartido ───────────────────────────────────────────────────────────

String _buildHtml({
  required String name,
  required String email,
  required String subject,
  required String message,
}) =>
    '''
<html>
<body style="font-family:Arial,sans-serif;padding:20px;background:#f5f5f5;">
  <div style="max-width:600px;margin:0 auto;background:white;padding:30px;border-radius:10px;">
    <h2 style="color:#333;">Nuevo mensaje de contacto</h2>
    <p><strong>De:</strong> $name ($email)</p>
    <p><strong>Asunto:</strong> $subject</p>
    <p><strong>Mensaje:</strong></p>
    <div style="background:#f0f0f0;padding:15px;border-left:4px solid #007bff;margin:10px 0;">
      ${message.replaceAll('\n', '<br>')}
    </div>
  </div>
</body>
</html>
''';
