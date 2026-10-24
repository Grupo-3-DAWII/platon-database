\set ON_ERROR_STOP on
\set products_only false
\getenv products_only PLATON_PRODUCTS_ONLY
\if :products_only
\else
-- Ejecutar despues de 02-grouped-sales-upgrade.sql y antes de iniciar Payments.
-- Los importes historicos desconocidos permanecen NULL: no se inventan precios pasados.
BEGIN;
ALTER TABLE payment.products_sold
    ADD COLUMN IF NOT EXISTS total_amount NUMERIC(18, 2) CHECK (total_amount >= 0);
ALTER TABLE payment.products_sold_item
    ADD COLUMN IF NOT EXISTS unit_price NUMERIC(12, 2) CHECK (unit_price >= 0);
COMMIT;
\endif