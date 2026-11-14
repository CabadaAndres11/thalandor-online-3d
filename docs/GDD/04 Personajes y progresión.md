---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-14
---

# 4. Personajes y clases

## 4.1 Recursos **[Diseñado]**
- **Vida:** todas las clases.
- **Recurso de clase:**
  - **Ira** (Guerrero): se genera golpeando y recibiendo daño; decae fuera de combate.
  - **Maná** (Clérigo, Mago): se consume al lanzar y se regenera con Espíritu (al 50 % en combate solo con la pasiva adecuada).
  - **Concentración** (Arquero): se regenera rápido estando quieto o caminando, más despacio al esquivar; los disparos cargados la consumen.
  - **Energía** (Asesino): se regenera rápido a ritmo fijo.

## 4.2 Las 5 clases iniciales **[Diseñado]**
Cada clase tiene su nota con kit, pasivas y mejoras: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]].
| Clase | Recurso | Rol base | Arma | Armadura |
|---|---|---|---|---|
| **Guerrero** | Ira | Tanque o daño cuerpo a cuerpo | Espada, hacha, maza, escudo | Placas (y todas las inferiores) |
| **Clérigo** | Maná | Sanador o daño sagrado | Maza, bastón, escudo, orbe | Tela |
| **Mago** | Maná | Daño mágico a distancia y control | Bastón, orbe | Tela |
| **Arquero** | Concentración | Daño físico a distancia | Arco, ballesta, carcaj | Cuero y malla |
| **Asesino** | Energía | Daño cuerpo a cuerpo con sigilo | Dagas (dos), espada corta | Cuero |

Orden de armaduras, de más ligera a más pesada: tela < cuero < malla < placas. Cada clase puede llevar su tipo y los inferiores.

**Supervivencia en solitario:**
- **Guerrero:** escudo, bloqueo y robo de vida.
- **Clérigo:** se cura a sí mismo.
- **Mago:** mantiene la distancia, congela y teletransporta.
- **Arquero:** mantiene la distancia, ralentiza y esquiva.
- **Asesino:** evasión alta y vuelta al sigilo para salir del combate.

**Mecánicas propias:**
- **Arquero:** disparos **cargados** (mantener el botón aumenta daño y alcance), **trampas** colocadas en el suelo y **marca** sobre un objetivo.
- **Asesino:** **sigilo** (los monstruos no lo detectan; se rompe al atacar o recibir daño; el primer golpe saliendo de sigilo es crítico), **puntos de combo** (0–5) que se gastan en remates, y **venenos** acumulables.

## 4.3 Habilidades **[Diseñado]**
- **Kit base por clase:** ataque básico (clic izquierdo), ataque secundario (clic derecho) y habilidades que se desbloquean por nivel (niveles 1, 3, 6, 10, 15, 20, 30 y 40).
- **Pasivas de clase:** niveles 5, 15, 25 y 35.
- **Barra:** 4 ranuras asignables (1–4); hay más habilidades que ranuras y el jugador elige cuáles lleva (ventana K).
- **Esquiva común** para todas las clases (Espacio).
- **Definición:** el listado concreto está en el **anexo A** y en `data/abilities/`. Es una propuesta inicial, ajustable tras las pruebas.

## 4.4 Mejoras de clase cada 50 niveles **[Diseñado]** (sustituyen a las especializaciones del prototipo)
- **Cada 50 niveles** (50, 100, 150…) se alcanza un **rango de clase** y se elige **una de 2 mejoras**.
- **Cada mejora aporta:** 2 habilidades activas nuevas, 2 pasivas y la **evolución de una habilidad base** (por ejemplo, el Tajo del Guerrero pasa a golpear dos veces).
- **Las mejoras se acumulan:** al nivel 100 se elige otra mejora de un segundo rango, cuyas opciones dependen de la elegida al 50 (árbol de evolución de la clase).
- **Cambiar de mejora:** posible en la capital (instructor de clase) pagando oro, fuera de combate.
- **Primer rango (nivel 50):** definido en el **anexo A**. Los rangos siguientes se diseñarán a medida que haya contenido para esos niveles.

| Clase | Mejora A (nivel 50) | Mejora B (nivel 50) |
|---|---|---|
| Guerrero | **Protector** (tanque: provocar en área, muro de escudo, represalia) | **Campeón** (daño: golpe mortal, ejecutar, temeridad) |
| Clérigo | **Sanador** (círculo de sanación, plegaria de vida, himno) | **Castigador** (fuego sagrado, juicio, lanza de luz) |
| Mago | **Piromante** (bola de fuego, columna de llamas, meteoro) | **Criomante** (descarga de escarcha, ventisca, bloque de hielo) |
| Arquero | **Francotirador** (disparo apuntado, ráfaga, marca del cazador) | **Montaraz** (disparo múltiple, trampas mejoradas, compañero animal) |
| Asesino | **Sombra** (eviscerar mejorado, desvanecer, emboscada) | **Venenero** (venenos letales, nube tóxica, contagio) |

## 4.5 Atributos **[Diseñado]**
Cada nivel otorga **5 puntos de atributo** para repartir libremente, y cada clase sube además 2 atributos principales por nivel.

| Atributo | Efecto |
|---|---|
| **Fuerza** | Poder de ataque cuerpo a cuerpo, probabilidad de bloqueo (0,2 % por punto; un bloqueo reduce a la mitad el daño físico cuerpo a cuerpo) |
| **Agilidad** | Probabilidad de crítico, esquiva, poder de ataque a distancia |
| **Intelecto** | Poder de hechizos, maná máximo |
| **Aguante** | Vida máxima |
| **Espíritu** | Regeneración de vida y maná |

**Sin nivel máximo:** para que los números no se disparen, las conversiones de atributo a estadística tienen **rendimientos decrecientes** a partir de ciertos umbrales (definidos en `data/balance.json`), y la probabilidad de crítico, esquiva y bloqueo tiene topes.

## 4.6 Árbol de talentos **[Diseñado]** (diseño probado en el prototipo 2D)
- **Puntos:** 1 por nivel a partir del 2.
- **Árbol común a todas las clases.** Los nodos solo dan estadísticas: no modifican habilidades.
- **Estructura circular:** se empieza en el centro y se avanza en cualquier dirección comprando nodos conectados a los que ya tienes (1 punto por nodo). Cada dirección está orientada a unas estadísticas.
  - **5 direcciones** en orden circular: Poderío (daño físico), Celeridad (velocidad y recargas), Vitalidad (sostenimiento), Bastión (defensa) y Arcano (daño mágico).
  - **Radios híbridos** entre direcciones vecinas que mezclan las dos.
  - **Notables** (valen el doble) y **culminantes** al final de cada dirección.
- **Crece con el personaje:** cada rango de clase (nivel 50, 100…) desbloquea un **anillo exterior** nuevo con más nodos y culminantes más potentes.
- **Puntos sobrantes (maestría):** cuando un jugador ha comprado todo lo disponible, los puntos nuevos van a **maestrías**: bonos pequeños e ilimitados (por ejemplo +0,1 % de vida por rango) con rendimiento decreciente.
- **Reinicio:** completo, cuesta oro y se hace con el instructor de la capital, fuera de combate.
- **Nodos:** ver [[Anexo C — Árbol de talentos]] (círculo inicial de 46 nodos).

## 4.7 Cálculo de estadísticas **[Diseñado]**
```
final = (base de clase + atributos + suma de bonos planos) × (1 + suma de bonos %)
```
- **Bonos planos:** equipo y talentos. **Bonos porcentuales:** equipo, talentos, pasivas y mejoras de clase.
- Los porcentajes de una misma estadística se **suman** antes de multiplicar.
- **Estadísticas secundarias:** daño crítico (se suma al ×1,5), reducción de recargas (tope del 40 %), robo de vida, bloqueo y multiplicador de amenaza.
- **Daño:** `(base + coeficiente × poder) × variación ±10 % × multiplicadores`; armadura con mitigación `armadura / (armadura + K)` y tope del 75 %, donde K crece con el nivel del atacante para que la armadura no pierda valor.
- **Datos:** todas las constantes viven en `data/balance.json`.

## 4.8 Progresión sin nivel máximo **[Diseñado]**
- **No hay nivel máximo.** La demo tiene contenido hasta el nivel 60.
- **Curva de experiencia:** `xpParaSubir(L) = round(100 × L^1,6)` hasta el nivel 50; a partir de ahí crece de forma **lineal** para que cada nivel cueste parecido (el valor exacto se ajusta en `data/balance.json` tras las pruebas). Objetivo orientativo: nivel 50 en unas 20–25 h de juego.
- **Experiencia por monstruo:** `8 × nivel^1,2`, ×4 si es élite. Baja si el monstruo está más de 2 niveles por debajo (mínimo 10 %).
- **Reparto en grupo:** entre los jugadores cercanos, con un bonus de `1 + 0,1 × (miembros − 1)`.
- **Al subir de nivel:** vida y recurso al máximo, efecto visual y aviso en el chat para todos.
- **Cada 50 niveles:** rango de clase (mejora a elegir, [[04 Personajes y progresión|§4.4]]) y anillo nuevo del árbol de talentos ([[04 Personajes y progresión|§4.6]]).
- **Muerte:** no hace perder experiencia.

## 4.9 Cambio de clase **[Diseñado; requisitos [Abierto]]**
- **Qué es:** un personaje puede cambiar a otra de las 5 clases cuando cumple ciertos requisitos.
- **Propuesta de requisitos** (a confirmar con el equipo):
  - Haber alcanzado el **primer rango de clase** (nivel 50) con la clase actual.
  - Completar una **misión de prueba** en la capital propia de la clase destino.
  - Pagar una cantidad de oro.
- **Qué se conserva y qué no** (propuesta):
  - Se conservan el **nivel**, la experiencia, el oro, el inventario, las misiones y el árbol de talentos (es común a todas las clases).
  - Cada clase lleva su **progreso propio de mejoras de clase**: si vuelves a una clase que ya tuviste, recuperas sus mejoras.
  - El equipo que la nueva clase no puede usar se queda en el inventario.
  - Los atributos repartidos se reinician gratis para recolocarlos.
- **Fuera de la demo:** se implementa después de tener contenido por encima del nivel 50.

## 4.10 Creación y apariencia del personaje **[Diseñado]**
- Hasta **8 personajes** por jugador.
- Se eligen **nombre, clase y apariencia**.
- **Apariencia vóxel:** tipo de cuerpo, tono de piel, peinado, color de pelo y color de ojos; los modelos se arman por piezas (cabeza, torso, brazos, piernas).
- **Ropa inicial:** la decide la clase. Después cambia con el equipo ([[08 Botín y economía|§8]]).
- **Nombres:** de 2 a 16 caracteres (letras con tildes, números, espacios, `-` y `'`), sin repetir entre los personajes del mismo jugador.

---
← [[00 Índice del GDD|Índice del GDD]]
