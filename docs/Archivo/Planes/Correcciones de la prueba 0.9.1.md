---
tags: [plan, errores]
estado: hecho
actualizado: 2026-11-20
---
# Correcciones de la prueba 0.9.1

Errores y mejoras que encontró el usuario al probar la 0.9.1. Se corrigen **antes de seguir con el Plan 6.4**.

| # | Área | Problema / petición | Causa encontrada | Estado |
|---|---|---|---|---|
| 1 | Interfaz | El personaje del menú de selección debe mostrar el arma y la armadura que lleva | `CharacterSelectScreen` no pasa el equipo a la vista previa | Hecho (0.9.2) |
| 2 | Combate | Bajar el tiempo entre ataques básicos cuerpo a cuerpo (todas las clases) | Recargas de 0,5 a 0,8 s, y ×1,4 con armas a dos manos | Hecho (0.9.2) |
| 3 | Animación | Con armas a dos manos (mandoble, hacha) a veces un brazo tiembla | El brazo derecho se cierra en pasos fijos de 0,08 rad: en el límite del alcance salta de un fotograma a otro | Hecho (0.9.2) |
| 4 | Animación | Ataques cuerpo a cuerpo más exagerados: postura, giro del torso… | — | Hecho (0.9.2) |
| 5 | Comercio | Algunos objetos de la bolsa no se pueden vender | **El cliente compacta la bolsa al recibirla y el anfitrión no**: tras vender, las casillas no coinciden y se manda la casilla equivocada | Hecho (0.9.2) |
| 6 | Clérigo | *Consagración* y *Círculo de sanación*: sin pulsos visuales y con efectos de definitiva (coro de ángeles alrededor…) | El círculo vuelve a crecer desde cero en cada pulso | Hecho (0.9.2) |
| 7 | Clérigo | *Himno divino*: levitas y te da invulnerabilidad | — | Hecho (0.9.2) |
| 8 | Chat | El chat se conserva al cerrar sesión y al cambiar de personaje | — | Hecho (0.9.2) |
| 9 | Chat | No informa por qué no se pueden vender algunos objetos | Un hueco vacío (punto 5) se rechaza sin aviso | Hecho (0.9.2) |
| 10 | Interfaz | Cambiar «Salir al título» por «Cerrar sesión» | Texto `MENU_LEAVE` | Hecho (0.9.2) |

---
← [[Planes]]
