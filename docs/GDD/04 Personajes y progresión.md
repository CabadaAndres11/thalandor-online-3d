---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-15
---

# 4. Personajes y clases

## 4.0 Creación y elección de clase **[Implementado]** (0.5.0, [[D-011 La clase se elige dentro de la partida]])
- **Crear personaje:** solo nombre y aspecto. Todo personaje nace **aldeano**:
  - 120 de vida y sin recurso de clase;
  - un golpe con espada de madera como ataque básico;
  - sin secundario ni habilidades en la barra; la esquiva funciona igual.
- **Elegir clase:** se habla con **Brann**, el herrero de la aldea, que es un PNJ definido en `data/npcs/brann.json` y colocado por el mapa.
  - Con **E** a 2,5 m o menos se abre la ventana *Elige tu camino*: las 5 clases con nombre, recurso, descripción y vista previa del personaje.
  - La elección es **definitiva** (el cambio de clase de §4.9 llegará más adelante).
  - El anfitrión comprueba que el jugador es un aldeano vivo junto a Brann.
  - Con un aliado derribado al alcance, E levanta al aliado en lugar de hablar.
  - Si ya tienes clase, Brann dice una frase.
- En el guion es «La práctica» de la misión 1, en [[Anexo B — Historia]]. Los textos de Brann y de la ventana son **provisionales** hasta que el guion los fije.

## 4.1 Recursos **[Implementado]** (Plan 3, 0.3.0–0.4.0; los valores están en `data/characters/classes.json`)
- **Vida:** todas las clases.
- **Recurso de clase:**
  - **Ira** (Guerrero): se genera golpeando y recibiendo daño; decae fuera de combate.
  - **Maná** (Clérigo, Mago): se consume al lanzar y se regenera con Espíritu (al 50 % en combate solo con la pasiva adecuada).
  - **Concentración** (Arquero): se regenera rápido estando quieto o caminando, más despacio al esquivar; los disparos cargados la consumen.
  - **Energía** (Asesino): se regenera rápido a ritmo fijo.

## 4.2 Las 5 clases iniciales **[Implementado]** (0.4.0: kit completo de cada clase; valores iniciales en la nota de cada clase)
Cada clase tiene su nota con kit, pasivas y mejoras: [[Guerrero]] · [[Clérigo]] · [[Mago]] · [[Arquero]] · [[Asesino]].
| Clase | Recurso | Rol base | Arma | Armadura |
|---|---|---|---|---|
| **Guerrero** | Ira | Tanque o daño cuerpo a cuerpo | Mandoble, gran hacha, martillo de guerra, alabarda, espada, hacha, maza, escudo | Su juego (placas) |
| **Clérigo** | Maná | Sanador o daño sagrado | Martillo de guerra, bastón, maza, varita, cetro, escudo, orbe, tomo | Su juego (tela) |
| **Mago** | Maná | Daño mágico a distancia y control | Bastón, varita, orbe, tomo | Su juego (tela, túnica larga) |
| **Arquero** | Concentración | Daño físico a distancia | Arco, ballesta, espada corta (carcaj de adorno) | Su juego (malla) |
| **Asesino** | Energía | Daño cuerpo a cuerpo con sigilo | Dagas (dos), espada corta | Su juego (cuero) |

Desde la 0.7.0 la armadura va **por clase**: cada clase lleva solo su propio juego ([[D-014 Objetos por clase, armas a dos manos y tramos épicos]]).

**Supervivencia en solitario:**
- **Guerrero:** escudo, bloqueo y robo de vida.
- **Clérigo:** se cura a sí mismo.
- **Mago:** mantiene la distancia, congela y teletransporta.
- **Arquero:** mantiene la distancia, ralentiza y esquiva.
- **Asesino:** evasión alta y vuelta al sigilo para salir del combate.

**Mecánicas propias:**
- **Arquero:** disparos **cargados** (mantener el botón aumenta daño y alcance), **trampas** colocadas en el suelo y **marca** sobre un objetivo.
- **Asesino:** **sigilo** (los monstruos no lo detectan; se rompe al atacar o recibir daño; el primer golpe saliendo de sigilo es crítico), **puntos de combo** (0–5) que se gastan en remates, y **venenos** acumulables.

## 4.3 Habilidades **[Implementado]** (0.4.0: 7 habilidades usables y 4 pasivas por clase como datos, ventana K y barra guardada con el personaje. Desde la 0.6.0 se desbloquean por nivel)
- **Kit base por clase:** ataque básico (clic izquierdo), ataque secundario (clic derecho) y habilidades que se desbloquean por nivel (niveles 1, 3, 6, 10, 15, 20, 30 y 40).
- **Pasivas de clase:** niveles 5, 15, 25 y 35.
- **Barra:** 4 ranuras asignables (1–4); hay más habilidades que ranuras y el jugador elige cuáles lleva (ventana K).
- **Esquiva común** para todas las clases (Espacio).
- **Definición:** el listado concreto está en el **anexo A** y en `data/abilities/`. Es una propuesta inicial, ajustable tras las pruebas.

## 4.4 Mejoras de clase cada 50 niveles **[Implementado]** (0.6.0, [[D-013 Mejoras del nivel 50 revisadas]]) (sustituyen a las especializaciones del prototipo)
- **Cada 50 niveles** (50, 100, 150…) se alcanza un **rango de clase** y se elige **una mejora entre 2 o 3** (el Mago tiene 3).
- **Cada mejora aporta:** 2 habilidades activas nuevas, 2 pasivas y la **evolución de una habilidad base** (por ejemplo, el Tajo del Guerrero pasa a golpear dos veces).
- **Las mejoras se acumulan:** al nivel 100 se elige otra mejora de un segundo rango, cuyas opciones dependen de la elegida al 50 (árbol de evolución de la clase).
- **Cambiar de mejora:** posible en la capital (instructor de clase) pagando oro, fuera de combate.
- **Primer rango (nivel 50):** definido en el **anexo A**. Los rangos siguientes se diseñarán a medida que haya contenido para esos niveles.

| Clase | Mejora A (nivel 50) | Mejora B (nivel 50) | Mejora C (nivel 50) |
|---|---|---|---|
| Guerrero | **Protector** (tanque: provocar en área, muro de escudo, represalia) | **Berserker** (daño: frenesí, ejecutar, más daño cuanta menos vida) | — |
| Clérigo | **Sanador** (círculo de sanación, plegaria de vida, himno) | **Templario** (combate cuerpo a cuerpo: golpe de cruzado, consagración, armadura de fe) | — |
| Mago | **Piromante** (bola de fuego, columna de llamas, meteoro) | **Criomante** (descarga de escarcha, ventisca, bloque de hielo) | **Arcano** (daño puro sin elemento: misiles arcanos, lanza arcana) |
| Arquero | **Francotirador** (disparo apuntado, ráfaga, marca del cazador) | **Cazador** (ballesta: disparo múltiple, trampas mejoradas, compañero animal) | — |
| Asesino | **Sombra** (eviscerar mejorado, desvanecer, emboscada) | **Venenero** (venenos letales, nube tóxica, contagio) | — |

El detalle de cada mejora está en la nota de su clase y en [[Plan 4 — Progresión (spec)]].

## 4.5 Atributos **[Implementado]** (0.6.0)
Cada nivel sube **+5 a cada uno de los cinco atributos** automáticamente y otorga además **5 puntos libres** para repartir. Los atributos principales de cada clase se muestran en dorado en la ventana C como recomendados.

| Atributo | Efecto |
|---|---|
| **Fuerza** | Poder de ataque cuerpo a cuerpo, probabilidad de bloqueo (0,2 % por punto; un bloqueo reduce a la mitad el daño físico cuerpo a cuerpo) |
| **Agilidad** | Probabilidad de crítico, esquiva, poder de ataque a distancia |
| **Intelecto** | Poder de hechizos, maná máximo |
| **Aguante** | Vida máxima |
| **Espíritu** | Regeneración de vida y maná (además, fuera de combate todos recuperan el 2 % de su vida máxima por segundo) |

**Sin nivel máximo:** para que los números no se disparen, las conversiones de atributo a estadística tienen **rendimientos decrecientes** a partir de ciertos umbrales (definidos en `data/balance.json`), y la probabilidad de crítico, esquiva y bloqueo tiene topes.

## 4.6 Árbol de talentos **[Implementado]** (0.6.0) (diseño probado en el prototipo 2D)
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

## 4.7 Cálculo de estadísticas **[Implementado]** (0.6.0)
```
final = (base de clase + atributos + suma de bonos planos) × (1 + suma de bonos %)
```
- **Bonos planos:** equipo y talentos. **Bonos porcentuales:** equipo, talentos, pasivas y mejoras de clase.
- Los porcentajes de una misma estadística se **suman** antes de multiplicar.
- **Estadísticas secundarias:** daño crítico (se suma al ×1,5), reducción de recargas (tope del 40 %), robo de vida, bloqueo y multiplicador de amenaza.
- **Daño:** `(base + coeficiente × poder) × variación ±10 % × multiplicadores`; armadura con mitigación `armadura / (armadura + K)` y tope del 75 %, donde K crece con el nivel del atacante para que la armadura no pierda valor.
- **Datos:** todas las constantes viven en `data/balance.json`.

## 4.8 Progresión sin nivel máximo **[Implementado]** (0.6.0)
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

## 4.10 Creación y apariencia del personaje **[Implementado]** (Plan 2, versión 0.2.0)
- Hasta **8 personajes** por jugador.
- Se eligen **nombre, clase y apariencia**.
- **Apariencia vóxel:** tipo de cuerpo, tono de piel, peinado, color de pelo y color de ojos; los modelos se arman por piezas (cabeza, torso, brazos, piernas).
- **Ropa inicial:** la decide la clase. Después cambia con el equipo ([[08 Botín y economía|§8]]).
- **Nombres:** de 2 a 16 caracteres (letras con tildes, números, espacios, `-` y `'`), sin repetir entre los personajes del mismo jugador.
- **Implementado (0.2.0):** modelo base de **Kenney Blocky Characters** (CC0, 27 vóxeles de alto, animado por piezas rígidas). Apariencia con **2 cuerpos** (esbelto y robusto, por proporciones), **8 tonos de piel**, **7 colores de ojos** (incluido rojo), **8 peinados** (corto, media melena, flequillo, calvo, y melena, coleta, moño y cresta en vóxel), **11 colores de pelo** (incluido rojo intenso) y **5 barbas**. La ropa inicial de cada clase es una capa de textura más piezas vóxel: hombreras del Guerrero, capucha baja del Clérigo, sombrero del Mago, capucha del Arquero y pañuelo del Asesino. Opciones en `data/characters/`.

---
← [[00 Índice del GDD|Índice del GDD]]
