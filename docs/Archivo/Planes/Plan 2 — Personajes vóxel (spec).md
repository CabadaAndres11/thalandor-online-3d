---
tags: [plan, spec]
plan: 2
fecha: 2026-11-14
estado: aprobada
actualizado: 2026-11-14
---
# Plan 2 — Personajes vóxel: diseño

## Objetivo
Sustituir las cápsulas por **personajes vóxel propios**. Al abrir el juego eliges uno de **tus personajes** (hasta 8) en una pantalla que muestra su modelo 3D girando, o creas uno nuevo eligiendo nombre, clase y apariencia con una vista previa en vivo. Entras al escenario con ese personaje, que se anima al quedarse quieto y al andar. Tus amigos lo ven igual que tú. Los personajes se guardan en tu PC y se pueden exportar e importar como archivo.

**Por qué:** el personaje es lo que el jugador siente como suyo. Además, todo lo que viene después se engancha a él: las habilidades y animaciones del combate (Plan 3), el nivel y los talentos (Plan 4) y el equipo visible (Plan 5). Este plan deja listos el modelo por piezas, la forma de vestirlo y el guardado.

**Éxito:** creas dos personajes distintos, eliges uno, abres grupo y un amigo ve tu personaje con su aspecto, su nombre y su animación al andar. Cierras el juego y al volver tus personajes siguen ahí. Exportas uno, lo importas en otro PC y es idéntico.

## Fuera de alcance
- Equipo visible, armas en la mano e inventario (Plan 5). Este plan solo prepara el sistema de piezas al que se engancharán.
- Combate, habilidades y animaciones de ataque, hechizo, esquiva o muerte en uso (Plan 3). El modelo base ya las trae, pero no se usan todavía.
- Experiencia, atributos, talentos y subir de nivel (Plan 4). Todos los personajes son de **nivel 1**.
- Cambio de clase (§4.9) y las mejoras de clase.
- La decisión de red: la prueba entre casas sigue **aplazada** y se mantienen WebRTC (por defecto) y ENet.
- Opciones, audio y menús de ajustes (Plan 7).

## Enfoques considerados
| Enfoque | Qué es | Pros | Contras |
|---|---|---|---|
| 1. Capas de textura | La textura del personaje se monta apilando capas teñidas (piel, ojos, pelo, barba, ropa) sobre el modelo de Kenney | Mucha variedad, todo son datos, poco trabajo | El pelo y la ropa son planos: todas las siluetas son iguales |
| 2. Personajes predefinidos | Unos cuantos personajes completos, y solo se tiñen piel y pelo | Lo más rápido | Poca variedad, se aleja del GDD |
| **3. Capas + piezas vóxel (elegido)** | Lo mismo que el enfoque 1, más **piezas vóxel en 3D** enganchadas a las partes del cuerpo (pelos largos, capuchas, sombreros) | La silueta cambia de verdad. El sistema de piezas es el mismo que usará el equipo en el Plan 5 | Más trabajo: lector de vóxeles, mallas y enganches |

Se eligió el **enfoque 3**. Antes se había elegido el 1, y el usuario cambió de idea para tener siluetas distintas desde ya y no rehacer el sistema en el Plan 5.

La **base del modelo** se eligió entre:
- **Kenney Blocky Characters**: CC0, de bloques, animado. **Elegido.**
- **KayKit Adventurers**: CC0, pero *low-poly* liso. Chocaría con el mundo de bloques.
- **Monogon Voxel RPG Characters**: de pago y su licencia no permite modificarlo.

## Diseño

### 1. Modelo base (Kenney Blocky Characters 2.0, CC0)
- **Qué trae el pack:**
  - Seis piezas rígidas, sin deformación: `torso` (hijo de `root`), `head`, `arm-left` y `arm-right` (hijos de `torso`), y `leg-left` y `leg-right` (hijos de `root`).
  - Los 18 personajes del pack comparten exactamente la misma geometría. Solo cambia la textura (1024×1024, sin iluminación propia: `KHR_materials_unlit`).
  - 27 animaciones por nodo. Entre ellas: `idle`, `walk`, `sprint`, `die`, `attack-melee-right/left`, `holding-*-shoot`, `interact-*` y `emote-yes/no`.
- **Qué se copia al proyecto:** un único modelo, `character-a.glb`, a `assets/characters/base/`. De él se usan la malla y las animaciones. Las texturas del pack solo sirven como fuente para recortar capas (§2). El pack completo **no** se mete en el repositorio.
- **Rejilla y escala:**
  - Rejilla vóxel de **0,1 unidades del modelo**: cabeza de 8×8×8, torso de 8×9×6, brazos de 4×11×4 y piernas de 4×10×4. Mide **27 vóxeles de alto** (GDD §11: 24-32).
  - El modelo se escala para medir unos **1,8 m** en el mundo (factor ≈ 0,67).
  - El radio de colisión sigue siendo 0,4 m (`sim/` no cambia).
- **Iluminación:** _decisión mía:_ el material pasa a sombreado normal en vez de *unlit*, para que las sombras del escenario caigan sobre el personaje (GDD §11: "iluminación suave con sombras"). Si queda peor, se vuelve a *unlit*, sin más cambios.
- **Créditos:** se crea `CREDITS.md` con Kenney (CC0, no obligatorio, pero lo pide el GDD §11).

### 2. Apariencia por capas de textura
- La textura de cada personaje se compone en un **shader** con varias capas sobre la plantilla UV de Kenney. Todas las capas son PNG RGBA de 1024×1024:

| Capa | Teñida con | Origen |
|---|---|---|
| Piel (todo el cuerpo, en gris con sombreado) | Tono de piel | Recortada de las texturas de Kenney |
| Cara: cejas, boca, nariz | — | Kenney |
| Ojos | Color de ojos | Kenney |
| Peinado (parte pintada en la cabeza) | Color de pelo | Kenney (recortes) y nuevos |
| Barba (opcional) | Color de pelo | Kenney |
| Ropa inicial de la clase | — (colores propios) | **Nueva**, una por clase |

- **Teñir** significa multiplicar el gris de la capa por el color elegido, para conservar el sombreado de Kenney.
- **Tipos de cuerpo:** 2, *Esbelto* y *Robusto*. Se hacen cambiando la escala de las piezas: el robusto tiene el torso y los brazos más anchos y se escala solo en X y Z. No hay geometría nueva.
- **Opciones iniciales** (propuesta mía, ampliables en datos):
  - 2 tipos de cuerpo;
  - 8 tonos de piel;
  - 6 colores de ojos;
  - 8 peinados (unos solo pintados, otros con pieza vóxel, §3);
  - 10 colores de pelo;
  - 5 barbas, incluida "sin barba".
- **Catálogo en datos:** `data/characters/appearance.json` lista cada opción con su id, la clave de texto de su nombre, su archivo de capa o pieza y su color. Añadir un peinado o un color no toca código (norma 9).

### 3. Piezas vóxel
- **Formato:** archivos **MagicaVoxel `.vox`** en `assets/characters/pieces/`. Es una herramienta gratuita, cualquiera puede editarlos y yo los genero con scripts. El juego trae un lector de `.vox`: solo hacen falta los bloques `SIZE`, `XYZI` y `RGBA`, que es un formato sencillo.
- **Malla:** cada pieza se convierte en malla al cargarla. Solo se dibujan las caras visibles, sin caras interiores. La malla se guarda en caché por pieza y color.
- **Colores teñibles:** algunos índices de la paleta del `.vox` están reservados y se pintan con un color de la apariencia en vez del suyo:
  - "color de pelo";
  - "color principal de la clase";
  - "color secundario de la clase".

  Así, una sola coleta sirve para todos los colores de pelo.
- **Enganche:** cada pieza indica en datos a qué parte se engancha (`head`, `torso`, `arm-left`…) y su desplazamiento en vóxeles. La pieza es hija de esa parte, así que sigue sus animaciones. Es el mismo mecanismo que usarán el casco, la espada o el escudo en el Plan 5.
- **Ocultar:** una pieza puede ocultar a otras. Por ejemplo, una capucha oculta los pelos largos y la capa de peinado de la parte de arriba.
- **Piezas del Plan 2** (propuesta mía):
  - **pelos con volumen**: melena, coleta, moño y cresta;
  - **un tocado por clase** como parte de la ropa inicial:

| Clase | Ropa inicial (textura) | Tocado (vóxel) |
|---|---|---|
| Guerrero | Gambesón y cinturón, botas | — (cabeza descubierta; el casco llegará con el equipo) |
| Clérigo | Hábito con estola | Capucha baja sobre los hombros |
| Mago | Túnica larga | Sombrero de ala ancha |
| Arquero | Jubón de cuero y carcaj pintado | Capucha |
| Asesino | Ropa ajustada oscura | Pañuelo que tapa la boca |

### 4. Animaciones
- El avatar elige la animación por la **velocidad** de su posición dibujada:
  - parado → `idle`;
  - en movimiento → `walk`, con la velocidad de reproducción ajustada a la velocidad real.

  Para los demás jugadores la velocidad se saca de la interpolación. Para el propio, de la predicción.
- El cuerpo **mira hacia donde apunta el ratón**, como ahora, y las piernas andan en esa misma dirección. _Decisión mía:_ no se separan torso y piernas en este plan. Si queda raro al andar de espaldas, se ajustará en el Plan 3 con el combate.
- Las animaciones se mezclan con una transición corta (≈0,15 s) para que no haya saltos.

### 5. Personajes y guardado (`save/`)
- **`CharacterData`:** `id` (aleatorio), `name`, `class_id`, `appearance` (id de cada opción), `level` (1), `created_at` y `version` del formato.
- **Archivos:** uno por personaje, `user://saves/characters/<id>.json` (GDD §10). Como máximo **8**. El nombre sigue la misma regla que hoy: 2-16 caracteres de letras con tildes, números, espacios, `-` y `'`. Además no puede repetirse entre tus personajes, sin distinguir mayúsculas.
- **Versiones:** cada archivo lleva su `version`. Al cargarlo se migra si es antiguo; este plan crea la versión 1 y el mecanismo de migración. Un archivo dañado no borra nada: se ignora, se avisa y se deja como está.
- **Exportar e importar:**
  - Exportar guarda el personaje en un `.json` donde el usuario elija (diálogo de archivos de Windows).
  - Importar lo **valida y sanea**: las opciones de apariencia desconocidas pasan al valor por defecto.
  - Si al importar el nombre ya existe, se pide otro. Si ya hay 8 personajes, se avisa y no se importa.
- **Ajustes:** `settings.json` deja de guardar el nombre del jugador y guarda el **último personaje elegido** y el último código. _Decisión mía:_ no se crea ningún personaje automático a partir del nombre antiguo, porque harían falta una clase y una apariencia que el jugador no ha elegido. Ese nombre solo aparece ya escrito al crear el primer personaje.

### 6. Pantallas (sin scroll a 1280×720, norma 7)
**Título** → **Tus personajes** → escenario.
- **Tus personajes:**
  - a la izquierda, la lista de hasta 8, con nombre, clase y nivel;
  - a la derecha, el modelo 3D del seleccionado girando despacio en un `SubViewport`;
  - botones **Crear**, **Borrar** (pide confirmación), **Exportar**, **Importar**, **Jugar** y **Unirse a un amigo** (pide el código);
  - **Jugar** funciona igual que hoy: entras tú solo como anfitrión, y desde el escenario **Esc → Abrir grupo** da el código a tus amigos. Solo cambia que entras con el personaje elegido en vez de con un nombre;
  - sin personajes, solo están activos Crear e Importar.
- **Crear personaje:**
  - nombre;
  - las 5 clases como botones, cada una con una línea de descripción;
  - apariencia con flechas ◀ ▶ por opción y muestras de color para piel, pelo y ojos;
  - **vista previa en vivo** que se puede girar arrastrando con el ratón;
  - botones **Aleatorio**, **Crear** y **Volver**.
- Los errores (nombre no válido o repetido, máximo de personajes, archivo no válido) salen en el mismo diálogo de mensajes que ya existe.
- Todos los textos van en `data/texts/textos.csv`: nombres de clases, de opciones y de pantallas.

### 7. Red
- **HELLO** lleva el personaje: nombre, `class_id` y apariencia. **WELCOME** y **PLAYER_JOINED** llevan esos datos por cada jugador en lugar del color de hueco. Sube la versión del protocolo.
- **No se puede jugar entre 0.1.x y 0.2.0.** Ya pasa hoy: el anfitrión rechaza otra versión del juego con un aviso.
- La apariencia viaja como diccionario de ids cortos. El tamaño de los mensajes no cambia de forma apreciable.
- `sim/` ya tiene la dirección en la que mira el jugador (`PlayerState.facing`). El avatar la sigue usando.
- El anfitrión **sanea** lo que recibe (GDD §2.2): una clase o una opción desconocida pasa al valor por defecto y el jugador entra sin ser expulsado.
- Los nombres repetidos dentro del grupo se permiten. _Decisión mía:_ son personajes de jugadores distintos.
- El hueco (0-3) se sigue usando para el sitio de aparición y el color del nombre.

### 8. Datos
| Archivo | Contenido |
|---|---|
| `data/characters/appearance.json` | Opciones de apariencia (§2) |
| `data/characters/classes.json` | Por clase: id, claves de texto, capa de ropa, tocado, colores principal y secundario |
| `data/characters/pieces.json` | Por pieza: archivo `.vox`, parte a la que se engancha, desplazamiento y qué oculta |

Las 5 clases completas (recursos, kit) se definen en el Plan 3. Aquí solo se usa lo visual.

### 9. De dónde sale el arte nuevo
- **Recortes de Kenney** (piel, caras, ojos, peinados, barbas): un script en `tools/art/` los saca de las 18 texturas del pack y los convierte en capas grises teñibles. Se ejecuta una vez y su resultado (PNG) se guarda en el repositorio.
- **Ropa de las 5 clases y piezas `.vox`:** las genero yo con scripts del mismo estilo (formas planas y sombreado suave, como Kenney). Si alguna no queda a la altura, la rehacemos con Blender o Claude Design, con la ayuda del usuario.
- Los scripts de `tools/art/` usan Node, que ya está instalado, sin dependencias nuevas.
- **El pack ya está descargado** (el usuario lo bajó a su carpeta de Descargas el 2026-11-14). Los 18 personajes comparten geometría, así que también comparten la plantilla UV: cada parte del cuerpo ocupa la misma zona en todas las texturas.
- **Riesgo principal: separar las capas.** Las texturas de Kenney vienen pintadas a todo color. Sacar de ellas capas grises de piel, pelo u ojos que se puedan teñir puede no quedar limpio. _Decisión mía:_ la **primera tarea del plan es una prueba de viabilidad**. Se monta un personaje completo:
  - piel, ojos, un peinado y una barba recortados y teñidos;
  - la ropa de una clase;
  - dos piezas `.vox` (una melena y el sombrero del mago).

  Se le enseña al usuario en capturas antes de hacer el resto del arte. Si los recortes no quedan bien, esas capas se repintan con formas planas, en el estilo de Kenney, en vez de recortarse. Si el estilo no convence, se pasa a Blender o Claude Design. Ese cambio no toca el código.
- **Segundo punto de control de arte:** cuando estén las 5 clases y todas las piezas, se enseñan en capturas antes de construir las pantallas.

## Pruebas
**Automáticas (GUT):**
- **Lector `.vox`:** lee archivos generados en el test (tamaño, vóxeles y paleta) y rechaza los archivos dañados sin errores de script.
- **Mallas:** un cubo de 1 vóxel tiene 6 caras, y dos vóxeles juntos tienen 10. Los colores teñibles se aplican bien.
- **Catálogo:** se cargan `appearance.json`, `classes.json` y `pieces.json`. Todo archivo citado existe y toda clase y opción tiene sus textos.
- **`CharacterData`:**
  - guardar y cargar da lo mismo;
  - la migración desde una versión de ejemplo funciona;
  - los datos se sanean (opciones desconocidas, nombre no válido);
  - se respeta el máximo de 8 y no se aceptan nombres repetidos;
  - un archivo dañado se ignora sin borrarse.
- **Exportar e importar:** una exportación importada es idéntica.
- **Avatar:**
  - se construye para **todas** las combinaciones de clase, cuerpo y peinado sin errores;
  - cada pieza queda enganchada a su parte;
  - las ocultaciones funcionan (capucha frente a melena);
  - el avatar elige `idle` o `walk` según la velocidad.
- **Red:**
  - HELLO y WELCOME con personaje;
  - el anfitrión sanea una apariencia inventada;
  - dos sesiones en memoria se ven la clase y la apariencia;
  - la prueba de dos procesos sigue pasando con un personaje.
- **Interfaz:** las pantallas nuevas caben a 1280×720 sin scroll (se amplía la prueba que ya existe).

**De juego (usuario):** crear varios personajes, ver que se distinguen bien de un vistazo, elegir uno, jugar solo y en grupo, exportar e importar.

## Publicación
Al terminar, **versión 0.2.0** en GitHub Releases, con las notas actualizadas.

## Antes de empezar
Cerrar el Plan 1:
- su revisión final (tarea 19);
- apuntar en el plan y en [[15 Decisiones abiertas]] que la prueba entre casas queda aplazada.

## Decisiones tomadas
- **Base:** Kenney Blocky Characters 2.0 (CC0). Usuario.
- **Apariencia por capas de textura + piezas vóxel** (enfoque 3). Usuario.
- **Packs gratuitos primero**, con vóxel como datos para lo que falte y Blender o Claude Design como último recurso. Usuario.
- **Prueba entre casas aplazada** hasta que el juego tenga más contenido. Usuario.
- **Decisiones mías:**
  - sombreado normal en lugar de *unlit*;
  - formato `.vox`;
  - tipos de cuerpo por escala;
  - número de opciones de apariencia;
  - tocado por clase;
  - animación por velocidad, sin separar torso y piernas;
  - nombres repetidos permitidos dentro de un grupo;
  - la prueba de viabilidad del arte es la primera tarea, con dos puntos de control en capturas;
  - "Jugar" funciona como hoy;
  - no se convierte el nombre antiguo en personaje.

---
← [[Planes]]
