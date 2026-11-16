---
tags: [gdd, clase]
estado: implementado
actualizado: 2026-11-15
---

# Guerrero

- **Recurso:** Ira
- **Rol base:** Tanque o daño cuerpo a cuerpo
- **Armas:** Espada, hacha, maza, escudo
- **Armadura:** Placas (y todas las inferiores)

Reglas generales en [[04 Personajes y progresión]].

## Kit base y pasivas
| Nivel | Habilidad | Tipo | Efecto |
|---|---|---|---|
| 1 | Tajo (CI) | Activa | Golpe en arco frontal. Genera ira. |
| 1 | Golpe brutal (CD) | Activa | Gasta ira: gran daño a un objetivo. |
| 1 | Carga | Activa | Se lanza hacia el cursor y aturde brevemente. |
| 3 | Grito de guerra | Activa | +daño al grupo cercano unos segundos. |
| 6 | Torbellino | Activa | Daño en área alrededor. |
| 10 | Provocar | Activa | Los enemigos cercanos le atacan unos segundos. |
| 20 | Muro de escudo | Activa | −50 % de daño recibido durante 6 s. |
| 5 | Furia contenida | Pasiva | La ira decae un 50 % más lento. |
| 15 | Piel endurecida | Pasiva | +10 % de armadura. |
| 25 | Bloqueo experto | Pasiva | Los bloqueos generan ira. |
| 35 | Sed de sangre | Pasiva | Los críticos curan un 3 % de la vida. |

## Mejoras de clase del nivel 50
Se elige una de las dos al llegar al nivel 50 (ver [[04 Personajes y progresión|§4.4]]).

| Mejora | Activas | Pasivas | Evoluciona |
|---|---|---|---|
| **Protector** | Provocar en área; Represalia (escudo que devuelve daño) | Postura defensiva (+100 % amenaza, +15 % vida); Último bastión (al bajar del 20 %: −40 % daño 8 s) | Muro de escudo protege también a los aliados cercanos |
| **Berserker** | Frenesí (10 s: más daño y recargas más cortas, pero +15 % de daño recibido); Ejecutar (gran daño por debajo del 25 %; si mata, devuelve la ira) | Furia sangrienta (hasta +25 % de daño según la vida que falta); Masacre (matar reinicia Carga y cura un 5 %) | Tajo golpea dos veces |

## Rangos siguientes (nivel 100+)
_Por diseñar._

## Valores iniciales (0.4.0)
Generados de `data/characters/classes.json` y `data/abilities/warrior.json`; son la propuesta inicial, ajustable tras las pruebas.

- **Estadísticas:** vida 200 · poder de ataque 20 · poder mágico 0 · armadura 40 · crítico 5 % · esquiva 0 %
- **Recurso:** Ira máx. 100, empieza en 0, +8 por golpe, +0,5 por punto de daño recibido, −5/s fuera de combate

| Nivel | Habilidad | Tipo | Coste | Recarga | Alcance | Efecto |
|---|---|---|---|---|---|---|
| 1 | Tajo | Básico (CI) | 0 | 0,6 s | 2,5 m | Golpe en arco frontal. Genera ira. |
| 1 | Golpe brutal | Secundario (CD) | 30 | 4 s | 2,5 m | Gasta ira: un gran golpe al enemigo que tienes delante. |
| 1 | Carga | Activa | 0 | 12 s | 8 m | Te lanzas hacia el cursor y aturdes 1 s a los enemigos donde llegas. |
| 3 | Grito de guerra | Activa | 20 | 18 s | 8 m | Tú y los aliados a 8 m hacéis un 15 % más de daño durante 8 s. |
| 6 | Torbellino | Activa | 25 | 8 s | 3 m | Giras con el arma y golpeas a todos los enemigos a 3 m a tu alrededor. |
| 10 | Provocar | Activa | 15 | 12 s | 6 m | Los enemigos a 6 m solo pueden atacarte a ti durante 4 s. |
| 20 | Muro de escudo | Activa | 20 | 45 s | — | Recibes un 50 % menos de daño durante 6 s. |
| 5 | Furia contenida | Pasiva | — | — | — | La ira decae un 50 % más lento. |
| 15 | Piel endurecida | Pasiva | — | — | — | +10 % de armadura. |
| 25 | Bloqueo experto | Pasiva | — | — | — | Cada golpe que esquivas o que tu escudo absorbe entero te da 10 de ira. |
| 35 | Sed de sangre | Pasiva | — | — | — | Tus críticos te curan un 3 % de la vida máxima. |

Hasta el Plan 4 todos los personajes son nivel 1: las activas se pueden poner en la barra (ventana K) aunque sean de nivel superior, y las pasivas aún no se activan.

## Notas y cambios
- 

---
← [[00 Índice del GDD|Índice del GDD]] · Clases: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]]
