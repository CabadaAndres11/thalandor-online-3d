---
tags: [plan, spec]
plan: 5
fecha: 2026-11-19
estado: implementado
actualizado: 2026-11-19
---
# Plan 5 — Objetos: diseño

## Objetivo
Que matar dé **botín** y que el personaje **se equipe**: oro, objetos con rareza y propiedades aleatorias, inventario, 11 ranuras de equipo que cambian el aspecto vóxel, armas a una y dos manos que se manejan distinto, pociones, durabilidad y un mercader. Todo se guarda con el personaje.

**Por qué:** tras el Plan 4 el personaje sube de nivel, pero no hay nada que buscar ni que mejorar fuera de los puntos. Los objetos son la recompensa de los combates y requisito de las misiones y zonas (Plan 6).

**Versión:** 0.7.0, protocolo de red 7, personajes versión 4 (hoy 3).

## Fuera de alcance
- **Capital:** el mercader está provisionalmente junto a Brann, en la arena; se muda en el Plan 6.
- **Alijo** (Plan 6) e **intercambio entre jugadores** (fuera de la demo).
- **Guardado de la posición y la zona** (Plan 6, cuando haya zonas).
- **Legendarios** (naranja, efecto único): la rareza queda prevista en los datos, pero no cae hasta el Plan 8 *(decisión de Claude: cada efecto único es una regla nueva en `sim/` y merece su propio diseño)*.
- **Habilidades que dependan del arma:** los kits no cambian (ver §5).
- Sonido.

## Antifines
- Que añadir un objeto, un aspecto o una propiedad exija tocar `sim/`: todo es dato en `data/items/`.
- Que un cliente pueda crearse objetos u oro: el anfitrión tira el botín y valida cada petición.
- Que una actualización borre o rebaje un personaje u objeto guardado.
- Que alguna ventana necesite scroll a 1280×720.
- Que el botín de un jugador lo vea o lo recoja otro.

## Enfoques
- **A (elegido): el anfitrión manda, el dueño guarda** (el mismo patrón que el progreso del Plan 4). Las reglas viven en `sim/items/` (portadas del prototipo 2D, `D:\RPG\src\sim\items`). El jugador trae su inventario y equipo en el `HELLO`; el anfitrión lo **sanea** (bases que existen, niveles y rarezas válidos, sin duplicados), lo tiene en memoria durante la partida, aplica botín, equipar, usar, comprar, vender y reparar, y devuelve el estado a su dueño, que lo guarda.
- **B: el cliente gestiona su inventario** y solo informa al anfitrión. Descartado: trampas triviales y estadísticas incoherentes entre jugadores.
- **C: el anfitrión guarda los inventarios de todos.** Descartado: el personaje dejaría de poder jugar solo o con otro anfitrión.

## Diseño

### 1. Objetos como datos (`data/items/`)
- **`bases.json`:** cada objeto base con ranura, tipo (tela, cuero, malla, placas o tipo de arma), **tramo de nivel** (`min_level`, `max_level`), modelo vóxel, nombre (clave de texto) y estadísticas fijas que escalan con el nivel del objeto (`base + por_nivel × nivel`).
- **`affixes.json`:** propiedades aleatorias planas o porcentuales, con las ranuras donde pueden salir (portadas del prototipo, con los nombres de estadística del 3D).
- **`loot.json`:** probabilidades, rarezas, valores, precios, durabilidad, pociones y mercader (valores en §2, §7–§9).
- **`weapons.json`:** las familias de arma (§5) y qué tipos de arma y armadura usa cada clase.
- **Nivel del objeto** = nivel del monstruo que lo suelta. Sin tope. Requisito: no se equipa un objeto de nivel superior al del personaje.
- **Rarezas:** común (fijas), poco común (+1), raro (+2), épico (+3), legendario (+4 y efecto único, sin caer en este plan), único de jefe (fijas, nombre y modelo propios). Las propiedades no repiten estadística y escalan con el nivel del objeto (tirada entre el 60 % y el 100 % del máximo).
- Las armas **a dos manos** dan del orden de 1,8 veces las estadísticas de una de una mano, porque ocupan dos ranuras *(propuesta de Claude, ajustable)*.

### 2. Botín personal
- Al morir un monstruo, **cada jugador vivo o derribado a 30 m o menos** (el mismo radio que la experiencia) tira su propio botín en el anfitrión.
- **Oro:** el 90 % de las veces, `round(2 × nivel^1,3 × (1 ± 0,2))`, ×4 en élites. Se suma directamente con un número flotante dorado (*decisión de Claude: no cae al suelo*).
- **Objetos:** 12 % en monstruos normales; el élite suelta 1 seguro y otro con un 40 %; el jefe, 2 seguros. El 75 % es usable por la clase de quien lo recibe.
- **Rareza:** normal 55/30/12/3 % (común/poco común/raro/épico); élite y jefe 25/45/22/8 %.
- **Pociones:** 6 %, mitad de vida y mitad de recurso; el Guerrero (ira) solo recibe de vida.
- **Únicos de jefe:** el Acólito Cultista, Vaelthar y Nhazar sueltan su único con un 25 % *(propuesta de Claude)*.
- **En el suelo:** los objetos y pociones caen esparcidos junto al cadáver, con un **haz de luz** y su nombre en el color de su rareza. **Solo los ve su dueño.** Se recogen pasando por encima (radio ~1 m); desaparecen a los 2 minutos. Si el inventario está lleno, se quedan en el suelo y avisa en el chat.

### 3. Inventario y oro
- **30 casillas** (ventana **I**, 6×5) y el oro. Las pociones se apilan hasta 20.
- **Clic derecho:** equipar o usar. **Tooltip** con nombre en color de rareza, ranura, tipo, nivel, estadísticas, durabilidad, valor y la **comparación** con lo equipado (diferencias en verde y rojo). En rojo si la clase no puede usarlo o el nivel no llega.
- **No se puede vender ni tirar fuera del mercader.**
- Se puede tener abierta a la vez que la ventana C y la del mercader.

### 4. Equipo (11 ranuras) y aspecto
- Ranuras: **arma principal, mano secundaria, cabeza, hombros, pecho, manos, piernas, pies, cuello, anillo ×2**.
- **Armas a dos manos** ocupan la principal y la secundaria: al equiparlas se desequipa la secundaria (vuelve al inventario; si no cabe, no se puede equipar).
- **Qué usa cada clase** (en `weapons.json`):

| Clase | A dos manos | Principal a una mano | Secundaria | Armadura |
|---|---|---|---|---|
| Guerrero | mandoble, hacha a dos manos, martillo de guerra, alabarda | espada, hacha, maza | escudo | placas y las inferiores |
| Clérigo | martillo de guerra, bastón | maza, varita, cetro | escudo, orbe, tomo | tela |
| Mago | bastón | varita | orbe, tomo | tela |
| Arquero | arco, ballesta | espada corta | — | cuero y malla (y tela) |
| Asesino | — | daga, espada corta | daga | cuero (y tela) |

  **Armadura por clase (cambio del 2026-11-19):** cada tramo tiene **un juego de armadura por clase** (Guerrero, Clérigo, Mago, Arquero y Asesino), con un aspecto propio de su clase, y **solo lo lleva esa clase**. El tipo (placas, tela, malla, cuero) queda como dato descriptivo: Guerrero placas, Clérigo y Mago tela, Arquero malla, Asesino cuero. La columna *Armadura* de la tabla ya no es una regla.
- **El carcaj deja de ser objeto:** es un adorno fijo a la espalda del Arquero.
- **Equipo visible:** las 8 ranuras con modelo (armas, secundaria, cabeza, hombros, pecho, manos, piernas, pies) cambian el aspecto del personaje, y el resto del grupo lo ve. Cuello y anillos no se ven. Una ranura vacía muestra la **ropa base** (sencilla, de aldeano, con los colores del personaje).
- **Equipo inicial:** cada clase empieza con un juego común de nivel 1 de su tipo, con su arma de siempre, para que el aspecto inicial se parezca al actual. Los personajes de la versión 3 lo reciben al cargar.
- **Ventana C:** el modelo 3D en vivo rodeado de **11 huecos** (hoy 8). Sin scroll a 1280×720.

### 5. Familias de arma: misma habilidad, distinto manejo
Las habilidades no cambian; cada **familia** fija en datos la **animación, el alcance, el arco y la velocidad** del ataque básico y de los golpes con arma, y un multiplicador de daño que compensa la velocidad:

| Familia | Armas | Manejo |
|---|---|---|
| Una mano | espada, hacha, maza, cetro, espada corta | como hoy |
| Pesada a dos manos | mandoble, hacha a dos manos, martillo de guerra | tajo amplio y lento, más daño por golpe, más alcance |
| Asta | alabarda | estocada larga y recta, alcance mayor |
| Bastón | bastón | como hoy (Mago y Clérigo) |
| Varita | varita | el ataque básico lanza un proyectil corto y rápido |
| Arco | arco | como hoy (tensar para el disparo cargado) |
| Ballesta | ballesta | dispara sin tensar: siempre sale el disparo cargado, con recarga más lenta |
| Dagas | dos dagas, o daga con espada corta | como hoy (Asesino) |

- **Combo visual de tres golpes:** el ataque básico cuerpo a cuerpo (todas las familias de melé) encadena tres animaciones distintas (por ejemplo, tajo de derecha a izquierda, revés y golpe vertical). **Solo es visual:** los tres golpes tienen el mismo daño, alcance, arco y recarga. El combo vuelve al primer golpe si pasa más de un instante sin atacar.
- **Bloqueo solo con escudo:** la probabilidad de bloquear (de atributos y equipo) solo cuenta con escudo equipado; el *Bloqueo experto* del Guerrero lo necesita.
- Los números concretos de cada familia son propuesta de Claude y se ajustan probando.

### 6. Aspectos por nivel y arte
- **Tres aspectos por tipo**, por tramos de nivel del objeto: **1–19, 20–39 y 40+** *(propuesta de Claude: la demo llega al 60)*. Cada tramo más ornamentado y épico que el anterior.
- Por tramo: **30 piezas de armadura** (5 juegos de clase × 6 ranuras) y **17 armas o secundarias** = 47 objetos; **141 en total**, más los **3 únicos de jefe**.
- Cada juego de clase tiene su tocado (yelmo del Guerrero, capucha con sol del Clérigo, sombrero puntiagudo del Mago, capucha de explorador del Arquero, capucha y máscara del Asesino) y su emblema en el pecho; la tela y el cuero toman los colores de la clase.
- Todo el arte se hace en código (`tools/art/`), como el resto del juego. Se revisa por tandas con `tests/helpers/render_characters.gd`: **tú apruebas cada tramo** antes de pasar al siguiente.
- **Iconos:** miniatura renderizada del propio modelo, generada al arrancar y guardada en caché.

### 7. Pociones
- **Vida (Q)** y **recurso (R)**: devuelven el 35 %, recarga **compartida** de 30 s, pilas de 20. Se usan desde la tecla o con clic derecho en el inventario.
- El HUD muestra las dos pociones con su cantidad y la recarga.

### 8. Durabilidad
- Cada pieza equipada pierde un **10 % al morir** (no al quedar derribado). A 0 no da estadísticas y se muestra en rojo.
- Aviso en el HUD cuando alguna pieza baja del 25 %.

### 9. Mercader provisional
- PNJ nuevo junto a Brann, con su propio modelo vóxel. Se habla con él con la tecla de interactuar.
- **Vende:** pociones de vida y recurso (`5 + 2 × nivel` de oro, nivel = el del personaje) y **4 objetos comunes** usables por quien compra, de su nivel, que cambian cada vez que se abre la ventana tras 10 minutos.
- **Compra** al 25 % del valor. Valor = `3 × nivel^1,4 × rareza` (×1, ×2, ×4, ×8, ×16 para común a épico y único).
- **Repara** todo lo equipado: 20 % del valor por pieza, proporcional a lo que le falta.
- **Ventana del mercader** junto al inventario (sin scroll): pestañas *Comprar* y *Vender/Reparar*. En la de vender, clic derecho en el inventario vende; *Reparar todo* con su precio. Vender pide confirmación solo para raros o mejores.

### 10. Red y guardado
- **Personaje versión 4:** añade `gold`, `inventory` (30 casillas) y `equipment` (11 ranuras). Cada objeto: id único, base, nivel, rareza, propiedades, durabilidad. Los de la versión 3 entran con el equipo inicial y nada más; no se pierde nada.
- **Protocolo 7:** el `HELLO` lleva oro, inventario y equipo; el anfitrión los sanea. Mensajes de petición (equipar, desequipar, usar, recoger, comprar, vender, reparar) y de respuesta con el estado nuevo **solo al dueño**. El botín en el suelo se envía solo a su dueño.
- **Aspecto para los demás:** la información de cada jugador incluye el modelo de cada ranura visible; se reenvía a todos al cambiar el equipo.
- Las escrituras al disco se agrupan como en el Plan 4.
- **Comandos de pruebas** del anfitrión: `/oro <n> [nombre]` y `/objeto <base> [nivel] [rareza] [nombre]`. Se retirarán antes de la demo.

## Pruebas
- **GUT:** tiradas de botín y rarezas con semilla fija; propiedades sin repetir y dentro de rango; reglas de clase, armadura, nivel y dos manos; inventario lleno, apilado de pociones; durabilidad al morir y no al quedar derribado; estadísticas del equipo en las de combate (y sin ellas a durabilidad 0); bloqueo solo con escudo; precios, venta, reparación y oro insuficiente; saneado del `HELLO`; migración de la versión 3 a la 4; mensajes de red (botín solo al dueño, aspecto a todos); validación de todos los datos de `data/items/` (cada base con modelo, texto y clase que pueda usarla).
- **Pruebas de juego (tú):** botín y haz de luz, recoger, equipar y ver el cambio en ti y en un amigo, cada familia de arma, pociones, morir y reparar, comprar y vender, cerrar y volver a entrar con todo guardado.

## Decisiones tomadas
- Mercader provisional junto a Brann hasta que exista la capital (usuario).
- El guardado ya existe; se amplía a la versión 4. La posición y la zona quedan para el Plan 6 (usuario, tras la explicación de Claude).
- Varios aspectos por tipo según el nivel del objeto (usuario); tres tramos 1–19, 20–39 y 40+ (propuesta de Claude).
- Armas a dos manos que ocupan principal y secundaria: mandoble, hacha a dos manos, martillo de guerra, alabarda, bastón, arco y ballesta; nuevas a una mano: varita y cetro; secundaria nueva: tomo (usuario y Claude).
- El carcaj pasa a adorno fijo a la espalda (usuario).
- Mismas habilidades; cada familia de arma cambia animación, alcance y velocidad; el bloqueo exige escudo (usuario).
- El básico cuerpo a cuerpo se ve como un combo de tres golpes encadenados, solo animación (usuario).
- Un juego de armadura por clase en cada tramo, exclusivo de esa clase (usuario, tras ver el arte del tramo 1).
- Legendarios fuera de este plan; el oro no cae al suelo; únicos de jefe al 25 % (Claude).

---
← [[Planes]]
