# LifeSync para Amazon Appstore

## Estado de la entrega

La entrega conserva todas las funciones originales, incluido Google Sign-In
con Firebase y el acceso local con SQLite. Se cambia el identificador Android
y se utiliza la firma de producción. No se usan variantes por tienda.
El APK anterior `LifeSync-1.0.0-amazon-release.apk`, generado sin Firebase,
queda obsoleto; la nueva entrega se llama `LifeSync-1.0.0-release.apk`.

La entrega anterior se verificó con análisis sin errores, 37 pruebas aprobadas,
compilación release correcta y firma comprobada con apksigner. Se comprobó dentro
del APK el nuevo paquete, FirebaseInitProvider y el App ID Firebase de la nueva app.

El código ahora incorpora sesión persistente para correo y Google: restaura la
cuenta al abrir la app y elimina la sesión guardada desde Perfil > Cerrar sesión.
La migración a SQLite v6 conserva los datos y requiere iniciar sesión una vez.
Verificación de esta actualización: `flutter test`, 46 pruebas aprobadas,
incluidas restauración al reiniciar, cierre de sesión y migración sin pérdida de
datos. El análisis y la compilación debug quedaron pendientes porque se rechazó
el permiso de ejecución. No se instaló esta actualización ni se regeneró el
release: el APK de `output/apk` todavía corresponde a la entrega anterior.

## Distribución Android

- Application ID y namespace: `com.carlosjacoboperez.lifesync`.
- Actividad: `com.carlosjacoboperez.lifesync.MainActivity`.
- Build `release`, versión inicial `1.0.0+1`.
- APK universal: `armeabi-v7a`, `arm64-v8a` y `x86_64`; SDK mínimo 24,
  target SDK 36. Firma de producción RSA de 3072 bits, verificada con apksigner.
- Objetivo: tablets Fire OS compatibles con el SDK mínimo del APK.
  La interfaz táctil no se ha adaptado ni validado para Fire TV.
- El identificador de iOS y los de escritorio son independientes y no se
  modificaron para esta entrega Android.

El nuevo paquete se instala como una app distinta de `com.example.appmovil`.
No hereda automáticamente su SQLite, cuentas, fotos ni recordatorios locales.

## Cuentas y Firebase

El APK procesa `google-services.json` y conserva el proveedor nativo de
inicialización de Firebase. El archivo actualizado incluye el nuevo paquete,
el cliente OAuth web y la firma release. Gradle selecciona el nuevo App ID.
Sigue `GOOGLE_SIGN_IN.md` para la configuración y las limitaciones de validación.

Se mantiene el flujo de autenticación original por indicación del usuario.
El SDK nativo de Google Sign-In requiere Google Play Services. Fire OS no los
incluye, por lo que este APK no demuestra compatibilidad de ese acceso con
tablets Fire. No se ha sustituido por otro proveedor ni migrado las cuentas.

## Firma de producción

Se utiliza la clave local `android/lifesync-release.jks`, alias `lifesync`.
Las contraseñas y ruta están en `android/key.properties`. Ambos archivos están
excluidos de Git. No se utiliza la firma debug para release.

Guarda **ambos archivos** en un respaldo privado y seguro. Reutiliza la misma
clave en las actualizaciones; no vuelvas a generarla ni publiques las contraseñas.
El script `tool/generar_clave_release.ps1` solo es para crear la primera clave
y rechaza sobrescribir archivos existentes.

Huella SHA-256 del certificado de producción:

`96:63:36:AE:D4:BD:C5:EF:B2:18:76:62:41:E0:F8:B7:9D:9E:9B:5E:1F:1E:C4:EA:CE:D1:E7:C3:CC:98:C2:CF`

## Compilar y comprobar

Desde la raíz del proyecto:

```powershell
flutter analyze
flutter test
flutter build apk --release
```

Salida de Flutter: `build/app/outputs/flutter-apk/app-release.apk`.
Copia para entregar: `output/apk/LifeSync-1.0.0-release.apk`, acompañada de
su archivo `.sha256` para comprobar la integridad.
Para versiones posteriores aumenta `version` en `pubspec.yaml`, incluido el
número de compilación después de `+`.

Antes de enviar a Amazon, instala el APK en una tablet Fire y prueba el registro,
acceso, tareas, eventos, hábitos, foto de perfil y notificaciones. Confirma que
los datos sobreviven al cerrar y abrir la app, y revisa los permisos del sistema.
Las pruebas automáticas y la verificación de firma no sustituyen esa prueba real.

La compilación no publica la app. En Amazon Developer Console hay que cargar el
APK, seleccionar dispositivos compatibles y completar ficha, privacidad,
clasificación y revisión. Si Amazon vuelve a firmar el archivo distribuido,
su certificado será distinto del certificado del APK local.

Fuentes:
- [Enviar una app a Amazon](https://developer.amazon.com/docs/app-submission/submitting-apps-to-amazon-appstore.html)
- [Fire OS y servicios de Google](https://developer.amazon.com/docs/fire-tablets/fire-os-7.html)
- [Registrar el paquete Android en Firebase](https://firebase.google.com/docs/android/setup)
- [Dependencias de Firebase y Google Play Services](https://firebase.google.com/docs/android/android-play-services)
