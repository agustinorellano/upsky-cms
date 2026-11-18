-- UP SKY CMS · detalles iniciales de los productos (opcional; se pueden editar desde el panel).
-- Ejecutar en Supabase > SQL Editor. Solo agrega el campo "detalles"; no toca precios ni fotos.
update public.items set data = data || jsonb_build_object('detalles', E'Contenido: 6 botellas de 355 cc\nEnvase: botella de vidrio\nSabor: frutilla\nOrigen: Industria Argentina')
 where section = 'productos' and data->>'tipo' = 'Pack';
update public.items set data = data || jsonb_build_object('detalles', E'Edición especial\nColores: negro y rosa')
 where section = 'productos' and data->>'tipo' = 'Vaso';
update public.items set data = data || jsonb_build_object('detalles', E'Material: algodón negro\nLogo estampado en el frente')
 where section = 'productos' and data->>'tipo' = 'Remera';
update public.items set data = data || jsonb_build_object('detalles', E'Cantidad: 30 packs de 6 botellas de 355 cc\nEnvase: botella de vidrio\nPago por transferencia bancaria\nPrecio sin envío')
 where section = 'mayorista' and (data->>'unidades')::int = 30;
update public.items set data = data || jsonb_build_object('detalles', E'Cantidad: 192 packs de 6 botellas de 355 cc\nEnvase: botella de vidrio\nPago por transferencia bancaria\nPrecio sin envío')
 where section = 'mayorista' and (data->>'unidades')::int = 192;
