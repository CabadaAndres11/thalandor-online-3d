---
tags: [gdd]
estado: implementado
actualizado: 2026-11-27
---

# 8. Botín, objetos y economía **[Implementado]** (0.7.0, Plan 5; alijo e intercambio pendientes)

- **Botín personal:** cada jugador cercano tiene su propia tirada al morir un monstruo. Los objetos caen sueltos en el suelo, con un haz de luz y su nombre del color de su rareza, y solo los ve su dueño. Se recogen pasando por encima y desaparecen a los 2 minutos.
- **Qué cae:** oro casi siempre; objetos el 12 % de las veces en monstruos normales; el élite suelta 1 seguro y a veces 2; pociones a veces. El 75 % de los objetos es usable por la clase de quien lo recibe.
- **Rarezas:**

| Rareza | Estadísticas | Color |
|---|---|---|
| Común | Fijas | blanco |
| Poco común | Fijas + 1 propiedad aleatoria | verde |
| Raro | Fijas + 2 propiedades aleatorias | azul |
| Épico | Fijas + 3 propiedades aleatorias | morado |
| Legendario | Fijas + 4 propiedades y un efecto único | naranja |
| Único de jefe | Fijas, con nombre propio y aspecto propio | dorado |

- **Propiedades aleatorias:** planas (+12 Fuerza) o porcentuales (+5 % vida), sin repetir estadística, escaladas por el nivel del objeto.
- **Nivel del objeto:** sin tope, como los personajes. Las estadísticas base escalan con él.
- **Ranuras de equipo (11):** arma principal, mano secundaria, cabeza, hombros, pecho, manos, piernas, pies, cuello y anillo ×2.
- **Requisito de nivel:** no se puede equipar un objeto de nivel superior al del personaje.
- **Equipo visible:** cada objeto base tiene **su propio modelo vóxel**. El arma, la mano secundaria, la cabeza, los hombros, el pecho, las manos, las piernas y los pies cambian el aspecto del personaje (piezas acopladas a los huesos del modelo con `BoneAttachment3D`). El resto del grupo también lo ve.
- **Iconos:** el icono de cada pieza es una **miniatura renderizada de su propio modelo** (generada al importar o al arrancar).
- **Inventario:** 30 casillas (ventana I). Clic derecho para equipar o usar; el tooltip compara con lo equipado. **No se puede vender ni tirar fuera de un mercader.**
- **Oro:** se obtiene de monstruos, misiones y ventas. Se gasta en el mercader (pociones, objetos y reparaciones), reinicio de talentos, cambio de mejora y cambio de clase.
- **Mercaderes:** en la capital. Venden pociones y seis objetos (tres comunes, dos poco comunes y uno raro que a veces sale épico; `merchant.stock` en `loot.json`), compran al 25 % del valor y reparan.
- **Durabilidad:** cada pieza equipada pierde un 10 % al morir (no al quedar derribado). A 0 no da estadísticas.
- **Pociones:** vida (Q) y recurso (R), con el 35 % y una recarga compartida de 30 s. Desde el 2026-11-27 no ocupan hueco en la bolsa: se guardan en su botón, que muestra cuántas quedan, sin límite. Los personajes antiguos las pasan de la bolsa al botón al cargarse. Iconos pintados en `assets/icons/items/`.
- **Alijo:** almacén compartido entre los personajes del mismo jugador, en la capital.
- **Intercambio entre jugadores:** fuera de la demo.

## Plan 5 (0.7.0) **[Implementado]**
- **Armadura por clase** ([[D-014 Objetos por clase, armas a dos manos y tramos épicos]]): cada tramo tiene un juego por clase que solo lleva esa clase; el tipo (placas, tela, malla, cuero) es descriptivo.
- **Tres tramos de aspecto** por nivel del objeto (1–19, 20–39, 40+), cada vez más épicos: colores propios y capa en el 2; halos, coronas, runas y **aura** en el 3. 141 objetos con modelo propio, más los **únicos** del Acólito Cultista (*Cetro del Sol Negro*), Vaelthar (*Báculo del Primer Apóstol*) y Nhazar (*Mandoble de las Mil Voces*), que sueltan con un 25 %.
- **Armas:** a dos manos (mandoble, gran hacha, martillo de guerra, alabarda, bastón, arco, ballesta) ocupan las dos manos y dan 1,8 veces las estadísticas; nuevas varita, cetro y tomo; el carcaj es un adorno fijo. Cada **familia** cambia el ataque básico; la ballesta siempre dispara cargado; el **bloqueo exige escudo**. El básico cuerpo a cuerpo se ve como un **combo de tres golpes**.
- **Mercader provisional** junto a Brann (se mudará a la capital en el Plan 6): pociones a 5 + 2 × nivel, 4 objetos comunes que se renuevan cada 10 min, compra al 25 %, repara al 20 % del valor según lo perdido; vender un raro o mejor pide confirmación.
- El oro va directo a la bolsa (número dorado flotante); los objetos caen esparcidos con un haz de su color.
- **Legendarios:** previstos en los datos, sin caer todavía (Plan 8).
- Comandos de pruebas del anfitrión: `/oro <n> [nombre]` y `/objeto <base> [nivel] [rareza] [nombre]`.

---
← [[00 Índice del GDD|Índice del GDD]]
