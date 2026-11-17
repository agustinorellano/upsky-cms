// UP SKY · configuración del panel (independiente de la web).
// La clave "publishable/anon" es pública por diseño: la seguridad la dan las políticas RLS de la base.
// NUNCA pegar acá la clave "service_role" / "secret".
window.UPSKY_SUPABASE = {
  url:        'https://stwyjbxmkwgwjwmctpki.supabase.co',
  anonKey:    'sb_publishable_CiDNlwCOX3-z2I59TQg8BA_zJTqZj8P',         // Project Settings > API > publishable / anon
  adminEmail: 'agustinorellanogomez@gmail.com',         // el panel solo pide la contraseña de este usuario
  bucket:     'upsky-images',
  siteUrl:    'https://PEGAR-URL-DEL-SITIO/',    // la URL final de la web
};
