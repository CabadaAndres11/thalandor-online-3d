---
tags: [plan, errores]
estado: pendiente
actualizado: 2026-11-20
---
# Correcciones de la prueba 0.9.1

Errores y mejoras que encontró el usuario al probar la 0.9.1. Se corrigen **antes de seguir con el Plan 6.4**.

| # | Área | Problema / petición | Causa encontrada | Estado |
|---|---|---|---|---|
| 1 | Interfaz | El personaje del menú de selección debe mostrar el arma y la armadura que lleva | `CharacterSelectScreen` no pasa el equipo a la vista previa | Pendiente |
| 2 | Combate | Bajar el tiempo entre ataques básicos del clérigo | *Castigo*: 0,8 s de recarga | Pendiente |
| 3 | Animación | Con armas a dos manos (mandoble, hacha) a veces un brazo tiembla | El brazo derecho se cierra en pasos fijos de 0,08 rad: en el límite del alcance salta de un fotograma a otro | Pendiente |
| 4 | Animación | Ataques cuerpo a cuerpo más exagerados: postura, giro del torso… | — | Pendiente |
| 5 | Comercio | Los objetos del equipo inicial no se pueden vender | Sin causa en la simulación: se venden desde la bolsa. No se puede vender lo que llevas puesto | Pendiente |
| 6 | Clérigo | *Consagración* y *Círculo de sanación*: sin pulsos y con efectos de definitiva (coro de ángeles alrededor…) | Hoy curan o dañan a pulsos de 1 s | Pendiente |
| 7 | Clérigo | *Himno divino*: levitas y te da invulnerabilidad | — | Pendiente |
| 8 | Chat | El chat se conserva al cerrar sesión y al cambiar de personaje | — | Pendiente |
| 9 | Chat | No informa por qué no se pueden vender algunos objetos | Ver el punto 5: lo que llevas puesto no avisa | Pendiente |
| 10 | Interfaz | Cambiar «Salir al título» por «Cerrar sesión» | Texto `MENU_LEAVE` | Pendiente |

---
← [[Planes]]
