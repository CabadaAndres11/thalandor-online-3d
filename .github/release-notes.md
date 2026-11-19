## Thalandor Online {{VERSION}} (Windows)

### Cómo jugar
1. Descarga `ThalandorOnline-{{VERSION}}-windows.zip` y **descomprime todo** en una carpeta. El `.dll` tiene que quedarse junto al `.exe`.
   - **Si el navegador bloquea la descarga** por "no segura" (el juego es nuevo y no está firmado): en **Chrome**, abre las descargas (Ctrl+J) y pulsa **Conservar**. En **Edge**, pulsa **… → Conservar → Mostrar más → Conservar de todos modos**.
2. Abre `ThalandorOnline.exe`.
3. **Aviso de Windows (SmartScreen):** el juego no está firmado. Pulsa **Más información → Ejecutar de todas formas**.
4. Pulsa **Jugar**. Se abre **Tus personajes**: crea uno con **Crear** (nombre y aspecto) o elige uno que ya tengas. Empiezas como **aldeano**: la clase se elige en la partida, hablando con **Brann** (pulsa **E** a su lado).

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

### Novedades de la 0.6.1: los jefes del culto
- **Acólito Cultista**, el nuevo jefe del culto (sustituye a la Bestia de guardia, con las mismas tres fases): halo dorado con púas, máscara del sol negro y garras.
- **Vaelthar, Primer Apóstol**, el primero de los cinco Sacerdotes demonio. Está al **este** de la arena.
  - Levita, tiene melena gris ceniza y tentáculos que le salen de las mangas.
  - Seis ataques en tres fases: azote de tentáculos, lágrimas del sol negro, abrazo del abismo, halo del eclipse, charca de corrupción y un fervor final.
- **Nhazar, Obispo de las Mil Voces**, el segundo Sacerdote demonio. Está en la esquina **noroeste**.
  - Su cabeza es una masa enorme llena de máscaras que gritan.
  - Su combate gira en torno a los estados: ralentiza, te hace atacar más lento, debilita, aturde y te rompe la armadura.
- **Cultista Inquisidor:** la élite de las bandas de cultistas, con espada ceremonial. Entra en combate junto a los cultistas.
- **Estado nuevo: Armadura rota.** Tu armadura protege menos contra el daño físico mientras dura.
- La barra de los jefes sale arriba en cuanto empiezas a pelear con ellos.
- **Todo el grupo tiene que usar la misma versión.**

### Novedades de la 0.6.0: progresión
- **Experiencia y niveles sin tope.** Cada nivel da **+5 a los cinco atributos** y 5 puntos libres; los atributos recomendados de tu clase salen en dorado.
- **Ventana del personaje (C)** con tu modelo 3D y tus atributos.
- **Árbol de talentos (T)** de 66 nodos con maestrías.
- **Mejoras de clase del nivel 50:** doce en total, con sus habilidades activas, pasivas y evoluciones. La elección es obligatoria al llegar al 50.
- **Barra de 9 huecos** (1–9) y ventana de habilidades (K) en lista.
- **Monstruos con nivel:** la arena escala del 1 al 60 y la fija el anfitrión hablando con Brann.
- **Kit del Asesino rehecho** y mucho trabajo visual en el combate:
  - magia en vóxel (prisma arcano, bola de fuego, hielo, meteoro, muro de fuego, láser arcano);
  - rastros y animaciones propias en el cuerpo a cuerpo;
  - los enemigos reaccionan a los golpes y se disuelven en código binario al morir.
- **Tiempo de lanzamiento** en algunos hechizos (se interrumpe al moverse), con su barra en pantalla.
- **F9:** cámara isométrica o en tercera persona (Z / X para girarla).
- Comandos de prueba para el anfitrión: `/xp <n>` y `/nivel <n>`.
- **Tus personajes de antes se actualizan solos.**

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
