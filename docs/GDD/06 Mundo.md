---
tags: [gdd]
estado: en curso
actualizado: 2026-11-22
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
- **Casas accesibles** **[Implementado 0.11.1]**: las casas se dibujan a 10 cm por vóxel en cuatro partes (suelo y muebles, paredes, paredes recortadas a 1 m y tejado). Se entra por una puerta de 2 casillas; al pisar el interior, el tejado se funde y las paredes se recortan, solo en la pantalla de quien está dentro.
- **Rendimiento** **[Implementado 0.11.1]**: las caras iguales de los modelos vóxel se fusionan; las piezas y el suelo van en trozos de 16×16 casillas; de cerca se ve el modelo completo y lejos una copia de la mitad de resolución; las sombras las da una copia simplificada y nunca las piezas pequeñas (sin sombras de piezas en calidad baja). La zona se construye por pasos detrás de la pantalla de carga, que dura al menos 0,6 s; un invitado se conecta cuando su zona ya está cargada.
- **Iluminación:** cada zona elige un **ambiente** de `data/ambiences/` con `"ambience"` en su JSON y coloca antorchas con `"torches"` **[Implementado 0.8.0]**. Ciclo de día y noche opcional por zona (Plan 8); las mazmorras usan luces locales (antorchas) para dar ambiente.

## 6.2 Contenido de la demo **[En curso]** (Plan 8, según el guion)
La demo cubre el **prólogo y el arco 1** (misiones 1–14) y termina hacia el **nivel 50** al salir de la capital rumbo al volcán.

| Zona | Niveles | Contenido |
|---|---|---|
| **Aldea** | 1–5 | Tutorial en solitario (misiones 1–2); Brann en la forja |
| **Bosque**, camino de la capital | 5–20 | Hordas, el rastro del Heraldo y la emboscada de bandidos (misiones 3–4) |
| **Capital** | — | Zona segura: mercaderes, instructor, alijo y misiones |
| **Afueras de la capital** | 20–35 | Hordas entre misiones del arco 1 |
| **Alcantarillas y submundo** | 30–40 | Misión 8 |
| **Cripta bajo el palacio** | 35–50+ | Mazmorra instanciada y repetible (misiones 5, 11 y 12) |

- **Provisional (0.11.0):** una aldea y un bosque de prueba conectados y una **cripta de prueba** instanciada al fondo del bosque. Su diseño definitivo llega con el prólogo (Plan 8.3).
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
