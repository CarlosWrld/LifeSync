# LifeSync

## Descargar e instalar en Android

**[Descargar LifeSync APK](https://github.com/CarlosWrld/LifeSync/releases/download/v1.0.0-preview.1/LifeSync-1.0.0-release.apk)** ·
[Detalles de la versión de prueba](https://github.com/CarlosWrld/LifeSync/releases/tag/v1.0.0-preview.1)

Requiere Android 7.0 o posterior. Descarga el APK desde tu teléfono, ábrelo y
autoriza la instalación desde tu navegador si Android lo solicita. El acceso
con Google requiere Google Play Services. No necesitas compilar el proyecto.

La descarga está en **Releases > Assets**, con su archivo de verificación SHA-256.
Si ya tienes una versión debug instalada, consulta las notas de la versión:
la firma es distinta y desinstalar la app elimina sus datos locales.

## APK para Amazon Appstore

El paquete Android es `com.carlosjacoboperez.lifesync`. Compila con
`flutter build apk --release` usando la clave de producción local.
Se conservan el acceso con Google mediante Firebase y las cuentas locales existentes.
El JSON del nuevo paquete está validado.
Consulta [AMAZON_APPSTORE.md](AMAZON_APPSTORE.md) para firma, pruebas y distribución.
La configuración Firebase y las firmas se describen en
[GOOGLE_SIGN_IN.md](GOOGLE_SIGN_IN.md).

## Git y GitHub

Consulta [VERSIONAMIENTO.md](VERSIONAMIENTO.md) para conectar el repositorio,
trabajar con ramas, revisar cambios y marcar entregas. Al clonar el proyecto,
restaura la configuración local de Firebase según
[GOOGLE_SIGN_IN.md](GOOGLE_SIGN_IN.md) antes de compilar Android.

Aplicación móvil Flutter para Android e iOS con Dashboard (Inicio), Tareas,
Calendario, Hábitos y Perfil. Mantiene el tema oscuro, tarjetas y formularios del proyecto.

## Uso

1. Ejecuta `flutter pub get` y `flutter run` en un dispositivo o emulador móvil.
2. Selecciona **Crear una cuenta**. La primera cuenta local recibe el rol `admin`;
   las siguientes reciben `usuario`. No hay credenciales predeterminadas ni selector de rol.
3. Inicia sesión con el correo y contraseña registrados en ese dispositivo.
4. Un administrador puede abrir **Perfil → Panel administrador** para consultar
   nombre, correo, rol y proveedor de las cuentas locales.
5. Crea, edita, completa y elimina tareas y eventos; registra, completa o reinicia
   el progreso de hábitos. Los cambios se guardan antes de actualizar la pantalla.

## Ícono de la app

El logo proporcionado se usa como ícono de inicio en Android e iOS. El original
se conserva en `assets/branding/logo_original.png`; `icono_app.png` es la versión
cuadrada de 1024 px. Se mantiene la proporción de la imagen y el fondo oscuro.
Android incluye recursos adaptativos con margen para las distintas formas del launcher.

Para regenerar los recursos desde Windows:
`powershell -NoProfile -ExecutionPolicy Bypass -File tool/generar_iconos.ps1`.

Compila y vuelve a ejecutar la app para ver el nuevo ícono; hot reload no actualiza
los recursos nativos. No hace falta desinstalar ni borrar los datos de la app.

## Recordatorios

- Las tareas pendientes avisan cada día a la hora elegida. Si la hora ya pasó,
  el primer aviso será mañana. Al completarlas o eliminarlas se cancela el aviso.
- Los eventos pendientes avisan una sola vez en su fecha y hora. No se programan
  eventos pasados. Editar el texto, la hora o la fecha actualiza el recordatorio.
- El aviso muestra el título escrito por el usuario y usa la zona horaria del teléfono.
- Al entrar se solicitan permisos de notificaciones y, en Android, de alarmas
  exactas. En **Perfil → Recordatorios de tareas y eventos** puedes reintentarlo;
  el engrane abre los ajustes. Sin permiso de alarmas exactas, Android puede retrasar
  los avisos y la app muestra ese estado.
- Los avisos quedan programados en el teléfono aunque cierres la app; Android
  los recupera al reiniciar el dispositivo. Cerrar sesión explícitamente los cancela.
- El sistema puede limitar los avisos por ahorro de batería o cierre forzado.
  iOS admite 64 recordatorios pendientes; se priorizan los más cercanos y se
  actualizan al volver a la app. Android se limita a 500 para evitar exceder
  el límite de algunos dispositivos.

Para comprobarlo en un teléfono, reinicia completamente la app después de compilar
(hot reload no incorpora los plugins nativos). Acepta los permisos, crea una tarea
y un evento de hoy para dos horas distintas dentro de unos minutos y deja la app
en segundo plano. Verifica el texto de ambos avisos; repite editando, completando
o eliminando antes de la hora. Comprueba también el cierre de sesión y el reinicio
del teléfono. La entrega real requiere un dispositivo o emulador móvil.

Pruebas de programación y formularios:
`flutter test test/notificaciones_test.dart test/horarios_test.dart test/widget_test.dart`.

## Datos locales

- En **Perfil → Editar perfil** puedes cambiar tu nombre y elegir o quitar una
  foto de la galería. **Guardar cambios** actualiza el perfil y el saludo de Inicio;
  **Cancelar** descarta la edición. La foto se reduce al seleccionarla en móvil
  y se guarda en SQLite (máximo 1 MB), sin depender del archivo de la galería.
- El esquema v5 añade la foto sin borrar cuentas ni tareas. El nombre y la foto
  permanecen al volver a entrar, también en cuentas de Google; son locales a esta
  instalación. Tras agregar el selector de fotos, vuelve a ejecutar `flutter run`
  con la app detenida para cargar el plugin nativo.

- `lib/servicios/database_helper.dart` abre `lifesync.db` en el directorio
  privado de bases de datos de la aplicación mediante `sqflite` y `path`.
- Tablas: `usuarios`, `tareas`, `habitos`, `eventos` y `sesion_activa`.
- Cada registro de organización pertenece a un `usuario_id`, con clave foránea
  e índice. Las lecturas, actualizaciones y eliminaciones se limitan a la sesión.
- Correos normalizados (sin espacios exteriores y en minúsculas), con restricción
  UNIQUE. Contraseñas nuevas de al menos ocho caracteres, almacenadas como
  PBKDF2-HMAC-SHA256 con salt aleatorio y 600000 iteraciones, calculadas en un isolate.
- El esquema v6 recuerda la cuenta autenticada en `sesion_activa`, dentro de la
  base privada. Al cerrar completamente la app y abrirla se recuperan la sesión,
  el perfil y sus datos, tanto con correo como con Google, incluso sin conexión.
  Solo se guarda el ID local de la cuenta, sin copiar tokens ni contraseñas.
  **Perfil > Cerrar sesión** elimina ese registro sin borrar cuentas ni tareas.
  Al actualizar desde v5 hay que entrar una vez: antes no se guardaba la sesión.
- El esquema v2 migra el helper v1 conservando IDs y datos. Normaliza correos,
  convierte contraseñas antiguas a hashes y asigna administrador a la cuenta más
  antigua si no existía uno. Correos equivalentes se combinan bajo la cuenta más
  antigua (con su contraseña), conservando sus registros relacionados.
  Si hay registros sin usuario, la migración se revierte sin borrarlos.
- Los datos de ejemplo que sólo existían en memoria no son recuperables.
- Las cuentas y datos pertenecen a esta instalación. Desinstalar o borrar los
  datos de la aplicación elimina la base local, incluida la sesión guardada.
- La ejecución web y Windows no está habilitada para la aplicación móvil.
  `sqflite_common_ffi` se usa únicamente en pruebas de escritorio.

## Verificación

`flutter analyze`

`flutter test`

Las pruebas usan SQLite real en archivos temporales para verificar registro,
duplicados, autenticación, roles, aislamiento entre usuarios, CRUD, persistencia,
claves foráneas y migración. Las pruebas de widgets verifican los formularios
de acceso y el rechazo del panel sin sesión.
