\set ON_ERROR_STOP on
\set products_only false
\getenv products_only PLATON_PRODUCTS_ONLY
\if :products_only
\else
-- Actualizacion de una base existente: detener Payments antes de ejecutar.
-- Este script no elimina ventas ni asignaciones existentes.
BEGIN;
ALTER TABLE payment.products_sold ALTER COLUMN id_products DROP NOT NULL;
ALTER TABLE payment.products_sold ALTER COLUMN number_sold DROP NOT NULL;
CREATE TABLE IF NOT EXISTS payment.products_sold_item (
    id BIGSERIAL PRIMARY KEY,
    id_products_sold BIGINT NOT NULL REFERENCES payment.products_sold(id_products_sold) ON DELETE CASCADE,
    id_products BIGINT NOT NULL REFERENCES products.product(idproduct),
    number_sold INTEGER NOT NULL CHECK (number_sold > 0),
    stock_deduction_id UUID,
    CONSTRAINT ux_sale_item_product UNIQUE (id_products_sold, id_products),
    CONSTRAINT ux_sale_item_deduction UNIQUE (stock_deduction_id)
);
DROP INDEX IF EXISTS payment.ux_purchase_outbox_sale_type;
CREATE UNIQUE INDEX IF NOT EXISTS ux_purchase_outbox_deduction_type
    ON payment.purchase_event_outbox (stock_deduction_id, event_type)
    WHERE stock_deduction_id IS NOT NULL;
ALTER TABLE payment.user_products DROP CONSTRAINT IF EXISTS user_products_pkey;
ALTER TABLE payment.user_products ADD CONSTRAINT user_products_pkey
    PRIMARY KEY (id_products_sold, id_products);
COMMIT;
\endif
