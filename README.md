# UP SKY CMS · puesta en marcha

Panel de administración para que el cliente edite **Catálogo**, **Para negocios** (precios por mayor y "Cómo funciona") y **Eventos**.
Es independiente del sitio: HTML estático + Supabase (base de datos, login e imágenes).

## 1. Crear el proyecto en Supabase
1. Crear una cuenta en supabase.com y un proyecto nuevo (región São Paulo, la más cercana a Argentina).
2. **SQL Editor**: pegar `schema.sql` (cambiando `CAMBIAR_EMAIL` por el email del cliente) y ejecutar.
3. **Authentication > Users > Add user**: crear el usuario con ese email y una contraseña fuerte. Marcar "Auto confirm".
4. **Authentication > Providers > Email**: desactivar "Allow new users to sign up" (nadie más puede registrarse).
5. **Project Settings > API**: copiar la URL y la clave *publishable/anon*. **No usar la clave secret/service_role.**

## 2. Configurar el panel
Completar `supabase-config.js` con la URL, la clave anon, el email del cliente y la URL del sitio (la URL y la clave ya están cargadas). Después, ejecutar `seed.sql` una sola vez para cargar los datos actuales del sitio.

## 3. Publicar el panel
Subirlo a Netlify o Vercel (este repositorio) en una dirección aparte del sitio, por ejemplo `panel.upsky.com.ar`. Tiene `noindex`: no aparece en buscadores.

## 4. Seguridad
- Las políticas RLS (en `schema.sql`) dejan al público **solo leer** lo marcado como visible. Escribir exige iniciar sesión con el email del administrador.
- La clave anon es pública por diseño. La clave secret nunca va en el panel ni en el sitio.
- Cambiar la contraseña desde Supabase si se comparte con alguien.

## Datos que maneja cada sección (tabla `items`, columna `data`)
| Sección | Campos |
|---|---|
| `productos` | nombre, presentacion, tipo, precio, max_por_pedido, desc_desde_5, desc_desde_10, etiqueta, colores, destacado, descripcion, imagen_1..4 |
| `mayorista` | nombre, presentacion, unidades, precio, nota, imagen_1 |
| `pasos_negocios` | titulo, texto |
| `eventos` | nombre, categoria, lugar, fecha, hora, etiquetas, descripcion, imagen_1 |

El sitio lee con: `GET {URL}/rest/v1/items?section=eq.eventos&order=position` (cabecera `apikey` con la clave anon). Solo devuelve lo visible.


## Equipo del sitio (usuarios con roles)

Hasta **3 personas** pueden entrar al panel (el acceso de soporte de la agencia no cuenta). Dos roles, solo para el contenido del sitio:

| Rol | Puede |
|---|---|
| **Administrador** | Todo, y además gestionar el equipo (sección *Equipo*) y ver *Mi plan*. |
| **Editor** | Editar contenido, imágenes y promociones; ver estadísticas e historial. |

- Quién puede entrar lo define la tabla `team_members` (`migrations/005_usuarios.sql`). Una cuenta de Supabase que no esté en esa lista no puede escribir nada.
- El administrador crea el acceso desde **Equipo**: elige un email y una contraseña inicial, y se la comparte (WhatsApp o como prefiera). Al entrar, la persona tiene que cambiarla. No depende del correo de Supabase.
- Las cuentas las crea la función `supabase/functions/team` (se despliega con `supabase functions deploy team`; la clave de servicio la pone la plataforma, no hay que cargarla). Solo la usa un administrador.
- El límite de 3, el acceso de soporte y "siempre queda un administrador" los impone también la base de datos (trigger `team_guard`).
- El login ahora pide **email y contraseña**. "¿Olvidaste tu contraseña?" envía un enlace; si el correo de Supabase no llega, un administrador puede generar una nueva desde *Equipo*.

## Comunidad (videos)

Sección **Comunidad** del panel: se sube un video (MP4, WebM o MOV, vertical, hasta 30 MB) y aparece en el carrusel del Inicio. Para **bajarlo** de la web se apaga "Mostrar en la web" (queda guardado) o se elimina (se borra también el archivo). La portada se genera sola con el primer cuadro. Requiere `migrations/007_comunidad.sql` (ya aplicada) y que los CSP de ambos sitios permitan `media-src https://*.supabase.co`.

## Notificaciones push

La campana de la barra superior activa las notificaciones en el dispositivo de cada persona del equipo (celular o computadora). Avisos: clics a WhatsApp, productos en el carrito (máximo uno cada 15 minutos por tipo) y agenda (evento de mañana, promoción que termina en 24 h, publicación programada que salió; se revisa cada hora). Cada persona elige cuáles recibir.

- `migrations/009_notificaciones_push.sql` (ya aplicada): tablas `push_subscriptions`, `push_config` (privada) y `push_log`, el aviso desde `analytics_events` y la tarea horaria `push-agenda`.
- `supabase/functions/push`: se despliega con `--no-verify-jwt` (valida ella misma la sesión del equipo o el secreto interno). Genera sola las claves VAPID la primera vez y las guarda en `push_config`; no hay que cargar ningún secreto a mano.
- `sw.js` y `manifest.webmanifest`: service worker y manifiesto del panel. En iPhone hay que agregar el panel a la pantalla de inicio para recibir avisos.

## Competencia (análisis con IA)

Se cargan hasta 5 competidores con sus links. La función `supabase/functions/competencia` lee las webs, tiendas y YouTube con la herramienta de lectura web de Claude, suma el material que cargó el cliente (textos pegados y capturas de Instagram, TikTok, etc., que no se pueden leer solos) y guarda un informe en `competitor_reports`: resumen de la categoría, tendencias, oportunidades, ideas y el detalle de cada competidor.

- **Cupo:** 2 análisis por mes (`ai_usage`). Se reserva al empezar y se devuelve si el análisis falla. Para darle uno extra a un cliente: `update ai_usage set bonus = bonus + 1 where month = 'AAAA-MM';`
- **Clave de Claude:** secreto `ANTHROPIC_API_KEY` en Supabase (Edge Functions → Secrets). Sin ella la función avisa con un mensaje claro y no gasta cupo.
- **Costo estimado:** el uso real de cada informe queda en `competitor_reports.usage` (tokens y costo estimado en dólares).
- **Despliegue:** `supabase functions deploy competencia --no-verify-jwt`. `migrations/011_competencia_ia.sql` ya está aplicada.
- La tabla `competitor_snapshots` (números cargados a mano) quedó sin uso en el panel.
