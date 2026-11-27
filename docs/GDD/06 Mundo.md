---
tags: [gdd]
estado: en curso
actualizado: 2026-11-27
---

# 6. Mundo

## 6.1 Estructura **[Implementado 0.11.0]** ([[D-017 Mundo por zonas, hordas y demo del prólogo y arco 1]])
- **Zonas:** el mundo está formado por zonas conectadas; cada una es una **escena 3D** construida con `GridMap` (bloques vóxel) y props. Se pasa entre zonas por sus bordes o portales, con una pantalla de carga breve.
- **Varias zonas a la vez:** dentro de una partida los jugadores pueden estar en zonas distintas.
- **Mazmorras:** son **instancias** (cada grupo tiene su copia).
- **Un mundo por zona en el anfitrión.** Solo avanzan las zonas con jugadores: una zona vacía se duerme y conserva sus monstruos, y una instancia vacía se cierra a los 5 minutos. Cada jugador recibe solo lo que pasa en su zona; los compañeros de otra zona aparecen en los marcos de grupo con el nombre de su zona.
- **Paso entre zonas:** pisando una **salida**, con una pantalla de carga breve. No se puede cambiar de zona en combate (5 s desde el último golpe recibido).
- **Hordas:** áreas que se mantienen llenas de monstruos de varios tipos con su **franja de nivel**; cada muerto vuelve a los 8 s. Son la forma principal de subir de nivel.
- **Mazmorras:** al llegar a la puerta se **elige el nivel** (del propio −5 a +10). El grupo comparte la misma instancia.
- **Reaparición** en el punto de la zona (en una mazmorra, en su entrada). El personaje **guarda su zona y su posición** (en una mazmorra, su puerta).
- **Puntos de control** para reaparecer y **reaparición de monstruos** con temporizador.
- **Bordes y salidas** **[Implementado 0.11.1]**: alrededor de cada zona hay una franja de 14 casillas de bosque espeso (en las mazmorras, roca) que nunca se pisa; cada salida del borde es un hueco con su camino, un poste con el nombre de la zona de destino, dos antorchas y un brillo en el suelo. La cámara no pasa del borde menos 6 casillas, así que nunca enseña el vacío. Nada se siembra a menos de 6 casillas de una salida.
- **Linde** **[Implementado 0.11.2]**: las zonas exteriores acaban en una franja de 10 casillas de árboles **dentro del mapa** que no se cruza; las salidas son sendas que la atraviesan y el cambio de zona salta dentro de la senda, 5 casillas antes del borde. Fuera, 30 casillas de bosque decorado sobre suelo de sotobosque; la cámara no pasa de la linde. Los árboles y rocas de la linde y de fuera no dan sombra.
- **Suelo** **[Implementado 0.11.3]**: una textura de píxeles por zona (4×4 por casilla, tres tonos en manchas, bordes entre tipos mezclados) y detalles vóxel sembrados por casilla: matas de hierba y flores en la hierba, piedrecitas en tierra y caminos; sin sombra, solo de cerca y menos en calidad baja.
- **Herrería de Aelhest** **[Implementado 0.11.3]**: piedra y entramado con tejado de tablas, dos hornos y fuelles dentro y una chimenea de ladrillo; al costado, un cobertizo abierto con fragua, yunque, banco y barril, donde está Brann.
- **Casas accesibles** **[Implementado 0.11.1]**: las casas se dibujan a 10 cm por vóxel en cuatro partes (suelo y muebles, paredes, paredes recortadas a 1 m y tejado). Se entra por una puerta de 2 casillas; al pisar el interior, el tejado se funde y las paredes se recortan, solo en la pantalla de quien está dentro.
- **Rendimiento** **[Implementado 0.11.1]**: las caras iguales de los modelos vóxel se fusionan; las piezas y el suelo van en trozos de 16×16 casillas; de cerca se ve el modelo completo y lejos una copia de la mitad de resolución; las sombras las da una copia simplificada y nunca las piezas pequeñas (sin sombras de piezas en calidad baja). La zona se construye por pasos detrás de la pantalla de carga, que dura al menos 0,6 s; un invitado se conecta cuando su zona ya está cargada.
- **Variantes y puntos de misión** **[Implementado 0.12.0]**: una zona puede tener `variants` (cambian el ambiente, los PNJ, las hordas y el punto de reaparición, y añaden o quitan piezas) para los momentos de la historia que se juegan a solas, y `quest_points` (sitios a los que llegar o que examinar). Una horda con `"respawn": false` no repone. Tras el asalto, el mundo compartido no cambia con la historia.
- **Iluminación:** cada zona elige un **ambiente** de `data/ambiences/` con `"ambience"` en su JSON y coloca antorchas con `"torches"` **[Implementado 0.8.0]**. La luz por momento de la historia va en las variantes y en las escenas (0.12.0); ambientes nuevos: atardecer, noche con fuego y alba; las mazmorras usan luces locales (antorchas) para dar ambiente.

## Nombres del mundo
El continente es **Velmora**; el reino, **Valdrenn**, con capital en **Sumerhold**. La aldea del prólogo es **Aelhest** y el bosque camino de la capital, **Eldarra** («Bosque de Eldarra»). La cripta del sello del arco 1 es la **Cripta de Sumerhold**. En pantallas de carga, carteles, mapa y textos se usa el **nombre completo**: «Aldea de Aelhest», «Bosque de Eldarra», «Sumerhold, Capital del Reino», «Cripta de Sumerhold».

## 6.2 Contenido de la demo **[En curso]** (Plan 8, según el guion)
La demo cubre el **prólogo y el arco 1** (misiones 1–14) y termina hacia el **nivel 50** al salir de la capital rumbo al volcán.

| Zona | Niveles | Contenido |
|---|---|---|
| **Aldea** | 1–5 | Tutorial en solitario (misiones 1–2, variantes `vispera` y `asalto`); después, en ruinas, con el campamento de Verrin (0.13.0) |
| **Bosque**, camino de la capital | 5–20 | Hordas y el rastro del Heraldo (misión 3); sale al este al Camino de Sumerhold |
| **Camino de Sumerhold** | 4–8 | La caravana y la emboscada de bandidos (misión 4), hordas suaves y un campamento de bandidos (0.14.0) |
| **Capital** (Sumerhold) | — | Zona segura amurallada (0.14.0): plaza con fuente y puestos, casas de piedra, el mercader, maese Corwin (reinicios) y ciudadanos que pasean. Al norte, el **palacio**: zona segura con el salón del trono (trono sobre un estrado de tres escalones, alfombra centrada, ocho estatuas gigantes de guerreros de granito gris mirando a la alfombra), la armería (armaduras y armas reales del juego en soportes y armeros, con una lanza nueva) y la sala del consejo al norte; antorchas de pared en todas las salas, la sala de la cripta (una escalera que baja al suelo, con una cadena hasta que la historia la abre) y el archivo de Oriel (estanterías con pasillos, mesas, sillas y libros por el suelo). Los nobles, con trajes y vestidos de corte, pasean en parejas sin pisar la alfombra y muestran [E] Hablar. La capital tiene torres en las esquinas de la muralla, interiores distintos en casas vecinas, gente en algunas casas, niños y habitantes de las cinco razas |
| **Afueras de la capital** | 20–35 | Hordas entre misiones del arco 1 |
| **Alcantarillas y submundo** | 30–40 | Misión 8 |
| **Cripta bajo el palacio** | 35–50+ | Mazmorra instanciada y repetible (misiones 5, 11 y 12) |

- **Provisional (0.11.0):** una aldea y un bosque de prueba conectados y una **cripta de prueba** instanciada. Desde la 0.14.0 se entra a ella por la reja del palacio ([[Plan 8.3b — Camino y capital (spec)|Plan 8.3b]]), que solo se abre con la marca `cripta_abierta`; el arco del bosque queda como ruina.
- **Salidas que abre la historia** (0.14.0): una salida puede pedir marcas (`requires`) y llevar una reja que se pinta abierta o cerrada según la historia de cada jugador; el anfitrión no deja pasar a quien no las tiene.
- **La aldea en tres momentos (0.13.0, [[Plan 8.3a — Prólogo en la aldea (spec)|Plan 8.3a]])** **[Implementado]**:
  - **base (compartida):** en ruinas, con casas quemadas (mismas casillas que las sanas), escombros, vigas, tumbas junto a la colina y el campamento del ejército (tiendas y estandarte). PNJ: Verrin, la anciana Edda, Tobías el panadero y Garet el cazador. Sin Brann ni mercader;
  - **`vispera`:** casas sanas, guirnaldas, farolillos, mesas de fiesta y hoguera, luz de atardecer, muñeco de práctica en el patio de la forja, Brann y Mira. Se empieza dentro de la casa de la forja;
  - **`asalto`:** de noche con fuego, cultistas de nivel 1–2 junto a los vecinos, sabuesos y el Heraldo al norte; se reaparece a salvo en la casa de la forja, a más de 15 m de toda horda.
  - Las variantes pueden cambiar también `entries` y `walkers`.
- **Relieve** (0.15.0, [[Plan 8.3d — Relieve, aldea nueva y correcciones (spec)|Plan 8.3d]]): `relief` en la zona (`hill`, `hollow`, `plateau` con `slope`); `ZoneLayout.height_at` da la altura y un desnivel de más de 0,6 m entre casillas es un acantilado. La simulación sigue en plano; cada cliente dibuja suelo, piezas, personajes, efectos y escenas a esa altura. El agua se queda en su hondonada.
- **La aldea desde la 0.15.0:** calle mayor de oeste a este con 14 casas en hilera (cabaña, entramado de dos plantas, troncos, piedra y casa grande), plaza en el cruce con el camino del norte, callejones a la herrería, la colina (tumbas) y el río; **rancho** con establo, cercado, comederos y vacas que pasean. Los jabalíes, en el prado del noreste.
- **Aldeanos que pasean** (0.13.0): ancianos sobre todo, por rutas (`walkers`). Se mueven en cada cliente con el reloj del anfitrión, no chocan con nadie y saludan con **E**. Desde la 0.16.x todos los saludos de PNJ se leen en la ventana de diálogo, no en el chat. Los PNJ sin importancia (ciudadanos, vendedores, aldeanos: `minor` en sus datos) no llevan nombre sobre la cabeza ni salen en el mapa.
- **Rastro del culto en el Bosque de Eldarra** (0.13.0): al sur del camino, lejos de las hordas, un campamento abandonado, huellas de carro y la orilla de un río donde el rastro se pierde.
- **Crecimiento:** el mundo crece por **arcos** del guion (un sello por arco).

## 6.3 Pipeline de contenido **[Diseñado]**
Añadir una zona consiste en aportar:
1. El JSON de la zona en `data/zones/` **[Implementado 0.11.0]**: tamaño, ambiente, franja de nivel, suelo (`terrain`), piezas colocadas (`pieces`, de `data/zones/pieces.json`, cada una con las casillas que bloquea), relleno por área (`scatter`, un bosque sin listar cada árbol), caminos (`paths`), PNJ, salidas, entradas con nombre, reaparición, hordas y puntos de monstruos. Si es una mazmorra, `instanced: true`.
2. Las entradas de monstruos y spawns en `data/`.
3. Las misiones.
4. Los textos.

Sin modificar el código de `sim/`. Es un requisito de arquitectura, porque el juego está pensado para crecer a muchas zonas.

---
← [[00 Índice del GDD|Índice del GDD]]
