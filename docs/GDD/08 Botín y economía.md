---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 8. Botín, objetos y economía **[Diseñado]** (sistema probado en el prototipo 2D)

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
- **Mercaderes:** en la capital. Venden pociones y objetos comunes, compran al 25 % del valor y reparan.
- **Durabilidad:** cada pieza equipada pierde un 10 % al morir (no al quedar derribado). A 0 no da estadísticas.
- **Pociones:** vida (Q) y recurso (R), con el 35 % y una recarga compartida de 30 s, en pilas de 20.
- **Alijo:** almacén compartido entre los personajes del mismo jugador, en la capital.
- **Intercambio entre jugadores:** fuera de la demo.

---
← [[00 Índice del GDD|Índice del GDD]]
