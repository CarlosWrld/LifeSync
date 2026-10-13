import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleAuthException implements Exception {
  const GoogleAuthException(this.mensaje);
  final String mensaje;
}

/// Autenticación nativa de Google para la aplicación Android.
class GoogleAuthService {
  GoogleAuthService._();
  static final instance = GoogleAuthService._();
  static const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  Future<void>? _initialization;

  Future<GoogleSignInAccount?> autenticar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const GoogleAuthException(
        'El acceso con Google está disponible en la app Android.',
      );
    }
    try {
      // Android obtiene las opciones de google-services.json mediante Gradle.
      // Inicializar aquí permite usar las cuentas locales sin conexión.
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      await FirebaseAuth.instance.signOut();
      await (_initialization ??= GoogleSignIn.instance.initialize(
        serverClientId: clientId.isEmpty ? null : clientId,
      ));
      // Siempre permite elegir una cuenta; no restaura sesiones silenciosamente.
      await GoogleSignIn.instance.signOut();
      final cuenta = await GoogleSignIn.instance.authenticate();
      final token = cuenta.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const GoogleAuthException(
          'Google no pudo verificar la cuenta. Intenta de nuevo.',
        );
      }
      final resultado = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: token),
      );
      if (resultado.user == null) {
        throw const GoogleAuthException(
          'Firebase no pudo verificar la cuenta.',
        );
      }
      return cuenta;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleAuthException(
          'Google no está configurado correctamente para esta versión de la app.',
        );
      }
      throw const GoogleAuthException(
        'No se pudo iniciar sesión con Google. Revisa tu conexión e intenta de nuevo.',
      );
    } on FirebaseAuthException catch (error) {
      throw GoogleAuthException(switch (error.code) {
        'operation-not-allowed' =>
          'El acceso con Google aún no está habilitado en Firebase.',
        'network-request-failed' =>
          'No se pudo conectar. Revisa tu conexión e intenta de nuevo.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        'account-exists-with-different-credential' =>
          'Este correo usa otro método de acceso en Firebase.',
        _ => 'No se pudo verificar tu cuenta con Firebase. Intenta de nuevo.',
      });
    } on FirebaseException {
      throw const GoogleAuthException(
        'No se pudo iniciar Firebase. Revisa la configuración de esta versión de la app.',
      );
    }
  }

  Future<void> cerrarSesion() async {
    try {
      if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
    } finally {
      if (_initialization != null) await GoogleSignIn.instance.signOut();
    }
  }
}
