---
tags: [gdd]
estado: diseñado
actualizado: 2026-11-27
---

# 4. Personajes y clases

## Cuerpo: hombre o mujer (0.16.0, Plan 8.3e) **[Implementado]**
- El cuerpo es **Hombre** o **Mujer** (antes *Esbelto* y *Robusto*; los guardados pasan solos: esbelto → mujer, robusto → hombre).
- La mujer tiene cabeza propia en humanos, elfos y enanos (los ogros y lagartos conservan la de su raza), hombros, torso y brazos más finos y su pecho (pieza `bust_female`), que se oculta bajo cualquier armadura de pecho.

## 4.0 Creación y elección de clase **[Implementado]** (0.5.0, [[D-011 La clase se elige dentro de la partida]]; desde la 0.13.0 en el asalto, [[D-019 Prólogo como tutorial y clase en el asalto]])
- **Desde la 0.13.0** la clase se elige en el prólogo, al despertar el poder durante el asalto: el paso de misión con el objetivo `class` deja elegir en cualquier sitio y la ventana sale sola, sin poder cerrarla. Brann ya no enseña clases. Desde la 0.14.0 los reinicios los hace **maese Corwin** en la capital: atributos o talentos por **20 de oro × nivel** cada uno (Plan 8.3b). Lo que sigue en esta sección describe la 0.5.0.
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
  - **Maná** (Clérigo, Mago): se consume al lanzar y se regenera con Espíritu; en combate, al 50 % (al 100 % con *Meditación* del clérigo).
  - **Concentración** (Arquero): se regenera rápido estando quieto o caminando, más despacio al esquivar. Los ataques básicos no la gastan, tampoco cargados.
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
- **Variantes del kit base** (0.17.1, [[D-021 Kit elemental del mago y Detonar toxinas del Venenero|D-021]]): una mejora puede sustituir habilidades base por variantes propias (`upgrade` + `replaces` en los datos). El hueco de la barra no cambia y lanza la variante; al reiniciar la mejora vuelve la base. Lo usa el mago para pasar su kit a su elemento.
- **Las mejoras se acumulan:** al nivel 100 se elige otra mejora de un segundo rango, cuyas opciones dependen de la elegida al 50 (árbol de evolución de la clase).
- **Cambiar de mejora:** posible en la capital (instructor de clase) pagando oro, fuera de combate. Hasta entonces (0.13.0) la mejora del nivel 50 es **definitiva**.
- **Primer rango (nivel 50):** definido en el **anexo A**. Los rangos siguientes se diseñarán a medida que haya contenido para esos niveles.

| Clase | Mejora A (nivel 50) | Mejora B (nivel 50) | Mejora C (nivel 50) |
|---|---|---|---|
| Guerrero | **Protector** (tanque: provocar en área, muro de escudo, represalia) | **Berserker** (daño: frenesí, ejecutar, más daño cuanta menos vida) | — |
| Clérigo | **Sanador** (círculo de sanación, plegaria de vida, himno) | **Templario** (combate cuerpo a cuerpo: golpe de cruzado, consagración, armadura de fe) | — |
| Mago | **Piromante** (bola de fuego, columna de llamas, meteoro) | **Criomante** (descarga de escarcha, ventisca, bloque de hielo) | **Arcano** (daño puro sin elemento: misiles arcanos, lanza arcana) |
| Arquero | **Francotirador** (disparo apuntado, ráfaga, marca del cazador) | **Cazador** (ballesta: disparo múltiple, trampas mejoradas, compañero animal) | — |
| Asesino | **Sombra** (eviscerar mejorado, desvanecer, emboscada) | **Venenero** (venenos letales, nube tóxica, contagio) | — |

El detalle de cada mejora está en la nota de su clase y en Plan 4 — Progresión (spec).

## 4.5 Atributos **[Implementado]** (0.6.0)
Cada nivel sube **+2 a cada uno de los cinco atributos** automáticamente y otorga además **5 puntos libres** para repartir. Los atributos principales de cada clase se muestran en dorado en la ventana C como recomendados.

| Atributo | Efecto |
|---|---|
| **Fuerza** | Poder de ataque cuerpo a cuerpo, probabilidad de bloqueo (0,2 % por punto; un bloqueo reduce a la mitad el daño físico cuerpo a cuerpo) |
| **Agilidad** | Probabilidad de crítico, esquiva, velocidad de movimiento (+0,05 % por punto, hasta +30 %), poder de ataque a distancia |
| **Intelecto** | Poder de hechizos, maná máximo |
| **Aguante** | Vida máxima |
| **Espíritu** | Regeneración de vida y maná (además, fuera de combate todos recuperan el 2 % de su vida máxima por segundo) |

**Sin nivel máximo:** para que los números no se disparen, cada punto de atributo da siempre lo mismo y se nota (1 fuerza = +1 de ataque, 1 aguante = +10 de vida…, en `data/balance.json`); lo que está acotado son la probabilidad de crítico, esquiva y bloqueo y la velocidad extra.

## 4.6 Árbol de talentos **[Implementado]** (Plan 8.3g, rehecho en anillos)
- **Puntos:** 1 por nivel a partir del 2.
- **Árbol común a todas las clases.** Los nodos solo dan estadísticas: no modifican habilidades.
- **Siete anillos cerrados** alrededor de un centro común (281 nodos con el centro). Cada anillo se une al siguiente por muchos puntos; se compra cualquier nodo conectado al centro o a uno ya comprado. **Todo está disponible desde el principio**: ni el nivel ni la mejora de clase bloquean anillos.
- **5 direcciones** en sectores: Poderío (daño físico), Celeridad (velocidad y recargas), Vitalidad (sostenimiento), Bastión (defensa y amenaza) y Arcano (daño mágico). En las fronteras los nodos **mezclan** las estadísticas de las dos direcciones.
- **Tipos:** nodo (1 estadística, 2 en las fronteras), **notable** (2–3) y **culminante** (2 grandes, en los anillos 4 y 7 de cada dirección). Los valores crecen hacia fuera (×1 en el anillo 1, ×2 en el 7). El árbol entero se completa hacia el nivel 280.
- **Ruta recomendada por clase:** 100 nodos marcados en dorado y numerados en la ventana; se puede ocultar. Es solo una guía.
- **Maestrías:** cuando todos los nodos de una dirección están comprados, cada punto extra mejora su maestría (rendimiento decreciente).
- **Reinicio:** completo, cuesta oro y se hace con Maese Corwin en la capital, fuera de combate.
- **Ventana (T):** holograma azul a pantalla completa; rueda para el zoom, arrastrar para moverse, clic para comprar. Cada nodo es el icono de su estadística (`assets/icons/talents/`) en un marco según su tipo.
- **Personajes anteriores** (versión 7): al cargarse pierden sus talentos y maestrías y recuperan todos los puntos.
- **Nodos:** ver [[Anexo C — Árbol de talentos]].

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
- **Cada 50 niveles:** rango de clase (mejora a elegir, [[04 Personajes y progresión|§4.4]]).
- **Muerte:** no hace perder experiencia.
- **De dónde sale la experiencia** ([[D-017 Mundo por zonas, hordas y demo del prólogo y arco 1]]): sobre todo de **matar hordas y de las mazmorras**. Completar una misión da 1 o 2 niveles, más la experiencia de sus enemigos.

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
- Se eligen **nombre, raza y apariencia**. La clase se elige en el juego, durante el asalto del prólogo (0.13.0).
- **Apariencia vóxel:** tipo de cuerpo, tono de piel, peinado, color de pelo y color de ojos; los modelos se arman por piezas (cabeza, torso, brazos, piernas).
- **Ropa inicial:** la decide la clase. Después cambia con el equipo ([[08 Botín y economía|§8]]).
- **Nombres:** de 2 a 16 caracteres (letras con tildes, números, espacios, `-` y `'`), sin repetir entre los personajes del mismo jugador.
- **Implementado (0.2.0):** modelo base de **Kenney Blocky Characters** (CC0, 27 vóxeles de alto, animado por piezas rígidas). Apariencia con **2 cuerpos** (esbelto y robusto, por proporciones), **8 tonos de piel**, **7 colores de ojos** (incluido rojo), **8 peinados** (corto, media melena, flequillo, calvo, y melena, coleta, moño y cresta en vóxel), **11 colores de pelo** (incluido rojo intenso) y **5 barbas**. La ropa inicial de cada clase es una capa de textura más piezas vóxel: hombreras del Guerrero, capucha baja del Clérigo, sombrero del Mago, capucha del Arquero y pañuelo del Asesino. Opciones en `data/characters/`.
- **Capuchas (2026-11-27):** las del Clérigo, el Arquero y el Asesino siguen la referencia del usuario: amplias y altas, abertura en arco con forro oscuro y la cara en sombra bajo el ala, mechones a los lados y faldones escalonados sobre hombros, pecho y espalda (`tools/art/hood_v2.mjs`). Cada clase conserva sus colores y adornos (diadema y mitra, punta y pluma, máscara y cuernos).
- **Razas [Implementado 0.10.0]** ([[D-016 Razas solo de aspecto con cabeza propia]]): **humano, elfo, enano, ogro y hombre lagarto**, solo de aspecto. Comparten el cuerpo v2 con proporciones propias:
  - el enano, más bajo (0,8) y ancho;
  - el elfo, alto y esbelto, con orejas largas;
  - el ogro, enorme (1,3), con cabeza propia y colmillos;
  - el lagarto, con cabeza propia, hocico y cola.
  El ogro y el lagarto tienen sus propias pieles. El lagarto lleva **crestas** en lugar de pelo. Cada opción de apariencia indica qué razas la admiten. Datos en `data/characters/races.json`.
- **Apariencia ampliada [Implementado 0.10.0]:** 16 peinados para las razas de cabeza humana, 4 crestas, 10 barbas (dos enanas), 16 colores de pelo, 9 de ojos, 22 pieles y **rasgos** de la cara (cicatrices, pintura de guerra, tatuaje rúnico y pecas). Un personaje anterior a la 0.10.0 se abre como humano.

---
← [[00 Índice del GDD|Índice del GDD]]
