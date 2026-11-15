## Thalandor Online {{VERSION}} (Windows)

### Cómo jugar
1. Descarga `ThalandorOnline-{{VERSION}}-windows.zip` y **descomprime todo** en una carpeta. El `.dll` tiene que quedarse junto al `.exe`.
   - **Si el navegador bloquea la descarga** por "no segura" (el juego es nuevo y no está firmado): en **Chrome**, abre las descargas (Ctrl+J) y pulsa **Conservar**. En **Edge**, pulsa **… → Conservar → Mostrar más → Conservar de todos modos**.
2. Abre `ThalandorOnline.exe`.
3. **Aviso de Windows (SmartScreen):** el juego no está firmado. Pulsa **Más información → Ejecutar de todas formas**.
4. Pulsa **Jugar**. Se abre **Tus personajes**: crea uno con **Crear** (nombre, clase y aspecto) o elige uno que ya tengas.

### Novedades de la 0.4.1
- **Esqueleto arquero nuevo:** ya no es un cuerpo de cubos. Está hecho de huesos finos con huecos entre ellos (costillas, columna, pelvis, brazos y piernas), con un cráneo de mirada malvada, brasas en las cuencas y colmillos. Camina traqueteando, tensa el arco al disparar y se desmorona al morir.
- **Ventana de habilidades (K):** ahora incluye también el **clic izquierdo y el derecho**, para ver qué hacen.
- **Descripciones detalladas:** cada habilidad muestra de dónde sale su daño (por ejemplo, *18 + 80 % de tu poder de ataque (20) = 34 físico*), a quién alcanza, los efectos con su porcentaje y duración, el crítico, el coste, la recarga y el alcance.
- **Todo el grupo tiene que usar la 0.4.1:** el juego solo deja jugar juntos con la misma versión.

### Novedades de la 0.4.0: clases completas, monstruos y jefe
- **Kit completo de las 5 clases:** cada una tiene ya su ataque básico, su secundario, 5 habilidades activas y 4 pasivas. Abre la ventana de **Habilidades con K**: ves todas con su descripción, coste y recarga. Para colocar una en la barra, haz clic en ella y luego en una casilla del 1 al 4 (si ya estaba, se intercambian). La barra se guarda con cada personaje.
  - Hasta que lleguen los niveles (próxima versión) todos sois nivel 1: puedes usar todas las activas, pero las pasivas aún no se activan.
- **Monstruos nuevos:** **jabalíes** que avisan una línea en el suelo y cargan por ella (¡apártate!), **goblins** que van en manada y **esqueletos arqueros** que se alejan si te acercas. Cualquier monstruo puede salir **élite**: más grande, con un aura en el suelo, más vida y más daño.
- **Jefe: el Rey orco**, en un extremo de la arena. Tiene tres fases: golpea en arco; a partir del 66 % de vida salta sobre un jugador (el círculo rojo avisa dónde cae); y a partir del 33 % llama a goblins. Una barra arriba muestra su vida y su fase. Cuando cae, todo el grupo lo ve en el chat; reaparece a los 3 minutos.
- **Amenaza:** los monstruos atacan a quien más amenaza tiene. Curar también da amenaza, y *Provocar* del Guerrero se los lleva y los mantiene en él.
- **Derribo en grupo:** si caes y queda algún aliado en pie, quedas **derribado** 30 s. Un aliado se acerca y **mantiene E** 3 s para levantarte (si se mueve o le pegan, se corta). Si cae todo el grupo, reaparecéis todos juntos.
- **Marcos de grupo** a la izquierda con la vida de tus aliados.


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
| Ventana de habilidades | K |
| Chat | Enter |
| Menú | Esc |
| Zoom | Rueda del ratón |
| Datos de red | F3 |
| Cambiar proyección de cámara | F9 |
