## Thalandor Online {{VERSION}} (Windows)

### Cómo jugar
1. Descarga `ThalandorOnline-{{VERSION}}-windows.zip` y **descomprime todo** en una carpeta. El `.dll` tiene que quedarse junto al `.exe`.
   - **Si el navegador bloquea la descarga** por "no segura" (el juego es nuevo y no está firmado): en **Chrome**, abre las descargas (Ctrl+J) y pulsa **Conservar**. En **Edge**, pulsa **… → Conservar → Mostrar más → Conservar de todos modos**.
2. Abre `ThalandorOnline.exe`.
3. **Aviso de Windows (SmartScreen):** el juego no está firmado. Pulsa **Más información → Ejecutar de todas formas**.
4. Pulsa **Jugar**. Se abre **Tus personajes**: crea uno con **Crear** (nombre y aspecto) o elige uno que ya tengas. Empiezas como **aldeano**: la clase se elige en la partida, hablando con **Brann** (pulsa **E** a su lado).

### Novedades de la 0.9.7: renovación gráfica
**Todo el juego tiene un aspecto nuevo**, con vóxeles más finos y más detalle.

- **Iluminación y ambientes:**
  - dos ambientes, de día y mazmorra de noche;
  - antorchas que parpadean, niebla, brillo y oclusión ambiental.
  - El anfitrión los cambia con .
- **Opciones** (en el título y en el menú de pausa):
  - calidad gráfica baja, media o alta, para equipos modestos;
  - ventana, escala de resolución y suavizado;
  - volumen general, de música y de efectos.
- **Personajes a doble resolución:**
  - cuerpo de adulto, con caras, pelo, barbas y ropa rehechos;
  - la vista previa de la selección lleva tu equipo puesto.
- **Equipo nuevo:**
  - las armaduras de las cinco clases, cada tramo más épico;
  - filos y cabezas de armas más grandes y gruesos, con una silueta propia por arma;
  - anillos y amuletos con modelo propio.
- **Enemigos rehechos:**
  - los cultistas, el inquisidor y los jefes Acólito, Vaelthar y Nhazar, con el detalle de sus hojas de referencia;
  - el sabueso, el jabalí y el lobo, a alta resolución.
- **Ropa que sigue al cuerpo:** las túnicas y faldas se mueven con las piernas, y las capas, capuchas y melenas se balancean al correr.
- **Combate:**
  - combo cuerpo a cuerpo de tajo a la izquierda, a la derecha y descendente, más exagerado y más rápido en todas las clases;
  - las armas a dos manos se agarran con las dos manos;
  - efectos sagrados del clérigo (cruces, alas, ángeles y coro) y templario cuerpo a cuerpo;
  - *Himno divino*: el clérigo levita y es invulnerable mientras canta.
- **Reglas:**
  - fuera de combate recuperas un 2 % de la vida por segundo;
  - en combate, el maná se recupera al 50 %;
  - cada punto de atributo da un efecto visible (1 fuerza = +1 de ataque, 1 aguante = +10 de vida…);
  - la agilidad sube la velocidad;
  - los básicos del arquero no gastan concentración.
- **Objetos:**
  - lo que cae se ve en el suelo;
  - fondo rojo en lo que no puedes equipar;
  - vender ya no falla: se arregló un desajuste de casillas de la bolsa, y el chat dice por qué si no se puede.
- El chat se vacía al **Cerrar sesión**.
- **Tus personajes de antes se actualizan solos.** Sus estadísticas se recalculan con los nuevos valores de los atributos.
- **Todo el grupo tiene que usar la misma versión.**

### Novedades de la 0.7.0: objetos
- **Botín personal:** al morir un monstruo, cada jugador cercano recibe el suyo. El oro va directo a tu bolsa; los objetos caen al suelo con un **haz de luz** y su nombre en el color de su rareza, y **solo los ves tú**. Se recogen pasando por encima.
- **Rarezas:** común, poco común, raro y épico, con propiedades aleatorias; y los **únicos de jefe** (Acólito Cultista, Vaelthar y Nhazar).
- **Inventario (I)** de 30 casillas y **11 ranuras de equipo** en la ventana del personaje (C). Clic derecho para equipar, desequipar o beber. El tooltip compara con lo que llevas puesto.
- **Equipo visible:** lo que llevas cambia tu aspecto y el grupo lo ve. **Cada clase tiene su propio juego** y solo puede llevar el suyo.
- **Tres tramos de aspecto** según el nivel del objeto (1–19, 20–39 y 40+), cada uno más épico: colores propios y capas en el segundo; halos, coronas, runas y **aura** en el tercero.
- **Armas a una y dos manos:** mandoble, gran hacha, martillo de guerra, alabarda, bastón, arco y ballesta ocupan las dos manos; nuevas **varita**, **cetro** y **tomo**. El arma cambia tu ataque básico (más lento y amplio, más alcance, disparo corto y rápido…); la ballesta siempre dispara cargada. **Solo bloqueas con escudo.**
- El ataque básico cuerpo a cuerpo se ve como un **combo de tres golpes**.
- **Pociones** de vida (**Q**) y de recurso (**R**), con recarga compartida de 30 s.
- **Durabilidad:** al morir (no al quedar derribado) tu equipo pierde un 10 %. El HUD avisa cuando toca reparar.
- **Mercader** junto a Brann: vende pociones y objetos comunes, compra lo tuyo al 25 % y repara.
- Comandos de prueba para el anfitrión: `/oro <n>` y `/objeto <base> [nivel] [rareza]`.
- **Tus personajes de antes se actualizan solos** y empiezan con el equipo de su clase.

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
| Habilidades | 1 a 9 |
| Esquivar | Espacio |
| Levantar a un aliado derribado | Mantener E a su lado |
| Hablar con Brann o el mercader | E a su lado |
| Pociones de vida / recurso | Q / R |
| Inventario | I |
| Ventana de habilidades | K |
| Personaje | C |
| Talentos | T |
| Chat | Enter |
| Menú | Esc |
| Zoom | Rueda del ratón |
| Datos de red | F3 |
| Cámara isométrica ↔ tercera persona (girar: Z / X) | F9 |
