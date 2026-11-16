## Thalandor Online {{VERSION}} (Windows)

### Cómo jugar
1. Descarga `ThalandorOnline-{{VERSION}}-windows.zip` y **descomprime todo** en una carpeta. El `.dll` tiene que quedarse junto al `.exe`.
   - **Si el navegador bloquea la descarga** por "no segura" (el juego es nuevo y no está firmado): en **Chrome**, abre las descargas (Ctrl+J) y pulsa **Conservar**. En **Edge**, pulsa **… → Conservar → Mostrar más → Conservar de todos modos**.
2. Abre `ThalandorOnline.exe`.
3. **Aviso de Windows (SmartScreen):** el juego no está firmado. Pulsa **Más información → Ejecutar de todas formas**.
4. Pulsa **Jugar**. Se abre **Tus personajes**: crea uno con **Crear** (nombre y aspecto) o elige uno que ya tengas. Empiezas como **aldeano**: la clase se elige en la partida, hablando con **Brann** (pulsa **E** a su lado).

### Novedades de la 0.5.0: arte propio, el culto y Brann
- **Personajes nuevos, hechos a mano por código:** sin paquetes de terceros.
  - Vóxel más fino y proporciones de adulto, con codos y rodillas.
  - Sombreado suave, y ropa, pelo, barbas y armas de cada clase.
  - El arquero tensa el arco de verdad y el mago lleva su bastón inclinado.
- **Empiezas como aldeano**, con una espada de madera. Ve a ver a **Brann**, el herrero, que está junto al punto de inicio, y pulsa **E**: eliges tu clase entre las cinco, viendo cómo quedarías. **La elección es definitiva.** Si tienes a un aliado derribado al lado, E sigue sirviendo para levantarlo.
- **El culto ataca:** los monstruos son ahora los del prólogo de la historia.
  - **Cultistas enmascarados** que van en grupo y **arqueros del culto**.
  - **Sabuesos** y **jabalíes marcados** con el collar del culto.
  - El jefe es la **Bestia de guardia**, con las mismas tres fases que el antiguo Rey orco.
- **Derribado:** ahora te quedas en el suelo y ya no giras con el ratón.
- **Tus personajes de antes conservan su clase.**
- **Todo el grupo tiene que usar la 0.5.0.**

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
| Acción | Tecla |
|---|---|
| Moverse | W A S D |
| Apuntar | Ratón |
| Ataque básico | Clic izquierdo (Arquero: mantener para cargar) |
| Ataque secundario | Clic derecho |
| Habilidades | 1 · 2 · 3 · 4 |
| Esquivar | Espacio |
| Levantar a un aliado derribado | Mantener E a su lado |
| Hablar con Brann (elegir clase) | E a su lado |
| Ventana de habilidades | K |
| Chat | Enter |
| Menú | Esc |
| Zoom | Rueda del ratón |
| Datos de red | F3 |
| Cambiar proyección de cámara | F9 |
