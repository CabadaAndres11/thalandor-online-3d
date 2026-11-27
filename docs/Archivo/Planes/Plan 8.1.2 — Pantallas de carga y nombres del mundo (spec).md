---
tags: [plan, spec]
plan: 8.1.2
fecha: 2026-11-23
estado: implementado
actualizado: 2026-11-23
---
# Plan 8.1.2 — Pantallas de carga y nombres del mundo: diseño

## Objetivo
Que la pantalla de carga sea una **imagen fija de una escena del propio juego**, con un **consejo** y una **barra de carga**, y usar los **nombres propios** del mundo que da el usuario. Sale como **0.11.2**.

## Nombres del mundo (usuario)

| Qué | Nombre |
|---|---|
| Continente | **Velmora** |
| Reino | **Valdrenn** |
| Capital | **Sumerhold** |
| Bosque | **Eldarra** («Bosque de Eldarra» en carteles, mapa y pantallas de carga) |
| Aldea | **Aelhest** |
| Cripta del sello del arco 1 | **Cripta de Sumerhold** |

- Los textos de zona pasan a usarlos:
  - `ZONE_ALDEA` → Aelhest;
  - `ZONE_BOSQUE` → Bosque de Eldarra.
- La cripta de prueba conserva su nombre provisional; la Cripta de Sumerhold llega con el arco 1.
- Los nombres quedan en el GDD (06 Mundo) para diálogos y misiones.

## Pantalla de carga
- **Imagen:**
  - A pantalla completa y opaca, recortada para cubrir sin deformarse.
  - Son capturas reales del juego, hechas con una herramienta de captura (`tests/helpers/render_loading.gd`): 2 o 3 por zona, a la altura de los ojos y con la luz de su ambiente, con Brann y el mercader en la aldea.
  - Se guardan en `assets/ui/loading/`.
  - Se elige al azar una de la zona de destino. Una zona sin capturas usa las genéricas (`default`).
- **Arriba:** el nombre de la zona en piedra y oro, como en los menús.
- **Abajo:** una franja oscura con un **consejo** al azar y una **barra de carga** fina y dorada.
- **Barra de carga:** avanza con los pasos reales de la construcción de la zona y de la precarga de monstruos.
- **Datos (`data/loading.json`):**
  - `images`: zona → rutas de imagen;
  - `tips`: claves de texto, en `textos.csv`.
- **Consejos:** unos 12, sobre:
  - atributos (C);
  - talentos (T);
  - habilidades (K);
  - mapa (M);
  - Ordenar la bolsa;
  - esquiva (Espacio);
  - pociones (Q/R);
  - grupo desde la pausa;
  - nivel de la mazmorra en su puerta;
  - hordas como forma de subir;
  - salir de combate antes de cambiar de zona;
  - Brann.

## Linde del mapa (usuario, tras la prueba de la 0.11.1)
- El borde deja de ser solo decorado de fuera: las **últimas 10 casillas** de las zonas con `"margin": "forest"` son una **linde** de árboles y rocas dentro del mapa que bloquea el paso.
- **Salidas:** cada salida del borde es una **senda** tan ancha como la salida que cruza la linde. El cambio de zona salta **5 casillas antes del borde**, dentro de la senda. El cartel y las antorchas están en la boca de la senda, y las llegadas a la zona, justo dentro.
- **Fuera del mapa:** el bosque decorado sigue durante **30 casillas**, muy denso cerca. El suelo de debajo es de sotobosque oscuro, así que los huecos se leen como bosque.
- **Cámara:** no se acerca a menos de 10 casillas del borde. Con la isométrica a su zoom máximo se ven unos 30 m: la linde y el bosque de fuera los cubren.
- **Mazmorras:** sin linde; siguen con sus muros y la roca decorada de fuera.

## Pruebas (GUT)
- **Imagen:** la pantalla elige una imagen de la zona de destino, o una genérica si la zona no tiene.
- **Datos:** cada imagen de `loading.json` existe.
- **Consejo:** está traducido y sale de la lista.
- **Barra de carga:**
  - la barra sigue `set_progress`;
  - en el juego, el progreso llega a 1 al acabar la construcción;
  - el progreso solo sube.
- **Nombres:** los carteles y el mapa dicen «Bosque de Eldarra» y «Aelhest».
- La suite completa pasa.

## Decisiones
- **Del usuario:**
  - imágenes fijas de escenas del juego;
  - consejos;
  - barra de carga;
  - los nombres del mundo.
- **De Claude:**
  - 2 o 3 capturas por zona elegidas al azar, con genéricas de reserva;
  - consejos en datos;
  - la barra sigue los pasos reales;
  - la franja inferior;
  - el JPG para que las imágenes pesen poco.

## Tareas
1. Nombres en `textos.csv` y en el GDD.
2. Herramienta de captura y las imágenes de aldea, bosque y cripta.
3. `data/loading.json` y los consejos.
4. `LoadingOverlay` con imagen, título, consejo y barra; `GameSession` le pasa el progreso.
5. Versión 0.11.2, documentación, revisión y subida.

---
← [[Planes]]
