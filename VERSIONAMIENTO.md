# Versionamiento de LifeSync

Usamos `main` como rama principal y una rama `feature/...` por funcionalidad.
El primer commit conserva el estado actual del proyecto; los cambios siguientes
se registran de forma incremental. No se reconstruye un historial ficticio de
funcionalidades desarrolladas antes de usar Git.

## Conectar GitHub por primera vez

1. En https://github.com/new crea un repositorio llamado `lifesync` (o el nombre
   que prefieras). Elige su visibilidad. Déjalo vacío: no agregues README,
   licencia ni `.gitignore`, porque este proyecto ya tiene archivos locales.
2. Sustituye `TU_USUARIO` y el nombre del repositorio en el comando siguiente.
   Ejecútalo desde la carpeta `appmovil`:

```powershell
git remote add origin https://github.com/TU_USUARIO/lifesync.git
git remote -v
git push -u origin main
```

Git puede solicitar que inicies sesión en GitHub. Si el repositorio ya contiene
commits, revisa su historial antes de integrar; no fuerces el push.

## Una rama por cambio

Con `origin` conectado y el directorio de trabajo limpio:

```powershell
git switch main
git pull --ff-only origin main
git switch -c feature/nombre-del-cambio
```

Desarrolla la funcionalidad y comprueba los cambios:

```powershell
flutter analyze
flutter test
git status
git diff
git add .
git diff --cached --stat
git diff --cached
git commit -m "feat: describir la funcionalidad agregada"
git push -u origin feature/nombre-del-cambio
```

Revisa los archivos antes del commit. Usa `feat:` para funcionalidades, `fix:`
para correcciones, `docs:` para documentación y `chore:` para mantenimiento.
Cada commit debe describir un cambio real y concreto.

## Integrar en main

Después de revisar el código y pasar las pruebas, abre un Pull Request en GitHub
desde la rama del cambio hacia `main`. Incluye el propósito, los cambios y las
pruebas realizadas. Tras integrarlo en GitHub:

```powershell
git switch main
git pull --ff-only origin main
git branch -d feature/nombre-del-cambio
```

Para conservar el historial de ramas de la guía, usa **Create a merge commit**
al integrar el Pull Request. Si utilizas squash o rebase, Git podría rechazar
`branch -d`: revisa primero que todos los cambios estén integrados.

Como alternativa al Pull Request, realiza la integración local:

```powershell
git switch main
git pull --ff-only origin main
git merge --no-ff feature/nombre-del-cambio -m "merge: integrar nombre-del-cambio"
flutter analyze
flutter test
git push origin main
git branch -d feature/nombre-del-cambio
```

No continúes con el push si hay conflictos o las pruebas fallan.

## Marcar una entrega

Solo cuando una entrega esté revisada, probada e integrada en `main`, crea un
tag anotado. El siguiente es un ejemplo para la primera entrega; no reutilices
un tag existente:

```powershell
git switch main
git pull --ff-only origin main
git tag -a v1.0.0 -m "Primera entrega de LifeSync"
git push origin v1.0.0
```

Mantén coherencia con la versión de `pubspec.yaml` (actualmente `1.0.0+1`).
El tag identifica una entrega; por sí solo no compila ni publica la aplicación.

## Archivos locales y configuración

`.gitignore` excluye compilaciones, cachés, respaldos, documentos generados,
bases de datos locales, variables de entorno y claves de firma. Conservamos
`pubspec.lock` para reproducir las dependencias de esta aplicación.

La configuración cliente de Firebase también queda local por decisión del
proyecto. Al clonar en otro equipo, restaura `android/app/google-services.json`
desde Firebase siguiendo `GOOGLE_SIGN_IN.md` antes de compilar Android. La
configuración cliente no sustituye las reglas de seguridad de Firebase.
Las claves privadas y cuentas de servicio nunca deben incluirse en el repositorio.

## Evidencias del trabajo

```powershell
git status
git log --oneline --graph --decorate --all
git branch -a
git tag -n
git remote -v
```

Para una entrega académica, conserva además los resultados reales de las
pruebas y el enlace del Pull Request cuando se haya creado.
