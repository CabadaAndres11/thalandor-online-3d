---
tags: [plan, spec]
plan: 6.1
fecha: 2026-11-19
estado: aprobado
actualizado: 2026-11-19
---
# Plan 6.1 — Iluminación, ambientes y opciones: diseño

## Objetivo
Primera parte de la [[14 Hoja de ruta|renovación gráfica (Plan 6)]]: que la escena deje de verse plana e infantil **sin tocar aún los modelos**. Iluminación y postprocesado de calidad, dos **ambientes como datos** (exterior de día y mazmorra o noche) y una ventana de **Opciones** con calidad de vídeo y volumen de sonido, para que los equipos flojos del grupo puedan jugar.

**Por qué:** la iluminación cambia el aspecto de todo y no depende de los modelos, así que se ve la mejora enseguida y los modelos de 6.2–6.4 se revisarán ya con la luz definitiva. Referencias en [[Estilo gráfico objetivo (Plan 6)]].

**Versión:** 0.8.0 *(decisión de Claude: el Plan 6 completo es la serie 0.8.x)*. Sin cambio de protocolo de red ni de versión de personaje.

## Partes del Plan 6 ([[D-015 Vóxel 2× y renovación gráfica en cuatro partes]])
| Parte | Contenido |
|---|---|
| **6.1** | Iluminación, ambientes y opciones (esta spec) |
| 6.2 | Humanoide y piezas con vóxel 2× (98 vóxeles de alto) |
| 6.3 | Equipo con vóxel 2× |
| 6.4 | Monstruos, PNJ y ropa (capas, túnicas, auras) que sigue al cuerpo |

## Fuera de alcance
- Modelos nuevos (6.2–6.4) y arte del mundo: bloques con textura, props y decorado (Plan 8). En la arena solo se añaden antorchas.
- Ciclo de día y noche (Plan 8, cuando haya zonas).
- Música y efectos de sonido (Plan 11): aquí solo los canales y sus volúmenes.
- Reasignar teclas, idioma y demás opciones (Plan 11).
- Renderizador Compatibility para gráficas sin Vulkan: se valora solo si algún amigo no puede arrancar el juego.

## Antifines
- Que un ambiente o la calidad elegida cambie algo de las reglas (`sim/`) o viaje por la red.
- Que añadir un ambiente exija tocar código: es un JSON en `data/ambiences/`.
- Que la calidad Baja vaya peor que la 0.7.0 en el mismo equipo.
- Que la ventana de Opciones necesite scroll a 1280×720.
- Que perder o corromper el archivo de ajustes impida arrancar: se vuelve a los valores por defecto.

## Enfoques
- **A (elegido): `Environment` de Godot (Forward+) configurado desde JSON.** Un cargador lee el ambiente y monta sol, cielo, niebla y efectos; una capa de calidad recorta lo que el equipo no puede pagar.
- **B: entornos `.tres` hechos a mano en el editor.** Descartado: se salta la norma de contenido como datos y obliga a duplicar cada ambiente por calidad.
- **C: renderizador Compatibility para los equipos flojos.** Descartado por ahora: cambiarlo exige reiniciar el juego y pierde oclusión ambiental, niebla volumétrica y reflejos. La escala de resolución y la calidad Baja cubren ese caso.

## Diseño

### 1. Ambientes como datos (`data/ambiences/`)
Un JSON por ambiente; las claves que falten toman un valor por defecto. Campos:
- **Sol:** color, energía, ángulo (elevación y orientación), sombras sí/no.
- **Cielo:** degradado de horizonte y cénit (o color liso para interiores).
- **Luz ambiental:** color y energía.
- **Niebla:** color, densidad, altura y, en Alta, niebla volumétrica con su densidad y albedo.
- **Postprocesado:** tonemap (ACES o fílmico) y exposición; brillo (intensidad, umbral, mezcla); oclusión ambiental (radio, intensidad); corrección de color (brillo, contraste, saturación); reflejos en superficies (sí/no); desenfoque de fondo (distancia y fuerza).
- **Partículas de ambiente:** tipo (`embers` = brasas, `dust` = motas de polvo, `none`), cantidad y color.

Ambientes iniciales:
- **`exterior_dia`:** sol cálido y bajo (tarde), cielo en degradado, niebla de distancia azulada, oclusión ambiental, brillo suave, contraste y saturación algo más altos que hoy pero sin colores de juguete; motas de polvo.
- **`mazmorra_noche`:** sol tenue y frío (luna), ambiente muy oscuro, niebla densa y cálida cerca del suelo, brillo marcado en lo luminoso, brasas flotando; la luz principal la ponen las antorchas (referencia 2).

Cada mapa elige el suyo con `"ambience": "exterior_dia"` en su JSON (`test_arena.json` usa `exterior_dia`). Si falta o no existe, se usa `exterior_dia` y se avisa en el registro.

### 2. Antorchas
- Prop vóxel propio (palo y cuenco de hierro, generado en `tools/art/`) con un `OmniLight3D` cálido que **parpadea** (energía y alcance con ruido suave, desfasado por antorcha) y una llama de partículas con brillo.
- Se colocan con `"torches": [[x, z], …]` en el JSON del mapa; la arena recibe unas cuantas junto a los bloques y a Brann.
- Las antorchas existen en los dos ambientes; de día casi no se notan.
- Sombras de las antorchas solo en Alta; en Baja, la luz se apaga más allá de una distancia corta (atenuación por distancia de Godot).

### 3. Calidad de vídeo
Tres niveles. La calidad **recorta** lo que pide el ambiente; el ambiente no sabe nada de calidades.

| Efecto | Baja | Media | Alta |
|---|---|---|---|
| Sombras del sol | 2048, 1 cascada, corto alcance | 4096, 2 cascadas | 4096, 4 cascadas, filtro suave |
| Sombras de antorchas | no | no | sí |
| Oclusión ambiental (SSAO) | no | sí, baja | sí, alta |
| Niebla | de distancia simple | de distancia y altura | + volumétrica |
| Brillo (glow) | sí, barato | sí | sí |
| Corrección de color y tonemap | sí | sí | sí |
| Reflejos (SSR) | no | no | sí |
| Desenfoque de fondo | no | no | sí |
| Partículas de ambiente | 25 % | 60 % | 100 % |
| Antialiasing | FXAA | FXAA | MSAA 2× + FXAA |

Además, independientes de la calidad:
- **Escala de resolución:** 50 %–100 % (por defecto 100 %), con FSR 1 al bajar de 100 %.
- **Modo de pantalla:** ventana o pantalla completa (sin bordes).
- **VSync:** sí/no.
- **Límite de FPS:** sin límite, 30, 60, 120, 144.

Valor por defecto la primera vez: **Media** *(decisión de Claude: sin una prueba automática de rendimiento fiable, Media es el punto seguro; el jugador sube o baja)*.

### 4. Sonido
- Canales (`AudioBus`): **General** (Master), **Música**, **Efectos** e **Interfaz**, declarados en el layout de buses del proyecto.
- Un volumen 0–100 % por canal, más silenciar General. Se aplican aunque aún no suene nada; el Plan 11 solo tendrá que reproducir en el canal correcto.

### 5. Ventana de Opciones
- Se abre desde el **menú de pausa (Esc)** con un botón «Opciones» y desde la **pantalla de título**.
- Dos pestañas: **Vídeo** (calidad, escala, pantalla, VSync, FPS) y **Sonido** (cuatro volúmenes y silencio). Cabe sin scroll a 1280×720.
- Los cambios se aplican al momento (vista previa en vivo); botones **Restablecer** y **Cerrar**. Se guarda al cerrar.
- Estilo de las demás ventanas (`holo_theme`); textos en `data/texts/textos.csv`.

### 6. Guardado de ajustes
- Se amplía el `user://settings.json` que ya existe (`SettingsStore`, último personaje y código) a la **versión 3**, con las claves de vídeo y sonido. Local a cada equipo.
- Se carga al arrancar, antes de la pantalla de título (como hoy). Valores ausentes o no válidos → valor por defecto; archivo ilegible → todos por defecto, sin error visible.

### 7. Comando `/ambiente`
- `/ambiente` sin argumento muestra el actual y la lista; `/ambiente <id>` lo cambia.
- Es **local**: solo cambia la vista de quien lo escribe, no pasa por el anfitrión. Sirve para comparar en la arena.

### 8. Piezas de código
*(Nombres orientativos; el plan los fija.)*
- `game/visual/ambience.gd`: carga y valida un ambiente JSON → datos.
- `game/visual/ambience_builder.gd`: aplica ambiente + calidad → `Environment`, sol y partículas. Es la única pieza que cruza ambos.
- `game/visual/torch.gd`: prop de antorcha con luz parpadeante.
- `save/settings_store.gd` (existe): guarda también vídeo y sonido.
- `game/visual/settings_applier.gd`: aplica ventana, VSync, FPS, escala y volúmenes; `main.gd` lo usa al arrancar y al cambiar algo, y avisa a la partida para reconstruir el entorno si cambia la calidad. El juego no usa autoloads.
- `ui/options_window.gd`: la ventana.
- `arena.gd` deja de crear la luz a mano y usa el constructor de ambientes.
- La vista previa del personaje (`ui/character_preview.gd`) y los iconos (`item_icons.gd`) siguen con su luz propia de estudio; se revisa que no hereden el ambiente.

## Pruebas
- **Automáticas (GUT):**
  - Carga de ambientes: valores por defecto, claves desconocidas ignoradas, id inexistente → `exterior_dia`.
  - Constructor: para cada calidad, los efectos activos coinciden con la tabla del §3 (p. ej. Baja sin SSAO, SSR ni volumétrica; Alta con todo lo que pide el ambiente; un ambiente sin brillo no lo activa en Alta).
  - Ajustes: guardar y cargar ida y vuelta, valores fuera de rango recortados, archivo corrupto → por defecto, volúmenes aplicados a los buses.
  - Mapa: `torches` y `ambience` se leen del JSON.
  - Comando `/ambiente`: cambia el ambiente local y rechaza ids desconocidos.
  - La ventana de Opciones cabe en 1280×720.
- **Prueba de juego (usuario):** comparar los dos ambientes en la arena, las tres calidades y la escala de resolución; que se vea menos infantil y que la calidad Baja vaya fluida en el equipo más flojo.

## Decisiones tomadas
- Vóxel 2× y Plan 6 en cuatro partes: [[D-015 Vóxel 2× y renovación gráfica en cuatro partes]].
- Dos ambientes como datos, elegidos por mapa (usuario).
- Ajustes de calidad de vídeo y de volumen ya en este plan, porque algún amigo puede tener un equipo flojo (usuario).
- Calidad por defecto Media, versión 0.8.0, `/ambiente` local *(decisiones de Claude)*.

---
← [[Planes]]
