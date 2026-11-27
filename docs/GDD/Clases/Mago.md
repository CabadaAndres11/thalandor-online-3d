---
tags: [gdd, clase]
estado: implementado
actualizado: 2026-11-15
---

# Mago

- **Recurso:** Maná
- **Rol base:** Daño mágico a distancia y control
- **Armas:** Bastón, orbe
- **Armadura:** Tela

Reglas generales en [[04 Personajes y progresión]].

## Kit base y pasivas
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Proyectil arcano (CI) | Activa | Proyectil mágico rápido. |
| 1 | Explosión arcana (CD) | Activa | Pequeña área en el cursor, con un breve retardo. |
| 1 | Parpadeo | Activa | Teletransporte corto hacia el cursor. |
| 3 | Nova de escarcha | Activa | Congela 2 s a los enemigos cercanos. |
| 6 | Barrera de maná | Activa | Escudo que absorbe daño. |
| 10 | Bola de fuego | Activa | Proyectil que explota en área. |
| 20 | Descarga de escarcha | Activa | Proyectil que ralentiza. |
| 5 | Mente arcana | Pasiva | +10 % de maná máximo. |
| 15 | Concentración | Pasiva | Tras 3 s sin recibir daño: +10 % de daño de hechizos. |
| 25 | Ignición | Pasiva | Los críticos de fuego dejan una quemadura. |
| 35 | Frío penetrante | Pasiva | +20 % de daño a enemigos congelados o ralentizados. |

## Mejoras de clase del nivel 50
Se elige una de las tres al llegar al nivel 50 (ver [[04 Personajes y progresión|§4.4]]). **[Implementado]**, con las escuelas `arcane` (proyectil y explosión arcanos), `fire` (bola de fuego) y `frost` (nova y descarga) en el daño de los hechizos. Números exactos en `data/abilities/mage.json` y `data/upgrades/mage.json`: Pilar de llamas 35 maná/14 s, Meteoro 60/30 s (1,5 s de aviso), Ventisca 45/20 s, Bloque de hielo 20/90 s (4 s, cura el 30 %), Misiles arcanos 40/10 s (canalizado 5 × 0,3 s), Lanza arcana 50/16 s (18 m × 1,2 m).

| Mejora | Activas | Pasivas | Evoluciona |
|---|---|---|---|
| **Piromante** | Columna de llamas (suelo ardiendo); Meteoro | Combustión (+10 % daño a enemigos ardiendo); Fénix (renace con 30 % de vida) | Bola de fuego deja el suelo ardiendo |
| **Criomante** | Ventisca; Bloque de hielo | Escalofrío (los ralentizados atacan más lento); Corazón helado (congelar reduce recargas) | Nova de escarcha se lanza en el cursor |
| **Arcano** | Misiles arcanos (canalizado, ráfaga de 5 proyectiles); Láser arcano (rayo de 4 s que sigue al cursor y atraviesa; 60 maná, 20 s) | Carga arcana (+4 % de daño por hechizo arcano, hasta 5 cargas; se pierden a los 6 s); Poder puro (+15 % de crítico con hechizos arcanos) | Explosión arcana estalla sin retardo y con más área |

## Rangos siguientes (nivel 100+)
_Por diseñar._

## Valores iniciales (0.4.0)
Generados de `data/characters/classes.json` y `data/abilities/mage.json`; son la propuesta inicial, ajustable tras las pruebas.

- **Estadísticas:** vida 130 · poder de ataque 5 · poder mágico 20 · armadura 10 · crítico 5 % · esquiva 0 %
- **Recurso:** Maná máx. 160, empieza en 160, +6/s, no se regenera en combate

| Nivel | Habilidad | Tipo | Coste | Recarga | Alcance | Efecto |
|---|---|---|---|---|---|---|
| 1 | Proyectil arcano | Básico (CI) | 0 | 0,7 s | 22 m | Proyectil mágico rápido. |
| 1 | Explosión arcana | Secundario (CD) | 25 | 5 s | 20 m | Área pequeña en el cursor, con un breve retardo. |
| 1 | Parpadeo | Activa | 15 | 10 s | 8 m | Teletransporte corto hacia el cursor. |
| 3 | Nova de escarcha | Activa | 40 | 15 s | 4 m | Congela 2 s a los enemigos a 4 m a tu alrededor. |
| 6 | Barrera de maná | Activa | 40 | 20 s | — | Un escudo que absorbe daño durante 8 s. |
| 10 | Bola de fuego | Activa | 45 | 10 s | 22 m | Un proyectil de fuego que explota al impactar y daña a todos a 2,5 m. |
| 20 | Descarga de escarcha | Activa | 40 | 25 s | 22 m | Un proyectil de hielo que ralentiza al enemigo un 50 % durante 4 s. |
| 5 | Mente arcana | Pasiva | — | — | — | +10 % de maná máximo. |
| 15 | Concentración | Pasiva | — | — | — | Tras 3 s sin recibir daño, tus hechizos hacen un 10 % más de daño. |
| 25 | Ignición | Pasiva | — | — | — | Tus críticos de fuego dejan una quemadura. |
| 35 | Frío penetrante | Pasiva | — | — | — | +20 % de daño a enemigos congelados o ralentizados. |

Hasta el Plan 4 todos los personajes son nivel 1: las activas se pueden poner en la barra (ventana K) aunque sean de nivel superior, y las pasivas aún no se activan.

## Notas y cambios
- **[Implementado 0.17.1]** Al elegir mejora, el kit base pasa a su elemento (Saeta de fuego, Esquirla de hielo, Nova ígnea…): variantes como datos (`upgrade` + `replaces` en `data/abilities/mage.json`); el hueco de la barra conserva la habilidad base y lanza la variante. Frío penetrante cuenta enemigos ardiendo (Piromante) o inmovilizados (Arcano) ([[D-021 Kit elemental del mago y Detonar toxinas del Venenero|D-021]]).

---
← [[00 Índice del GDD|Índice del GDD]] · Clases: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]]
