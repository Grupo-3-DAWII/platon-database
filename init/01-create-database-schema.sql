-- Unico init para PostgreSQL compartido y PostgreSQL independiente de Products.
-- Docker ejecuta este archivo con psql. Por defecto crea todos los esquemas.
-- PLATON_PRODUCTS_ONLY=true conserva el init exclusivo de Products.
\set products_only false
\getenv products_only PLATON_PRODUCTS_ONLY

BEGIN;

\if :products_only
\else
CREATE SCHEMA IF NOT EXISTS account;

CREATE TABLE account.status (
    idstatus BIGSERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE account.roles (
    idrole BIGSERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE account.users (
    iduser BIGSERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    lastname VARCHAR(80) NOT NULL,
    username VARCHAR(80) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    idrole BIGINT NOT NULL,
    idstatus BIGINT NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    nro VARCHAR(20) NOT NULL UNIQUE,
    direccion VARCHAR(180) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (idrole) REFERENCES account.roles(idrole),
    FOREIGN KEY (idstatus) REFERENCES account.status(idstatus)
);

INSERT INTO account.status (name)
VALUES
    ('active'),
    ('inactive');

INSERT INTO account.roles (name)
VALUES
    ('ADMIN'),
    ('USER'),
    ('SELLER');

INSERT INTO account.users (name, lastname, username, password, idrole, idstatus, email, nro, direccion)
VALUES
    ('Admin', 'Platon', 'admin', '{noop}admin123', 1, 1, 'admin@platon.local', '900000001', 'Platon Admin'),
    ('Usuario', 'Platon', 'usuario', '{noop}usuario123', 2, 1, 'usuario@platon.local', '900000002', 'Platon Usuario');
\endif

CREATE SCHEMA IF NOT EXISTS products;

CREATE TABLE IF NOT EXISTS products.editorial (
    ideditorial BIGSERIAL PRIMARY KEY,
    name VARCHAR(160) NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS products.genre (
    idgenre BIGSERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

ALTER TABLE products.editorial ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE products.genre ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT TRUE;
CREATE UNIQUE INDEX IF NOT EXISTS ux_editorial_name_lower ON products.editorial (LOWER(name));
CREATE UNIQUE INDEX IF NOT EXISTS ux_genre_name_lower ON products.genre (LOWER(name));

CREATE TABLE IF NOT EXISTS products.product (
    idproduct BIGSERIAL PRIMARY KEY,
    name VARCHAR(160) NOT NULL,
    isbn VARCHAR(20) NOT NULL,
    author VARCHAR(160) NOT NULL,
    ideditorial BIGINT NOT NULL REFERENCES products.editorial (ideditorial),
    idgenre BIGINT NOT NULL REFERENCES products.genre (idgenre),
    publication_year INTEGER NOT NULL CHECK (publication_year BETWEEN 1 AND 3000),
    description VARCHAR(2000) NOT NULL,
    image_url VARCHAR(1000),
    purchase_price NUMERIC(12, 2) NOT NULL CHECK (purchase_price >= 0),
    profit_margin NUMERIC(6, 2) NOT NULL CHECK (profit_margin >= 0),
    sale_price NUMERIC(12, 2) NOT NULL CHECK (sale_price >= 0),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_product_isbn UNIQUE (isbn)
);

ALTER TABLE products.product ADD COLUMN IF NOT EXISTS image_url VARCHAR(1000);
ALTER TABLE products.product ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE products.product ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE UNIQUE INDEX IF NOT EXISTS ux_product_name_lower ON products.product (LOWER(name));
CREATE UNIQUE INDEX IF NOT EXISTS ux_product_isbn_lower ON products.product (LOWER(isbn));

CREATE TABLE IF NOT EXISTS products.stock_movement (
    idmovement BIGSERIAL PRIMARY KEY,
    idproduct BIGINT NOT NULL REFERENCES products.product (idproduct) ON DELETE RESTRICT,
    type VARCHAR(10) NOT NULL CHECK (type IN ('ENTRY', 'EXIT')),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    movement_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resulting_stock INTEGER NOT NULL CHECK (resulting_stock >= 0),
    notes VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_stock_movement_product_date
    ON products.stock_movement (idproduct, movement_date DESC, idmovement DESC);

INSERT INTO products.editorial (name) VALUES ('Alfaguara'), ('Planeta'), ('Penguin Random House')
ON CONFLICT (name) DO NOTHING;

INSERT INTO products.genre (name) VALUES ('Novela'), ('Poesia'), ('Ensayo')
ON CONFLICT (name) DO NOTHING;

INSERT INTO products.product (
    name, isbn, author, ideditorial, idgenre, publication_year, description,
    purchase_price, profit_margin, sale_price, active, stock, created_at, updated_at
)
SELECT 'Don Quijote', '978-612-00-0001-1', 'Miguel de Cervantes',
       (SELECT ideditorial FROM products.editorial WHERE name = 'Alfaguara'),
       (SELECT idgenre FROM products.genre WHERE name = 'Novela'),
        1605, 'Las aventuras del ingenioso hidalgo.',
        80.00, 60.00, 128.00, TRUE, 5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
WHERE NOT EXISTS (
    SELECT 1 FROM products.product WHERE isbn = '978-612-00-0001-1'
);

INSERT INTO products.stock_movement (idproduct, type, quantity, movement_date, resulting_stock, notes)
SELECT idproduct, 'ENTRY', stock, CURRENT_TIMESTAMP, stock, 'Stock inicial'
FROM products.product AS initial_product
WHERE isbn = '978-612-00-0001-1'
  AND stock > 0
  AND NOT EXISTS (
      SELECT 1 FROM products.stock_movement movement
      WHERE movement.idproduct = initial_product.idproduct
  );

CREATE TABLE IF NOT EXISTS products.purchase_stock_deduction (
    deduction_id UUID PRIMARY KEY,
    id_products BIGINT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('DEDUCTED', 'RETURNED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    returned_at TIMESTAMPTZ
);

\if :products_only
\else
CREATE SCHEMA IF NOT EXISTS payment;

CREATE TABLE IF NOT EXISTS payment.state_sold (
    id_state_sold BIGSERIAL PRIMARY KEY,
    name_state VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS payment.products_sold (
    id_products_sold BIGSERIAL PRIMARY KEY,
    -- Columnas anteriores conservadas para compatibilidad.
    id_products BIGINT,
    id_user BIGINT NOT NULL,
    number_sold INTEGER,
    create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_state_sold BIGINT NOT NULL,
    stock_deduction_id UUID,
    total_amount NUMERIC(18, 2) CHECK (total_amount >= 0),
    CONSTRAINT fk_products_sold_state_sold
        FOREIGN KEY (id_state_sold)
        REFERENCES payment.state_sold (id_state_sold),
    CONSTRAINT fk_products_sold_products
        FOREIGN KEY (id_products)
        REFERENCES products.product (idproduct)
);

-- Una cabecera de venta y varios detalles; tambien actualiza instalaciones existentes.
ALTER TABLE payment.products_sold ALTER COLUMN id_products DROP NOT NULL;
ALTER TABLE payment.products_sold ALTER COLUMN number_sold DROP NOT NULL;
CREATE TABLE IF NOT EXISTS payment.products_sold_item (
    id BIGSERIAL PRIMARY KEY,
    id_products_sold BIGINT NOT NULL REFERENCES payment.products_sold(id_products_sold) ON DELETE CASCADE,
    id_products BIGINT NOT NULL REFERENCES products.product(idproduct),
    number_sold INTEGER NOT NULL CHECK (number_sold > 0),
    unit_price NUMERIC(12, 2) CHECK (unit_price >= 0),
    stock_deduction_id UUID,
    CONSTRAINT ux_sale_item_product UNIQUE (id_products_sold, id_products),
    CONSTRAINT ux_sale_item_deduction UNIQUE (stock_deduction_id)
);

-- Datos de ejemplo para el listado de pedidos.
INSERT INTO payment.state_sold (name_state)
SELECT seed.name_state
FROM (VALUES ('PENDIENTE'), ('PAGADO'), ('CANCELADO')) AS seed(name_state)
WHERE NOT EXISTS (
    SELECT 1 FROM payment.state_sold existing
    WHERE UPPER(existing.name_state) = seed.name_state
);

INSERT INTO payment.products_sold (
    id_products, id_user, number_sold, create_date, id_state_sold
)
SELECT product.idproduct, buyer.iduser, seed.quantity, seed.created_at,
       (SELECT MIN(state.id_state_sold)
        FROM payment.state_sold state
        WHERE UPPER(state.name_state) = seed.state_name)
FROM (VALUES
    ('usuario', 1, TIMESTAMP '2026-10-01 09:00:00', 'PENDIENTE'),
    ('usuario', 1, TIMESTAMP '2026-10-02 10:00:00', 'PENDIENTE'),
    ('admin',   1, TIMESTAMP '2026-10-03 11:00:00', 'PAGADO'),
    ('usuario', 1, TIMESTAMP '2026-10-04 12:00:00', 'CANCELADO')
) AS seed(username, quantity, created_at, state_name)
JOIN account.users buyer ON buyer.username = seed.username
JOIN products.product product ON product.isbn = '978-612-00-0001-1'
WHERE NOT EXISTS (
    SELECT 1 FROM payment.products_sold existing
    WHERE existing.id_products = product.idproduct
      AND existing.id_user = buyer.iduser
      AND existing.create_date = seed.created_at
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_products_sold_stock_deduction
    ON payment.products_sold (stock_deduction_id) WHERE stock_deduction_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS payment.purchase_event_outbox (
    event_id UUID PRIMARY KEY,
    id_products_sold BIGINT,
    payload TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMPTZ,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_error VARCHAR(1000),
    event_type VARCHAR(80) NOT NULL DEFAULT 'purchase.created',
    stock_deduction_id UUID
);

CREATE INDEX IF NOT EXISTS ix_purchase_outbox_pending
    ON payment.purchase_event_outbox (created_at, event_id) WHERE published_at IS NULL;
-- Se deduplican eventos por descuento y tipo, no por venta.
DROP INDEX IF EXISTS payment.ux_purchase_outbox_sale_type;
CREATE UNIQUE INDEX IF NOT EXISTS ux_purchase_outbox_deduction_type
    ON payment.purchase_event_outbox (stock_deduction_id, event_type) WHERE stock_deduction_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS payment.user_products (
    id_products_sold BIGINT NOT NULL REFERENCES payment.products_sold (id_products_sold),
    id_user BIGINT NOT NULL,
    id_products BIGINT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    acquired_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- Permite asignar todos los productos de la venta, conservando las asignaciones anteriores.
ALTER TABLE payment.user_products DROP CONSTRAINT IF EXISTS user_products_pkey;
ALTER TABLE payment.user_products ADD CONSTRAINT user_products_pkey
    PRIMARY KEY (id_products_sold, id_products);
\endif

COMMIT;
