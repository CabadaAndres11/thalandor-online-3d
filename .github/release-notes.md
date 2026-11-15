## Thalandor Online {{VERSION}} (Windows)

### Cómo jugar
1. Descarga `ThalandorOnline-{{VERSION}}-windows.zip` y **descomprime todo** en una carpeta. El `.dll` tiene que quedarse junto al `.exe`.
   - **Si el navegador bloquea la descarga** por "no segura" (el juego es nuevo y no está firmado): en **Chrome**, abre las descargas (Ctrl+J) y pulsa **Conservar**. En **Edge**, pulsa **… → Conservar → Mostrar más → Conservar de todos modos**.
2. Abre `ThalandorOnline.exe`.
3. **Aviso de Windows (SmartScreen):** el juego no está firmado. Pulsa **Más información → Ejecutar de todas formas**.
4. Pulsa **Jugar**. Se abre **Tus personajes**: crea uno con **Crear** (nombre, clase y aspecto) o elige uno que ya tengas.

### Novedades de esta versión: combate básico
- **Combate en tiempo real** con las 5 clases y su kit de nivel 1: ataque básico (clic izquierdo), secundario (clic derecho) y una habilidad en la casilla 1.
  - **Guerrero:** genera **furia** al golpear y al recibir daño; Carga le lleva hasta el enemigo.
  - **Clérigo y Mago:** gastan **maná**, que solo se recupera fuera de combate.
  - **Arquero:** mantén el clic izquierdo para **cargar** el disparo (gasta concentración).
  - **Asesino:** sus golpes suman **combos**; Destripar los gasta todos y pega más cuantos más tengas.
- **Esquiva** con Espacio: un salto corto con un instante de invulnerabilidad (recarga de 3 s).
- **Monstruos:** una manada de **lobos** y unos **limos ácidos**, cada grupo en una esquina distinta de la arena. Te persiguen esquivando los muros, vuelven a su sitio si te alejas demasiado y reaparecen al rato. Tienen más vida cuantos más jugadores haya en el grupo.
- **Si caes**, reapareces a los 3 s cerca del centro de la arena con la vida llena.
- **HUD de combate** abajo en el centro: vida, recurso, casillas con su recarga (atenuadas si no te llega el recurso), combos y carga. Números de daño, chispas y avisos en el suelo.
- **Todo el grupo tiene que usar la 0.3.0.** Las versiones anteriores no pueden jugar con esta.

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
WASD mover · ratón apuntar · clic izquierdo ataque básico (mantener: carga del Arquero) · clic derecho secundario · 1–4 habilidades · Espacio esquivar · rueda zoom · Enter chat · Esc menú · F3 datos de red · F9 cambiar proyección de cámara
