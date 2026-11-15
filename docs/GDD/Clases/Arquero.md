---
tags: [gdd, clase]
estado: implementado
actualizado: 2026-11-15
---

# Arquero

- **Recurso:** Concentración
- **Rol base:** Daño físico a distancia
- **Armas:** Arco, ballesta, carcaj
- **Armadura:** Cuero y malla

Reglas generales en [[04 Personajes y progresión]].

## Kit base y pasivas
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Disparo (CI) | Activa | Flecha a distancia; mantener carga el disparo (más daño y alcance). |
| 1 | Disparo perforante (CD) | Activa | Flecha que atraviesa a los enemigos en línea. |
| 1 | Voltereta | Activa | Salto hacia atrás disparando una flecha. |
| 3 | Red | Activa | Inmoviliza a un enemigo 3 s. |
| 6 | Lluvia de flechas | Activa | Área en el cursor. |
| 10 | Trampa explosiva | Activa | Trampa en el suelo que explota al pisarla. |
| 20 | Marca | Activa | El objetivo marcado recibe +15 % de daño. |
| 5 | Reflejos | Pasiva | +5 % de esquiva. |
| 15 | Ojo de halcón | Pasiva | +15 % de alcance. |
| 25 | Distancia letal | Pasiva | +15 % de daño a objetivos lejanos. |
| 35 | Ráfaga | Pasiva | Cada 5.º disparo básico es crítico. |

## Mejoras de clase del nivel 50
Se elige una de las dos al llegar al nivel 50 (ver [[04 Personajes y progresión|§4.4]]).

| Mejora | Activas | Pasivas | Evoluciona |
|---|---|---|---|
| **Francotirador** | Disparo apuntado (canalizado, gran daño); Ráfaga de 3 flechas | Punto débil (+daño crítico a distancia); Paciencia (+daño estando quieto) | Disparo cargado atraviesa |
| **Montaraz** | Disparo múltiple (abanico de 5); Compañero animal (lobo que ataca y distrae) | Trampero (las trampas se rearman); Superviviente (+10 % vida y velocidad) | Red alcanza a varios enemigos |

## Rangos siguientes (nivel 100+)
_Por diseñar._

## Valores iniciales (0.4.0)
Generados de `data/characters/classes.json` y `data/abilities/archer.json`; son la propuesta inicial, ajustable tras las pruebas.

- **Estadísticas:** vida 150 · poder de ataque 20 · poder mágico 0 · armadura 20 · crítico 5 % · esquiva 5 %
- **Recurso:** Concentración máx. 100, empieza en 100, +12/s, al 30 % al esquivar

| Nivel | Habilidad | Tipo | Coste | Recarga | Alcance | Efecto |
|---|---|---|---|---|---|---|
| 1 | Disparo | Básico (CI) | 0 | 0,6 s | 20 m | Flecha a distancia. Mantén el botón para cargarla: más daño y alcance, a cambio de concentración. |
| 1 | Disparo perforante | Secundario (CD) | 25 | 6 s | 20 m | Flecha que atraviesa a los enemigos en línea. |
| 1 | Voltereta | Activa | 0 | 8 s | 20 m | Saltas hacia atrás disparando una flecha. |
| 3 | Red | Activa | 20 | 14 s | 15 m | Inmoviliza 3 s al enemigo bajo el cursor. |
| 6 | Lluvia de flechas | Activa | 30 | 12 s | 20 m | Tres oleadas de flechas caen en el cursor y dañan a todos a 3 m. |
| 10 | Trampa explosiva | Activa | 25 | 18 s | 10 m | Colocas una trampa en el cursor; se arma en 1 s y explota cuando un enemigo la pisa. |
| 20 | Marca | Activa | 15 | 30 s | 20 m | El enemigo bajo el cursor recibe un 15 % más de daño durante 10 s. |
| 5 | Reflejos | Pasiva | — | — | — | +5 % de esquiva. |
| 15 | Ojo de halcón | Pasiva | — | — | — | +15 % de alcance. |
| 25 | Distancia letal | Pasiva | — | — | — | +15 % de daño a enemigos a 10 m o más. |
| 35 | Ráfaga | Pasiva | — | — | — | Cada 5.º disparo básico es crítico. |

Hasta el Plan 4 todos los personajes son nivel 1: las activas se pueden poner en la barra (ventana K) aunque sean de nivel superior, y las pasivas aún no se activan.

## Notas y cambios
- 

---
← [[00 Índice del GDD|Índice del GDD]] · Clases: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]]
