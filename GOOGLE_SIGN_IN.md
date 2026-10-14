# Activar Google en LifeSync (Android)

El código usa `google_sign_in` 7 y conserva los datos en SQLite en este dispositivo.
Firebase Authentication verifica la identidad de Google antes de abrir la sesión local.
No solicita acceso a los mensajes de Gmail. La configuración OAuth y una
prueba en un dispositivo con Google Play Services son necesarias antes de considerar
el acceso real verificado. No se ha configurado para iOS, web ni Windows.

## Nuevo identificador Android y configuración verificada

Proyecto: `lifesync-112e4`. Nuevo paquete Android: `com.carlosjacoboperez.lifesync`.

El JSON actualizado incluye `com.carlosjacoboperez.lifesync`, con App ID
`1:703354705609:android:ce02127505689f4d55df18` y clientes OAuth Android y web.
También conserva la app anterior, lo cual es válido.
El procesamiento del JSON con Gradle generó recursos para la nueva app.
Esto verifica la configuración de compilación,
pero no confirma por sí solo un inicio de sesión real ni el estado del proveedor
en Firebase Console.

La nueva app Firebase debe conservar las dos SHA-1 indicadas abajo: debug para
`flutter run` y release para el APK de publicación. El JSON local actualizado
ya incluye la firma debug. Después de cambiar las huellas en Firebase, descarga
de nuevo el JSON y recompila; hot reload no actualiza los recursos nativos.

Se conserva el comportamiento original: acceso local con SQLite y acceso con
Google verificado mediante Firebase Authentication. El APK release también
incluye Firebase y el botón de Google. No hay variantes que desactiven estos servicios.
El acceso nativo con Google requiere un dispositivo con Google Play Services;
su funcionamiento en Fire OS no queda validado por esta compilación.

## Configurar Google

1. En Firebase Console, abre `lifesync-112e4` → **Configuración del proyecto →
   Agregar app → Android**. Registra `com.carlosjacoboperez.lifesync`.
2. Abre **Authentication → Método de acceso → Google**.
   Habilita el proveedor, elige un correo de soporte y guarda.
3. En la nueva app Android, registra la SHA-1 debug:
   `B2:BD:F0:6B:96:E0:AA:03:04:F9:3E:D5:6B:0F:C8:92:72:54:56:04`.
   Para APK firmados con la nueva clave de producción, registra además:
   - SHA-1: `E7:FD:A8:AA:B3:A8:31:A7:90:1E:5B:C0:FF:1E:D2:44:83:F7:DC:A5`
   - SHA-256: `96:63:36:AE:D4:BD:C5:EF:B2:18:76:62:41:E0:F8:B7:9D:9E:9B:5E:1F:1E:C4:EA:CE:D1:E7:C3:CC:98:C2:CF`
4. Descarga de nuevo `google-services.json` y reemplaza `android/app/google-services.json`.
   Comprueba que `client_info.android_client_info.package_name` sea el nuevo paquete.
   Debe incluir un cliente OAuth de tipo 3 (Web) en `oauth_client`.
5. Detén la app y ejecuta `flutter run`. No necesitas pasar un ID con `--dart-define`:
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
   - Nombre del paquete: `com.carlosjacoboperez.lifesync`
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
Esta alternativa también necesita un JSON Firebase válido para el nuevo paquete:
el ID OAuth por sí solo no configura Firebase Authentication.
El ID de cliente es público; no es una contraseña ni un secreto.
Si cambia el paquete o la firma, registra los nuevos datos en Google Cloud.
Para Google Play se utiliza la huella de la firma de la app en Play, no esta firma debug.

## Comprobación en teléfono

Prueba manual confirmada el 13 de octubre de 2026 en Samsung SM-S938B:
con el paquete nuevo, la configuración Firebase actualizada y firma debug,
seleccionar una cuenta de Google permite entrar a Inicio. La confirmación
corresponde a la versión debug instalada. También se confirmó que una tarea
permanece después de cerrar completamente la app, abrirla e iniciar sesión con
la misma cuenta. Queda pendiente repetir estas pruebas con el APK release.

La actualización con esquema local v6 también recuerda la sesión. Después de
instalarla, entra una vez, cierra completamente la app y vuelve a abrirla:
debe entrar directamente a Inicio con tu perfil y tus tareas. Repite sin conexión.
Después usa **Perfil > Cerrar sesión**, reinicia y comprueba que pide el acceso.
Esta nueva prueba en teléfono queda pendiente de confirmación del usuario.

- Pulsa **Continuar con Google**, selecciona una cuenta nueva y acepta.
- Verifica que se abre Inicio y que la cuenta es un usuario normal.
- Crea una tarea, cierra sesión y entra de nuevo con la misma cuenta: debe conservarse.
- Cancela el selector: debe regresar al formulario sin crear una cuenta.
- Para un nuevo acceso con Google sin conexión debe mostrar un error recuperable.
  Una sesión ya guardada permite abrir los datos locales sin conexión.
- Si el correo ya pertenece a una cuenta local, usa su contraseña. No se vinculan
  automáticamente cuentas por coincidencia de correo, incluido el administrador.

Las identidades de Google se asocian por su ID estable, no solo por correo.
No se guardan tokens de Google ni contraseñas de Gmail en SQLite.
Esto no sincroniza tareas entre dispositivos; si se añade un backend, este deberá
verificar los tokens de Google antes de dar acceso a los datos del servidor.

Documentación: https://pub.dev/packages/google_sign_in_android
Firebase: https://firebase.google.com/docs/auth/flutter/federated-auth
