# Thalandor Online (3D vóxel, Godot 4)

RPG de acción 3D vóxel con cámara isométrica para jugar online con hasta 4 amigos. Desarrollo desde cero; el prototipo 2D (`D:\RPG`, repo `CabadaAndres11/thalandor-online`) es solo referencia de reglas y fórmulas.

## Documentación: bóveda de Obsidian en `docs/`
- **El GDD vive en `docs/GDD/`**, una nota por apartado (`00 Índice del GDD.md`) y una por clase (`docs/GDD/Clases/`). Es un documento vivo: actualiza el apartado afectado, su estado ([Diseñado], [En curso], [Implementado], [Abierto]) y `docs/GDD/Registro de cambios.md` cuando algo cambie o se implemente.
- **Decisiones:** cada decisión importante va en `docs/Decisiones/` (plantilla `docs/Plantillas/Decisión.md`) y se enlaza en `Índice de decisiones.md`. Lo pendiente está en `docs/GDD/15 Decisiones abiertas.md`.
- **Planes:** la spec y el plan de cada plan van en `docs/Planes/` (plantilla `Spec de plan.md`); actualiza la tabla de `docs/Planes/Planes.md`.
- **Sesiones:** al cerrar una sesión de trabajo, añade un resumen en `docs/Sesiones/` (plantilla `Sesión.md`).
- **Formato Obsidian:** enlaces internos `[[Nombre de nota]]`, propiedades YAML al inicio (`tags`, `estado`, `actualizado`). No muevas ni renombres notas sin actualizar sus enlaces.

## Normas del proyecto
1. **Presupuesto 0 €:** solo herramientas, servicios y assets gratuitos.
2. **Decidimos juntos:** preguntas de una en una, con opciones y la recomendación primero.
3. **Instalaciones y descargas:** pedir permiso antes (qué, de dónde, cuánto ocupa).
4. **Las pruebas de juego las hace el usuario;** los tests automáticos (GUT) los escribe y pasa Claude.
5. **Por plan:** spec → plan → implementación con tests → revisión final → publicación. Ejecución nativa en el chat.
6. **"Implementa directamente"** = no parar a pedir revisiones intermedias, pero mantener la documentación.
7. **Interfaz sin scroll:** ninguna ventana puede necesitar scroll a 1280×720; si se llena, se reparte en otra ventana con su propia tecla.
8. **Idioma:** textos del juego y documentación en español (textos del juego en archivos de datos); código y commits en inglés.
9. **Contenido como datos** en `data/`; añadir contenido no debe requerir tocar las reglas en `sim/`.
10. **Repositorio público** en GitHub; commits con el email personal del usuario.
