---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 1. Visión

**Thalandor Online** es un RPG de acción en **3D de estilo vóxel**, con **cámara isométrica** y combate en tiempo real, para jugar online con hasta 4 amigos.

Busca la sensación de un MMO clásico (personajes persistentes, clases con roles, misiones, mazmorras, botín) sin la masividad: cada jugador tiene su personaje y avanza solo o en grupo cuando coincide con sus amigos. **No hay nivel máximo**: el personaje crece indefinidamente y su clase evoluciona cada 50 niveles.

## 1.1 Pilares
1. **Tu personaje es tuyo.** El progreso vive en el personaje, no en la partida de otro jugador. Nadie depende de otro para jugar.
2. **Solo o en grupo, sin fricción.** Se puede jugar en solitario y abrir el grupo a amigos en cualquier momento.
3. **Roles que se complementan.** Tanque, sanador y daño tienen sentido en grupo, pero cada clase puede sobrevivir sola.
4. **Progreso sin techo.** Siempre hay un siguiente objetivo: nivel, mejora de clase, talento, objeto o cambio de clase.
5. **Construido para crecer.** El contenido (zonas, monstruos, objetos, misiones, mejoras de clase) se define como datos; añadir una zona no requiere tocar el motor.

## 1.2 Restricciones del proyecto
- **Presupuesto 0 €.** Toda herramienta, servicio, hosting y asset debe ser gratuito (licencias libres o gratuitas para uso).
- **Plataforma:** PC con Windows, **ejecutable descargable**. La versión web no es objetivo.
- **Jugadores:** de 1 a 4 por partida, cada uno en su casa, por internet.
- **Sin anti-trampas:** el juego es entre amigos. El host es la autoridad de la simulación y valida lo básico de los personajes, pero no se invierte en protección contra trampas.
- **Idioma:** español. Todos los textos están en archivos de datos, preparados para traducción.
- **Desarrollo:** construido íntegramente mediante prompts con Claude. Las decisiones se toman juntos; las instalaciones se piden con permiso y las pruebas de juego las hace el equipo.

## 1.3 Alcance de la primera versión jugable (demo)
- **5 clases** con kit base y pasivas de clase, y la **primera mejora de clase (nivel 50)** con sus 2 opciones por clase.
- El **prólogo y el arco 1** completos del [[Guion]], con las zonas que hagan falta (seguramente más de cuatro), y una progresión natural que acaba **hacia el nivel 60** (referencia, no tope: el sistema no tiene nivel máximo) ([[D-017 Mundo por zonas, hordas y demo del prólogo y arco 1|D-017]]).
- Atributos repartibles, árbol de talentos circular y equipo visible en el personaje.
- Multijugador online hasta 4 jugadores, guardado local y exportación de personajes.

**Fuera del alcance de la demo:** intercambio entre jugadores, soporte para mando, cambio de clase (diseñado, ver [[04 Personajes y progresión|§4.9]]), mejoras de clase a partir del nivel 100, chat de voz (se usa Discord).

---
← [[00 Índice del GDD|Índice del GDD]]
