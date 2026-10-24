# Platon · DATABASE

PostgreSQL y RabbitMQ para Platon.

## Requisitos

Docker con Compose (`docker compose`) y los puertos `5432`, `5672` y `15672` libres.

## Uso

Desde la carpeta `DATABASE` (donde está `docker-compose.yml`):

```bash
docker compose up -d --wait   # levantar
docker compose ps             # ver estado
docker compose down           # detener (conserva los datos)
```

## Accesos

| Servicio | Dirección | Usuario | Password |
| --- | --- | --- | --- |
| PostgreSQL | `localhost:5432` · base `account_db` | `account_user` | `account_pass` |
| RabbitMQ (AMQP) | `localhost:5672` | `guest` | `guest` |
| RabbitMQ (panel) | <http://localhost:15672> | `guest` | `guest` |

Usuarios de prueba de la aplicación: `admin` / `admin123` y `usuario` / `usuario123`.

> Credenciales solo para desarrollo local.

## Base de datos

Tres schemas dentro de `account_db`:

| Schema | Tablas |
| --- | --- |
| `account` | `status`, `roles`, `users` |
| `products` | `editorial`, `genre`, `product`, `stock_movement`, `purchase_stock_deduction` |
| `payment` | `state_sold`, `products_sold`, `products_sold_item`, `purchase_event_outbox`, `user_products` |

Los scripts de `init/` se ejecutan en orden (01, 02, 03) **solo al crear el volumen por primera vez**. Este proyecto es el único que crea y actualiza las tablas; los microservicios no lo hacen.

Conectarse con `psql`:

```bash
docker exec -it platon-account-postgres psql -U account_user -d account_db
```

Para el microservicio de Products:

```text
DB_URL=jdbc:postgresql://localhost:5432/account_db?currentSchema=products
DB_USERNAME=account_user
DB_PASSWORD=account_pass
```

## RabbitMQ

Exchange, colas y bindings se crean solos al arrancar (desde `rabbitmq/definitions.json`):

| Exchange (topic) | Cola | Routing key |
| --- | --- | --- |
| `platon.purchase.events` | `platon.purchase.created` | `purchase.created` |
| `platon.purchase.events` | `platon.products.purchase.validation` (TTL 30 s) | `purchase.requested` |
| `platon.purchase.events` | `platon.products.payment.rejected` | `payment.rejected` |

Ver colas: `docker exec platon-rabbitmq rabbitmqctl list_queues name messages consumers`

## Reiniciar desde cero

Si cambiaste algo en `init/` y quieres aplicarlo:

```bash
docker compose down -v
docker compose up -d --wait
```

> `-v` borra los datos de PostgreSQL y RabbitMQ.

## Actualizar una base existente (sin borrar datos)

Con Payments detenido, ejecuta en este orden:

```bash
docker exec -it platon-account-postgres psql -U account_user -d account_db -f /docker-entrypoint-initdb.d/02-grouped-sales-upgrade.sql
docker exec -it platon-account-postgres psql -U account_user -d account_db -f /docker-entrypoint-initdb.d/03-purchase-amounts-upgrade.sql
```

No ejecutes `01-create-database-schema.sql` sobre una base con datos.
