-- UP SKY CMS · datos iniciales (los que hoy tiene el sitio).
-- Ejecutar UNA SOLA VEZ en Supabase > SQL Editor, DESPUÉS de schema.sql.
-- Las fotos se cargan desde el panel. Las fechas de eventos son de demostración.

insert into public.items (section, position, active, data) values
('productos', 0, true, '{"nombre":"1 pack de energizante","presentacion":"6 botellas 355cc c/u","tipo":"Pack","precio":14500,"max_por_pedido":10,"desc_desde_5":5,"etiqueta":"Más elegido","destacado":"SI"}'),
('productos', 1, true, '{"nombre":"1 vaso UP SKY","presentacion":"Edición especial","tipo":"Vaso","precio":3200,"desc_desde_5":5,"desc_desde_10":10,"colores":"Negro, Rosa","destacado":"SI"}'),
('productos', 2, true, '{"nombre":"1 remera UP SKY","presentacion":"Algodón negro · logo estampado","tipo":"Remera","precio":36500,"desc_desde_5":3,"desc_desde_10":6,"destacado":"SI"}'),

('mayorista', 0, true, '{"nombre":"30 packs de energizante","presentacion":"6 botellas 355cc c/u","unidades":30,"precio":388500}'),
('mayorista', 1, true, '{"nombre":"1 pallet","presentacion":"192 packs de 6 botellas 355cc c/u","unidades":192,"precio":2304000}'),

('pasos_negocios', 0, true, '{"titulo":"Elegís tu volumen","texto":"Packs desde 30 unidades o pallets completos de 192 packs."}'),
('pasos_negocios', 1, true, '{"titulo":"Agregás al carrito","texto":"Sumás lo que necesitás desde la lista de arriba."}'),
('pasos_negocios', 2, true, '{"titulo":"Completás tus datos","texto":"Nombre, dirección y localidad para coordinar la entrega."}'),
('pasos_negocios', 3, true, '{"titulo":"Coordinamos por WhatsApp","texto":"Confirmamos el pago por transferencia y el envío."}'),

('eventos', 0, true, '{"nombre":"Noche UP SKY","categoria":"Noche","lugar":"Concordia","fecha":"2026-12-05","hora":"21:00","etiquetas":"Degustación, Música","descripcion":"Una noche de música y degustación de UP SKY bien fría, con premios y sorpresas para quienes se sumen."}'),
('eventos', 1, true, '{"nombre":"Entrená con UP SKY","categoria":"Deporte","lugar":"Concordia","fecha":"2026-12-12","hora":"10:00"}'),
('eventos', 2, true, '{"nombre":"Festival de la comunidad","categoria":"Comunidad","lugar":"Por definir","fecha":"2026-12-19","hora":"18:00"}'),
('eventos', 3, true, '{"nombre":"Verano en la costa","categoria":"Playa","lugar":"Costa del Uruguay","fecha":"2027-01-09","hora":"17:00"}'),
('eventos', 4, true, '{"nombre":"UP SKY en tu comercio","categoria":"Comercio","lugar":"A coordinar","fecha":"2027-01-16","hora":"11:00"}'),
('eventos', 5, true, '{"nombre":"Competencias y torneos","categoria":"Deporte","lugar":"Por definir","fecha":"2027-01-23","hora":"09:00"}');
