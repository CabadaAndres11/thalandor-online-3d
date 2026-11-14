## Thalandor Online {{VERSION}} (Windows)

### Cómo jugar
1. Descarga `ThalandorOnline-{{VERSION}}-windows.zip` y **descomprime todo** en una carpeta. El `.dll` tiene que quedarse junto al `.exe`.
   - **Si el navegador bloquea la descarga** por "no segura" (el juego es nuevo y no está firmado): en **Chrome**, abre las descargas (Ctrl+J) y pulsa **Conservar**. En **Edge**, pulsa **… → Conservar → Mostrar más → Conservar de todos modos**.
2. Abre `ThalandorOnline.exe`.
3. **Aviso de Windows (SmartScreen):** el juego no está firmado. Pulsa **Más información → Ejecutar de todas formas**.
4. Pulsa **Jugar**. Se abre **Tus personajes**: crea uno con **Crear** (nombre, clase y aspecto) o elige uno que ya tengas.

### Novedades de esta versión: personajes vóxel
- Hasta **8 personajes** por jugador, de 5 clases: Guerrero, Clérigo, Mago, Arquero y Asesino. Cada clase tiene su ropa.
- **Aspecto:** cuerpo, piel, ojos, peinado, color de pelo y barba, con vista previa que se puede girar arrastrando.
- **Animaciones** de reposo y andar. Tus amigos ven tu personaje tal como lo creaste.
- **Exportar e importar:** sirve para copias de seguridad o para jugar con el mismo personaje en otro PC. Los personajes se guardan en `%APPDATA%\Godot\app_userdata\Thalandor Online\saves\characters`.
- **Todo el grupo tiene que usar la 0.2.0:** con la 0.1.x, el juego avisa de que las versiones no coinciden.

### Jugar con amigos: dos redes para probar
Esta versión trae **dos formas de conectarse**. Todos los del grupo tienen que usar la misma, y también **la misma versión** del juego.

| | **WebRTC** (por defecto) | **ENet + Tailscale** |
|---|---|---|
| Cómo se abre | `ThalandorOnline.exe` | `Jugar con ENet y Tailscale.bat` |
| Preparación | Nada | Todos instalan **Tailscale** (gratis), entran con su cuenta y el anfitrión comparte su red con los demás |
| Cortafuegos | Puede preguntar: permite el acceso | La primera vez pregunta: marca *Redes privadas* y **Permitir acceso** |

- Quien hace de anfitrión pulsa **Esc → Abrir grupo** y comparte el código (por ejemplo `ABCD-EFGH`). Con WebRTC el código tarda un momento en aparecer.
- Los demás escriben el código en **Unirse a un amigo**.
- Pulsa **F3** para ver la red que usas, el ping y las correcciones.

### Controles
WASD mover · ratón apuntar · rueda zoom · Enter chat · Esc menú · F3 datos de red · F9 cambiar proyección de cámara
