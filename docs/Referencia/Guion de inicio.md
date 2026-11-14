---
tags: [referencia]
actualizado: 2026-11-14
---
# Guion de inicio — Thalandor Online (3D vóxel, Godot)

> Abre un chat nuevo de Claude Code **en la carpeta `D:\Thalandor3D`** y pega este texto. La documentación ya está ahí, en la bóveda de Obsidian `docs/`, y `CLAUDE.md` resume las normas.

---

Hola. Vamos a desarrollar desde cero **Thalandor Online**, un RPG de acción en **3D vóxel** hecho en **Godot 4**, para jugar online con hasta 4 amigos. El **GDD** está en la bóveda de Obsidian `docs/` del proyecto, dividido en notas: empieza por `docs/GDD/00 Índice del GDD.md` (una nota por apartado y una por clase en `docs/GDD/Clases/`). Es la guía del proyecto y un documento vivo. Léelo entero antes de empezar, junto con `CLAUDE.md`.

## Contexto
- Ya hicimos un **prototipo en 2D** (Phaser + TypeScript, navegador), publicado en el repositorio público `CabadaAndres11/thalandor-online` (versión 0.5.3). Ahí están probadas las reglas que el GDD reutiliza: red host-autoritativa con predicción e interpolación, combate, amenaza, árbol de talentos circular, botín y mercader.
- Puedes consultarlo como **referencia de reglas y fórmulas**, pero **no se porta su código**: este proyecto empieza de cero en Godot, con GDScript.
- El juego se llama **Thalandor Online**.

## Cómo trabajamos (normas del proyecto)
1. **Presupuesto 0 €.** Toda herramienta, servicio, hosting y asset debe ser gratuito. Si algo tiene coste, busca la alternativa gratuita o dímelo.
2. **Decidimos juntos.** Hazme las preguntas de **una en una**, con opciones y tu recomendación primero. Si algo del GDD no está claro o choca con lo técnico, pregúntame antes de decidir por tu cuenta.
3. **Instalaciones y descargas:** las haces tú, pero **pídeme permiso antes** (di qué, de dónde y cuánto ocupa).
4. **Pruebas de juego:** las hago yo. Tú escribes y pasas los tests automáticos; cuando algo esté listo, dime exactamente qué probar.
5. **Forma de trabajar por plan:** diseño (spec) → plan de implementación → implementación con tests → revisión final → publicación. **Ejecución nativa en este chat** (sin delegar los planes enteros en subagentes).
6. Si te digo **"implementa directamente"**, sigue sin pararte a pedir revisiones intermedias, pero mantén la documentación (spec, plan, GDD).
7. **La documentación vive en Obsidian (`docs/`):** cuando cambie una decisión o se implemente algo, actualiza la nota del GDD afectada, su estado ([Diseñado], [En curso], [Implementado]) y `GDD/Registro de cambios.md`. Cada decisión importante se apunta en `Decisiones/`, las specs y planes van en `Planes/` y cada sesión deja un resumen en `Sesiones/`, usando las plantillas de `Plantillas/` y enlaces `[[...]]`.
8. **Interfaz sin scroll:** ninguna ventana puede necesitar scroll para verse entera a 1280×720. Si una ventana se llena, se reparte en otra con su propia tecla.
9. **Textos del juego en español**, en archivos de datos (preparados para traducción). El código y los commits, en inglés.
10. **Repositorio público en GitHub.** Commits con mi email personal (configúralo en el repositorio, pregúntame si no lo sabes).
11. **Contenido como datos:** clases, habilidades, monstruos, objetos, zonas y misiones viven en `data/`; añadir contenido no debe requerir tocar las reglas.
12. **Comunicación:** responde en español, claro y sin jerga innecesaria; dime siempre qué has hecho, qué falta y qué tengo que probar.

## Primeros pasos
1. **Lee `CLAUDE.md` y el GDD** (`docs/GDD/`) y dime en un resumen corto qué has entendido del proyecto, el alcance de la demo y las decisiones abiertas (§15).
2. **Revisa el entorno:** comprueba si tengo Godot 4, Git y la CLI de GitHub instalados. Propón lo que falte (Godot 4 estable, la plantilla de exportación para Windows, el addon GUT para tests) y espera mi permiso para instalarlo.
3. **Diseña el Plan 1 — Fundaciones y red** (§14) conmigo, pregunta a pregunta:
   - Estructura del proyecto Godot según §2.4.
   - Cámara isométrica y un personaje provisional (cápsula) que se mueve con WASD y apunta con el ratón.
   - Simulación host-autoritativa con predicción e interpolación.
   - **Spike de red** (§2.5): probar WebRTC con código de grupo (señalización en un plan gratuito) frente a ENet con VPN gratuita, con una prueba real entre dos casas, y elegir.
   - Grupo de hasta 4 por código, chat de texto y control de versiones al conectar.
   - Exportación a un ejecutable de Windows y publicación de una primera versión (itch.io o GitHub Releases).
4. Escribe la **spec** y el **plan** del Plan 1 en `docs/Planes/`, y cuando los apruebe, impleméntalo con tests. El proyecto Godot va en la raíz de `D:\Thalandor3D` (junto a `docs/`), y el repositorio Git abarca ambos.

Cuando termines el Plan 1 y yo lo haya probado con mis amigos, seguimos con el Plan 2 (personajes vóxel).
