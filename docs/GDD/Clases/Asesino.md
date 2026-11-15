---
tags: [gdd, clase]
estado: implementado
actualizado: 2026-11-15
---

# Asesino

- **Recurso:** Energía
- **Rol base:** Daño cuerpo a cuerpo con sigilo
- **Armas:** Dagas (dos), espada corta
- **Armadura:** Cuero

Reglas generales en [[04 Personajes y progresión]].

## Kit base y pasivas
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Cuchillada (CI) | Activa | Golpe con dagas que genera 1 punto de combo. |
| 1 | Eviscerar (CD) | Activa | Remate que gasta los puntos de combo; el daño escala con los puntos. |
| 1 | Paso sombrío | Activa | Se teletransporta a la espalda del objetivo. |
| 3 | Sigilo | Activa | Fuera de combate entra en sigilo; en combate, desaparece y sale del combate (recarga larga). |
| 6 | Abanico de cuchillas | Activa | Daño en área alrededor y 1 punto de combo por enemigo. |
| 10 | Veneno | Activa | Durante 30 s, los golpes aplican un veneno acumulable (hasta 5). |
| 20 | Evasión | Activa | +50 % de esquiva durante 5 s. |
| 5 | Golpe por la espalda | Pasiva | +20 % de daño por la espalda. |
| 15 | Emboscada | Pasiva | El primer golpe desde sigilo es crítico y hace +50 % de daño. |
| 25 | Evasión mortal | Pasiva | Tras esquivar, el siguiente golpe genera 2 puntos de combo. |
| 35 | Oportunista | Pasiva | +10 % de daño a objetivos aturdidos o inmovilizados. |

## Mejoras de clase del nivel 50
Se elige una de las dos al llegar al nivel 50 (ver [[04 Personajes y progresión|§4.4]]).

| Mejora | Activas | Pasivas | Evoluciona |
|---|---|---|---|
| **Sombra** | Desvanecer mejorado; Golpe sombrío (teletransporte + golpe crítico) | Asesino nato (+daño a objetivos por debajo del 30 %); Velo (+tiempo de sigilo) | Eviscerar devuelve energía por punto de combo |
| **Venenero** | Nube tóxica (área persistente); Contagio (el veneno salta a enemigos cercanos al morir) | Toxicología (el veneno se acumula hasta 10); Sangre corrupta (los envenenados hacen −10 % daño) | Cuchillada aplica veneno siempre |

## Rangos siguientes (nivel 100+)
_Por diseñar._

## Valores iniciales (0.4.0)
Generados de `data/characters/classes.json` y `data/abilities/assassin.json`; son la propuesta inicial, ajustable tras las pruebas.

- **Estadísticas:** vida 160 · poder de ataque 20 · poder mágico 0 · armadura 20 · crítico 5 % · esquiva 5 %
- **Recurso:** Energía máx. 100, empieza en 100, +12/s

| Nivel | Habilidad | Tipo | Coste | Recarga | Alcance | Efecto |
|---|---|---|---|---|---|---|
| 1 | Cuchillada | Básico (CI) | 0 | 0,5 s | 2 m | Golpe con dagas que genera 1 punto de combo. |
| 1 | Eviscerar | Secundario (CD) | 35 | 1 s | 2 m | Remate que gasta los puntos de combo; cuantos más, más daño. |
| 1 | Paso sombrío | Activa | 20 | 12 s | 12 m | Te teletransportas a la espalda del enemigo bajo el cursor. |
| 3 | Sigilo | Activa | 20 | 8 s (45 s en combate) | — | Fuera de combate, entras en sigilo. En combate, desapareces y sales del combate (recarga larga). |
| 6 | Abanico de cuchillas | Activa | 30 | 8 s | 3 m | Dañas a los enemigos a 3 m y ganas 1 punto de combo por cada uno. |
| 10 | Veneno | Activa | 25 | 20 s | — | Durante 30 s, tus golpes envenenan; el veneno se acumula hasta 5 veces. |
| 20 | Evasión | Activa | 20 | 40 s | — | +50 % de esquiva durante 5 s. |
| 5 | Golpe por la espalda | Pasiva | — | — | — | +20 % de daño por la espalda. |
| 15 | Emboscada | Pasiva | — | — | — | El primer ataque desde sigilo es crítico y hace un 50 % más de daño. |
| 25 | Evasión mortal | Pasiva | — | — | — | Tras esquivar, el siguiente golpe da 2 puntos de combo. |
| 35 | Oportunista | Pasiva | — | — | — | +10 % de daño a enemigos aturdidos o inmovilizados. |

Hasta el Plan 4 todos los personajes son nivel 1: las activas se pueden poner en la barra (ventana K) aunque sean de nivel superior, y las pasivas aún no se activan.

## Notas y cambios
- 

---
← [[00 Índice del GDD|Índice del GDD]] · Clases: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]]
