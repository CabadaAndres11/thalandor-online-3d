---
tags: [gdd, clase]
estado: implementado
actualizado: 2026-11-15
---

# Clérigo

- **Recurso:** Maná
- **Rol base:** Sanador o daño sagrado
- **Armas:** Maza, bastón, escudo, orbe
- **Armadura:** Tela

Reglas generales en [[04 Personajes y progresión]].

## Kit base y pasivas
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Destello sagrado (CI) | Activa | Proyectil de luz. |
| 1 | Sanar (CD) | Activa | Cura al aliado bajo el cursor o, si no hay ninguno, a sí mismo. |
| 1 | Palabra de escudo | Activa | Escudo que absorbe daño. |
| 3 | Renovar | Activa | Curación en el tiempo. |
| 6 | Nova sagrada | Activa | Daño en área y curación a los aliados cercanos. |
| 10 | Purificar | Activa | Quita efectos negativos de un aliado. |
| 20 | Resurrección | Activa | Levanta a distancia a un aliado derribado (recarga larga). |
| 5 | Meditación | Pasiva | La regeneración de maná continúa al 50 % en combate. |
| 15 | Fe inquebrantable | Pasiva | +10 % de curación recibida. |
| 25 | Gracia | Pasiva | +10 % de curación realizada. |
| 35 | Eco de luz | Pasiva | Las curaciones dejan una curación extra en el tiempo. |

## Mejoras de clase del nivel 50
Se elige una de las dos al llegar al nivel 50 (ver [[04 Personajes y progresión|§4.4]]).

| Mejora | Activas | Pasivas | Evoluciona |
|---|---|---|---|
| **Sanador** | Círculo de sanación; Himno divino (canalizado) | Ángel guardián (salva a un aliado de un golpe mortal); Gracia mayor (+20 % curación) | Sanar rebota a un segundo aliado |
| **Castigador** | Fuego sagrado (quemadura); Juicio (+15 % daño recibido de todo el grupo) | Ira divina (+15 % daño sagrado); Expiación (el daño cura al aliado más herido) | Destello sagrado atraviesa enemigos |

## Rangos siguientes (nivel 100+)
_Por diseñar._

## Valores iniciales (0.4.0)
Generados de `data/characters/classes.json` y `data/abilities/cleric.json`; son la propuesta inicial, ajustable tras las pruebas.

- **Estadísticas:** vida 150 · poder de ataque 10 · poder mágico 20 · armadura 15 · crítico 5 % · esquiva 0 %
- **Recurso:** Maná máx. 150, empieza en 150, +6/s, no se regenera en combate

| Nivel | Habilidad | Tipo | Coste | Recarga | Alcance | Efecto |
|---|---|---|---|---|---|---|
| 1 | Destello sagrado | Básico (CI) | 0 | 0,8 s | 20 m | Proyectil de luz. |
| 1 | Sanar | Secundario (CD) | 20 | 1,5 s | 20 m | Cura al aliado bajo el cursor o, si no hay ninguno, a ti. |
| 1 | Palabra de escudo | Activa | 30 | 10 s | 20 m | Escudo que absorbe daño durante 8 s, sobre el aliado bajo el cursor o sobre ti. |
| 3 | Renovar | Activa | 25 | 8 s | 20 m | Cura al aliado bajo el cursor (o a ti) poco a poco durante 6 s. |
| 6 | Nova sagrada | Activa | 40 | 12 s | 4 m | Una ola de luz daña a los enemigos a 4 m y cura a los aliados a 4 m. |
| 10 | Purificar | Activa | 25 | 10 s | 20 m | Quita los efectos negativos del aliado bajo el cursor (o los tuyos). |
| 20 | Resurrección | Activa | 50 | 60 s | 20 m | Levanta a distancia a un aliado derribado bajo el cursor. |
| 5 | Meditación | Pasiva | — | — | — | La regeneración de maná sigue al 50 % en combate. |
| 15 | Fe inquebrantable | Pasiva | — | — | — | +10 % de curación recibida. |
| 25 | Gracia | Pasiva | — | — | — | +10 % de curación realizada. |
| 35 | Eco de luz | Pasiva | — | — | — | Tus curaciones dejan un 30 % extra que cura durante 3 s. |

Hasta el Plan 4 todos los personajes son nivel 1: las activas se pueden poner en la barra (ventana K) aunque sean de nivel superior, y las pasivas aún no se activan.

## Notas y cambios
- 

---
← [[00 Índice del GDD|Índice del GDD]] · Clases: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]]
