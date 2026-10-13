# Activar Google en LifeSync (Android)

El código usa `google_sign_in` 7 y conserva los datos en SQLite en este dispositivo.
Firebase Authentication verifica la identidad de Google antes de abrir la sesión local.
No solicita acceso a los mensajes de Gmail. La configuración OAuth y una
prueba en un dispositivo con Google Play Services son necesarias antes de considerar
el acceso real verificado. No se ha configurado para iOS, web ni Windows.

## Configuración de Firebase (actual)

Proyecto: `lifesync-112e4`. App Android: `com.example.appmovil`.

1. En Firebase Console, abre **Authentication → Método de acceso → Google**.
   Habilita el proveedor, elige un correo de soporte y guarda.
2. En **Configuración del proyecto → Tus apps → Android**, registra la SHA-1:
   `B2:BD:F0:6B:96:E0:AA:03:04:F9:3E:D5:6B:0F:C8:92:72:54:56:04`.
3. Descarga de nuevo `google-services.json` y reemplaza `android/app/google-services.json`.
   Debe incluir un cliente OAuth de tipo 3 (Web) en `oauth_client`.
4. Detén la app y ejecuta `flutter run`. No necesitas pasar un ID con `--dart-define`:
   el complemento de Google Services toma la configuración del JSON.

Firebase se inicializa al pulsar el botón de Google. El acceso local por contraseña
continúa usando SQLite. Cerrar sesión también cierra Firebase y el SDK de Google.
Las cuentas locales existentes no se migran a Firebase ni se vinculan automáticamente.

## Configuración manual de OAuth (alternativa avanzada)

1. En https://console.cloud.google.com/ crea un proyecto llamado LifeSync.
2. Abre **Google Auth Platform** y completa la información de marca/contacto.
   Selecciona audiencia externa. Si el proyecto está en modo de prueba, agrega las
   cuentas con las que probarás en la lista de usuarios de prueba.
3. En **Clientes**, crea un cliente OAuth de tipo **Android**:
   - Nombre del paquete: `com.example.appmovil`
   - SHA-1 de la firma debug de esta computadora:
     `B2:BD:F0:6B:96:E0:AA:03:04:F9:3E:D5:6B:0F:C8:92:72:54:56:04`
4. En el mismo proyecto crea otro cliente OAuth de tipo **Aplicación web**.
   Copia su ID terminado en `.apps.googleusercontent.com`.
   Para este flujo Android no necesitas orígenes JavaScript ni URLs de redirección.
   No copies el secreto de cliente a la app.
5. Detén la aplicación y ejecútala pasando el ID de tipo web:

```powershell
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=TU_ID_WEB.apps.googleusercontent.com
```

Para generar un APK, pasa el mismo `--dart-define` a `flutter build apk`.
El ID de cliente es público; no es una contraseña ni un secreto.
Si cambia el paquete o la firma, registra los nuevos datos en Google Cloud.
Para Google Play se utiliza la huella de la firma de la app en Play, no esta firma debug.

## Comprobación en teléfono

- Pulsa **Continuar con Google**, selecciona una cuenta nueva y acepta.
- Verifica que se abre Inicio y que la cuenta es un usuario normal.
- Crea una tarea, cierra sesión y entra de nuevo con la misma cuenta: debe conservarse.
- Cancela el selector: debe regresar al formulario sin crear una cuenta.
- Prueba sin conexión: debe mostrar un error recuperable.
- Si el correo ya pertenece a una cuenta local, usa su contraseña. No se vinculan
  automáticamente cuentas por coincidencia de correo, incluido el administrador.

Las identidades de Google se asocian por su ID estable, no solo por correo.
No se guardan tokens de Google ni contraseñas de Gmail en SQLite.
Esto no sincroniza tareas entre dispositivos; si se añade un backend, este deberá
verificar los tokens de Google antes de dar acceso a los datos del servidor.

Documentación: https://pub.dev/packages/google_sign_in_android
Firebase: https://firebase.google.com/docs/auth/flutter/federated-auth
