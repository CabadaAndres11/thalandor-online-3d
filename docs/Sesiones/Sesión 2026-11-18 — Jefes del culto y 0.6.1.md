---
tags: [sesion]
fecha: 2026-11-18
tipo: desarrollo
---
# Sesión 2026-11-18 — Jefes del culto y 0.6.1

## Objetivo
Crear los enemigos de la historia a partir de las hojas de referencia del usuario y publicar el Plan 4.

## Qué se hizo
- **Acólito Cultista:** sustituye a la bestia de guardia como jefe genérico del culto (mismas reglas).
- **Vaelthar, Primer Apóstol** (primer Sacerdote demonio): levita, melena gris ceniza, tentáculos que salen de mangas cortadas al codo; seis ataques en tres fases.
- **Nhazar, Obispo de las Mil Voces** (segundo Sacerdote demonio): cuerpo pequeño bajo una masa enorme con 34 máscaras expresivas; set de nueve ataques centrado en estados.
- **Cultista Inquisidor:** élite de las bandas de cultistas con espada ceremonial y un ataque cuerpo a cuerpo.
- Técnica: ataques especiales por fase en los datos de los jefes (`specials`, `phase_abilities`), `hover`, `hide_parts`, `bar_height` y agarre `blade_down` en los humanoides, `pack_group` y el estado *Armadura rota*.
- Publicada la **0.6.1**; corregidas las notas de la 0.6.0.

## Qué se probó
- Tests GUT: 1037 en verde.
- El usuario probó el Plan 4 y aprobó los modelos de Vaelthar y Nhazar tras dos rondas de cambios.

## Problemas encontrados
- Las notas de la 0.6.0 se publicaron con el texto de la 0.5.0.
- En las cabezas con capucha la sombra ocultaba la cara: se pinta el rostro como pieza.

## Siguiente paso
- Probar los sets de Vaelthar, Nhazar y el Inquisidor en partida.
- Plan 5 · Objetos.

---
← [[Sesiones]]
