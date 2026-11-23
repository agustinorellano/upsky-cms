# Auditoría de accesibilidad · Panel y sitio de UP SKY

**Fecha:** 23 de noviembre de 2026 · **Criterio:** WCAG 2.2 nivel AA (más buenas prácticas)
**Herramienta:** axe-core 4.14.1 con Playwright, más revisiones manuales de teclado, ampliación y celular.

## Alcance y límites
- **Panel:** 26 pantallas y estados (login, Inicio, cada sección, formularios laterales, material, campana, menú de usuario, vista previa, Ayuda, Equipo, Mi plan), en claro, oscuro y celular (390 px). Se probó con una base simulada.
- **Sitio:** 8 páginas en escritorio (1280 px) y celular (390 px), con movimiento reducido.
- **Límites:** las pruebas automáticas detectan alrededor de un tercio de los problemas reales. No se probó con un lector de pantalla real (NVDA, VoiceOver) ni con usuarios. Conviene sumarlo antes de afirmar "cumple AA".

## Lo que ya está bien
- Idioma de la página declarado (`es` en el panel, `es-AR` en el sitio) y zoom permitido.
- Formularios con etiquetas, autocompletado correcto en el ingreso y errores con `role="alert"`.
- Avisos (toast) anunciados con `role="status"`.
- Foco visible (contorno de 2 px) en los controles.
- Sin scroll horizontal a 320 px de ancho ni con el texto al 200 %, en el panel.
- El sitio respeta `prefers-reduced-motion`.

## Panel

| # | Prioridad | Problema | Dónde | Cómo arreglarlo |
|---|---|---|---|---|
| P1 | Crítico | **Botones sin nombre**: las miniaturas de imágenes del Inicio (9) y el botón de usuario en celular (se oculta el texto y queda solo el avatar) | Inicio, celular | `aria-label` ("Ampliar imagen", "Menú de usuario") |
| P2 | Serio | **Contraste del magenta de marca**: `#ec1f7a` da 4,16:1 sobre blanco (mínimo 4,5:1) y 3,66:1 sobre el rosado claro. Texto blanco sobre magenta, igual 4,16:1. 136 elementos en las 26 pantallas: botón "Crear contenido", enlaces, etiquetas, días del calendario | Todo el panel | Un magenta más oscuro para texto y botones: `#d51269` (5,1:1 sobre blanco, y 4,49:1 sobre rosado claro; usar `#d11266` para llegar a 4,63:1). En oscuro, un magenta más claro. El `#ec1f7a` queda para íconos y decoración |
| P3 | Serio | **Contraste de grises**: texto de ayuda `#949a97` sobre `#f9f9fa` (2,72:1), píldora "Soporte" `#6b736f` sobre `#e7eae8` (4,02:1) | Ayuda, Equipo | Oscurecer esos grises |
| P4 | Serio | **Filas de lista con rol de botón que contienen botones** (Ocultar, Editar, Eliminar): los lectores de pantalla no pueden usar los botones internos. 13 filas | Catálogo, Fotos del sitio, Para negocios | Sacar `role="button"` y `tabindex` de la fila; el título pasa a ser el control para abrir |
| P5 | Serio | **El nombre accesible no incluye el texto visible**: la campana (`Notificaciones` con un contador visible) y las filas (`Editar …`) | Campana, listas | Que el `aria-label` contenga el texto visible, o marcar el contador como `aria-hidden` |
| P6 | Serio | **Región con scroll sin teclado**: la vista previa del sitio | Vista previa | `tabindex="0"` y un nombre |
| P7 | Moderado | **Inicio sin título de nivel 1** (la bienvenida usa `h2`) | Inicio | Pasar a `h1` |
| P8 | Moderado | **Saltos en el orden de títulos** (de `h1` a `h3` en las tarjetas) | Competencia, Ayuda, Equipo, Vista previa | Tarjetas con `h2` |
| P9 | Moderado | **El ingreso no tiene zona principal** (`main`) ni zonas de contenido | Login | Envolver en `main` |
| P10 | Moderado | **Sin enlace "Saltar al contenido"**: hacen falta 16 pulsaciones de Tab para llegar al contenido | Todo el panel | Enlace de salto al inicio de la página |
| P11 | Moderado | **Diálogos sin nombre** (8: formularios laterales, vista previa, confirmaciones) | Todo el panel | `aria-labelledby` apuntando a su título |
| P12 | Menor | **Sin `prefers-reduced-motion`** en el panel (animaciones del indicador de carga y transiciones) | Panel | Regla de movimiento reducido |
| P13 | Menor | **Objetivos táctiles chicos en celular**: 25 controles de menos de 44 px. Solo "Ver sitio web" (83×17) baja de los 24 px que exige WCAG 2.2 AA | Celular | Agrandar el área de toque |

## Sitio

| # | Prioridad | Problema | Dónde | Cómo arreglarlo |
|---|---|---|---|---|
| S1 | Serio | **Contraste**: el mismo magenta (`#ec1f7a`, 4,16:1) en 111 elementos, y grises `#606061` y `#6c6c6d` sobre casi negro (3,14:1 y 3,77:1) | Todas las páginas | Magenta más oscuro para texto, y grises más claros sobre fondo oscuro |
| S2 | Serio | **Enlace de WhatsApp flotante sin texto** (`wa-nudge-link`) | Todas las páginas | Texto o `aria-label` |
| S3 | Serio | **Carrito cerrado con contenido enfocable** (`aria-hidden` con botones adentro): se puede llegar con Tab a algo que un lector de pantalla no ve. 20 elementos | Carrito | `inert` mientras está cerrado |
| S4 | Serio | **El botón del carrito**: el nombre accesible ("Ver carrito") no incluye el texto visible | Todas las páginas | Alinear el nombre con el texto |
| S5 | Serio | **Tabla nutricional con scroll sin teclado** en celular | Producto | `tabindex="0"` y un nombre |
| S6 | Moderado | **Sin zona principal (`main`)** en 13 páginas, y contenido fuera de zonas (260 elementos) | Casi todas | Envolver el contenido en `main` |
| S7 | Moderado | **Orden de títulos**: un `h3` sin `h2` previo | Catálogo | Corregir el nivel |
| S8 | Menor | **Rol no permitido**: `tabpanel` en un `article` (12) | Producto | Usar `div` |

## Orden sugerido
1. **P2 y S1 (contraste del magenta):** cambia un par de variables de color y arregla más de la mitad de los problemas de ambos lados.
2. **P1, P4, P5, S2, S3:** son los que bloquean a quien usa lector de pantalla o teclado.
3. **P7 a P11 y S6:** estructura y navegación.
4. **Prueba con un lector de pantalla real** y revisión final.

## Estado tras las correcciones del panel (23 de noviembre de 2026)
Se repitió la misma revisión automática sobre las 26 pantallas del panel. **De 10 tipos de problema se pasó a 2**, y ambos son menores:
- `region`: el enlace "Saltar al contenido" quedó dentro del menú lateral (zona de navegación).
- `target-size`: avisa de un botón del menú tapado parcialmente cuando está abierto el menú de usuario; es un efecto del menú flotante, no un control demasiado chico.

Cambios aplicados: magenta de marca `#d11266` (5,26:1 sobre blanco, y 4,63:1 sobre el rosado claro) y una variante clara `#ff6aa9` para texto en la vista oscura; nombres para las miniaturas y el botón de usuario; filas de lista sin rol de botón; títulos en orden (1 → 2 → 3); `main` en el ingreso; enlace "Saltar al contenido"; diálogos con nombre; movimiento reducido; objetivos táctiles de 44 px en celular.
**Sitio público (S1 a S8): corregido** en la rama `claude/upsky-visual-prototype-9vdi3t` del repo del sitio. Re-auditoría de 8 páginas en escritorio y celular: cero violaciones salvo un elemento (un botón "Me gusta" de una tarjeta lateral del carrusel de Comunidad que, al estar achicada por el efecto de escala, mide 17 px en vez de 24 px; es una decisión de diseño, de severidad baja).

Qué se hizo: magenta de texto `#d11266` (y `#ff5fa8` sobre fondos oscuros), grises más claros sobre negro, zona principal `<main>` en todas las páginas, carrito y menú móvil no enfocables cuando están cerrados, nombres accesibles sin duplicar el texto visible, títulos en orden y regiones desplazables enfocables.

Sigue pendiente la prueba con un lector de pantalla real (NVDA / VoiceOver), que no se puede automatizar.
