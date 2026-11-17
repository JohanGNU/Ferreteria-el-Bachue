-- =====================================================================
-- Ferretería El Bachué - datos de prueba (init 04)
-- Corre como superusuario al crear el volumen de la BD.
-- Las FK se resuelven por código/NIT/nombre (no por id fijo).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Roles y usuarios de prueba
--   admin@ferreteria.com    / Admin123*     (admin)
--   vendedor@ferreteria.com / Vendedor123*  (vendedor)
-- Hash bcrypt (costo 12) generado con la librería bcrypt de Python.
-- ---------------------------------------------------------------------
INSERT INTO roles (nombre) VALUES ('admin'), ('vendedor');

INSERT INTO usuarios (nombre, email, password_hash, rol_id)
SELECT u.nombre, u.email, u.hash, r.id
FROM (VALUES
    ('Administrador del sistema', 'admin@ferreteria.com',
     '$2b$12$0SzmGu6S34Ty62VwuDdNT.0SMM3sx5XB2p8sLI2jpAN0hWvsNYi2K', 'admin'),
    ('Vendedor de mostrador', 'vendedor@ferreteria.com',
     '$2b$12$jK5nL72SKLecOs8.2G5xHOOgo3zZTfzTRWBAJwQm5J8KreAjrb/ta', 'vendedor')
) AS u (nombre, email, hash, rol)
JOIN roles r ON r.nombre = u.rol;

-- ---------------------------------------------------------------------
-- Categorías
-- ---------------------------------------------------------------------
INSERT INTO categorias (nombre, descripcion) VALUES
    ('Herramientas manuales',   'Martillos, destornilladores, alicates y medición'),
    ('Herramientas eléctricas', 'Taladros, pulidoras y sierras'),
    ('Tornillería y fijaciones','Tornillos, chazos y puntillas'),
    ('Electricidad',            'Cables, tomas, iluminación y protecciones'),
    ('Plomería',                'Tubería, llaves y accesorios'),
    ('Pinturas',                'Pinturas, brochas y rodillos'),
    ('Construcción',            'Cemento, arena y agregados'),
    ('Jardinería',              'Mangueras y herramientas de jardín');

-- ---------------------------------------------------------------------
-- Proveedores
-- ---------------------------------------------------------------------
INSERT INTO proveedores (nit, nombre, telefono, email) VALUES
    ('900123456-1', 'Distribuidora Ferretera Andina S.A.S.',      '6087701234', 'ventas@ferreandina.com'),
    ('900234567-2', 'Herramientas Pro Colombia Ltda.',            '6017452233', 'pedidos@herramientaspro.co'),
    ('900345678-3', 'Eléctricos del Centro S.A.S.',               '6087623344', 'comercial@electricoscentro.com'),
    ('900456789-4', 'Pinturas y Acabados Boyacá S.A.S.',          '6087405566', 'contacto@pinturasboyaca.com'),
    ('900567890-5', 'Cementos y Agregados del Altiplano S.A.',    '6087718899', 'despachos@cementosaltiplano.com');

-- ---------------------------------------------------------------------
-- Productos (precios en COP, antes de IVA)
-- Algunos quedan a propósito en estado BAJO o AGOTADO para la alerta.
-- ---------------------------------------------------------------------
INSERT INTO productos (codigo, nombre, categoria_id, proveedor_id,
                       precio_compra, precio_venta, stock, stock_minimo)
SELECT p.codigo, p.nombre, c.id, pr.id, p.compra, p.venta, p.stock, p.minimo
FROM (VALUES
    ('HM-001', 'Martillo de uña 16 oz',                 'Herramientas manuales',    '900234567-2',  18000,  26000,  40,   5),
    ('HM-002', 'Destornillador de pala 1/4"',           'Herramientas manuales',    '900234567-2',   5500,   8500,  60,  10),
    ('HM-003', 'Alicate universal 8"',                  'Herramientas manuales',    '900234567-2',  16000,  24000,  35,   5),
    ('HM-004', 'Flexómetro 5 m',                        'Herramientas manuales',    '900123456-1',   9000,  14000,  50,   8),
    ('HE-001', 'Taladro percutor 1/2" 650 W',           'Herramientas eléctricas',  '900234567-2', 165000, 229000,  12,   3),
    ('HE-002', 'Pulidora angular 4-1/2" 850 W',         'Herramientas eléctricas',  '900234567-2', 150000, 210000,   3,   4),
    ('HE-003', 'Sierra circular 7-1/4" 1400 W',         'Herramientas eléctricas',  '900234567-2', 280000, 389000,   6,   2),
    ('TF-001', 'Tornillo drywall 6x1" (caja x100)',     'Tornillería y fijaciones', '900123456-1',   6500,  10000, 120,  20),
    ('TF-002', 'Chazo plástico 1/4" (bolsa x100)',      'Tornillería y fijaciones', '900123456-1',   4000,   6500,  90,  15),
    ('TF-003', 'Puntilla con cabeza 2" (libra)',        'Tornillería y fijaciones', '900123456-1',   3500,   5500, 150,  20),
    ('EL-001', 'Cable THHN calibre 12 (metro)',         'Electricidad',             '900345678-3',   2200,   3500, 500, 100),
    ('EL-002', 'Toma doble con polo a tierra',          'Electricidad',             '900345678-3',   5500,   9000,  80,  10),
    ('EL-003', 'Bombillo LED 12 W',                     'Electricidad',             '900345678-3',   4500,   7500, 100,  15),
    ('EL-004', 'Breaker monopolar 20 A',                'Electricidad',             '900345678-3',  14000,  21000,   0,   5),
    ('PL-001', 'Tubo PVC presión 1/2" x 6 m',           'Plomería',                 '900123456-1',  11000,  16500,  70,  10),
    ('PL-002', 'Llave de paso 1/2"',                    'Plomería',                 '900123456-1',  13000,  19500,   4,   6),
    ('PL-003', 'Cinta teflón 1/2" x 10 m',              'Plomería',                 '900123456-1',   1200,   2500, 200,  30),
    ('PI-001', 'Pintura vinilo blanco tipo 1 (galón)',  'Pinturas',                 '900456789-4',  42000,  59000,  45,   8),
    ('PI-002', 'Brocha 3"',                             'Pinturas',                 '900456789-4',   4500,   7500,  60,  10),
    ('CO-001', 'Cemento gris uso general 50 kg',        'Construcción',             '900567890-5',  29000,  36500, 200,  30),
    ('CO-002', 'Arena de río (bulto 40 kg)',            'Construcción',             '900567890-5',   6000,   9500, 150,  20),
    ('JA-001', 'Manguera de jardín 1/2" x 15 m',        'Jardinería',               '900123456-1',  28000,  42000,  20,   4)
) AS p (codigo, nombre, categoria, nit, compra, venta, stock, minimo)
JOIN categorias  c  ON c.nombre = p.categoria
JOIN proveedores pr ON pr.nit   = p.nit;

-- Kardex: el stock inicial entra como movimiento ENTRADA del administrador,
-- para que el historial cuadre con el saldo de productos.stock
INSERT INTO movimientos_inventario (producto_id, tipo, cantidad, usuario_id, fecha)
SELECT p.id, 'ENTRADA', p.stock, u.id, now() - interval '100 days'
FROM productos p
CROSS JOIN usuarios u
WHERE p.stock > 0
  AND u.email = 'admin@ferreteria.com';

-- ---------------------------------------------------------------------
-- Clientes
-- ---------------------------------------------------------------------
INSERT INTO clientes (documento, nombre, telefono, email) VALUES
    ('222222222222', 'Consumidor final',                              NULL,         NULL),
    ('1052345678',   'Carlos Andrés Pérez Rojas',                     '3104567890', 'carlos.perez@gmail.com'),
    ('1053456789',   'Luz Marina Gómez Vargas',                       '3115678901', 'luzmarina.gomez@hotmail.com'),
    ('1054567890',   'Jorge Eliécer Suárez Mora',                     '3126789012', NULL),
    ('1055678901',   'Diana Carolina Rodríguez Niño',                 '3137890123', 'diana.rodriguez@gmail.com'),
    ('1056789012',   'Andrés Felipe Castro León',                     '3148901234', 'afcastro@outlook.com'),
    ('1057890123',   'María Fernanda López Díaz',                     '3159012345', 'mafe.lopez@gmail.com'),
    ('1058901234',   'Óscar Iván Torres Cely',                        '3160123456', NULL),
    ('901234567-8',  'Constructora Los Cerezos S.A.S.',               '6087712345', 'compras@loscerezos.com.co'),
    ('901345678-9',  'Mantenimientos Industriales del Sugamuxi S.A.S.','6087723456', 'almacen@mantsugamuxi.com');
