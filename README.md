# Base de datos

Este proyecto levanta PostgreSQL y RabbitMQ con Docker Compose, incluyendo el esquema SQL y la topologia de eventos de Platon.

## Requisitos

- Docker Desktop instalado y ejecutandose.
- Terminal ubicada en esta carpeta:

```powershell
cd C:\Users\nekro\Desktop\CIBERTEC\DATABASE
```

## Levantar PostgreSQL y RabbitMQ

```powershell
docker compose up -d
```

Esto crea un contenedor PostgreSQL con estos datos:

```text
Host: localhost
Puerto: 5432
Base de datos: account_db
Usuario: account_user
Password: account_pass
```

## Ver contenedores activos

```powershell
docker compose ps
```

## Ver logs

```powershell
docker compose logs -f postgres
```

## Conectarse a PostgreSQL desde Docker

```powershell
docker exec -it platon-account-postgres psql -U account_user -d account_db
```

Dentro de `psql`, puedes listar los schemas con:

```sql
\dn
```

Y listar las tablas con:

```sql
\dt account.*
\dt products.*
\dt payment.*
```

## Detener la base de datos

```powershell
docker compose down
```

## Reiniciar la base de datos desde cero

El script `init/01-create-database-schema.sql` solo se ejecuta la primera vez que se crea el volumen de PostgreSQL.

Si cambiaste el archivo `init/01-create-database-schema.sql` y quieres aplicar todo desde cero, ejecuta:

```powershell
docker compose down -v
docker compose up -d
```

Esto elimina el volumen anterior y vuelve a crear la base con el script actual.

## Esquema de productos

El init incluye el modelo del microservicio de productos dentro del schema `products`:
`editorial`, `genre`, `product` y `stock_movement`, con indices, restricciones y datos iniciales.
La clave foranea de `payment.products_sold.id_products` referencia `products.product.idproduct`.

Para conectar el microservicio de productos a esta instancia, configura estas variables de entorno:

```text
DB_URL=jdbc:postgresql://localhost:5432/account_db?currentSchema=products
DB_USERNAME=account_user
DB_PASSWORD=account_pass
```

Este archivo prepara instalaciones nuevas. No migra las tablas ni los datos del modelo anterior
(`products.products`, `author`, `gender`, `state_products` y `products_log`) en volumenes existentes.
Para conservar esos datos se requiere una migracion; no ejecutes `docker compose down -v` en ese caso.
## Esquema de compras, usuarios y stock

La creacion y actualizacion del esquema se centraliza en este proyecto. Payments y Products tienen Spring SQL Init desactivado; no crean tablas al iniciar.

El unico script de inicializacion es `init/01-create-database-schema.sql`. Incluye:

- Tablas y datos iniciales de cuentas, con la fecha de creacion del usuario.
- Catalogo de productos, movimientos de stock y registro de descuentos y devoluciones.
- Ventas de ejemplo, estados, identificador de descuento de stock, outbox y productos del usuario.

El script completo se ejecuta en una transaccion al crear un volumen nuevo. No debe ejecutarse
sobre una base existente: reiniciar el contenedor conserva sus datos y no repite el init.

El Compose independiente de Products monta este mismo archivo y define
`PLATON_PRODUCTS_ONLY=true`: crea solo el esquema `products`, con sus cinco tablas y datos
iniciales. El Compose compartido crea `account`, `products` y `payment` como antes.
El archivo usa instrucciones de `psql`, el cliente utilizado por la imagen oficial de PostgreSQL.

## RabbitMQ y eventos de compras

Desde DATABASE, el mismo comando levanta ambos servicios y espera la comprobacion de salud de RabbitMQ:

```powershell
docker compose up -d --wait
```

RabbitMQ queda en el contenedor `platon-rabbitmq`, puerto AMQP `5672`, panel `http://localhost:15672`, usuario `guest` y password `guest`. La configuracion local usa el mismo acceso de desarrollo que Payments y Products. Sus datos se conservan en el volumen `platon_rabbitmq_data`.

El broker carga `rabbitmq/definitions.json` al arrancar, mediante `rabbitmq/rabbitmq.conf`. Se inicializan el virtual host `/`, el usuario local, los permisos y estos recursos durables sin necesitar que arranquen los microservicios:

| Exchange topic | Cola | Routing key |
| --- | --- | --- |
| `platon.purchase.events` | `platon.purchase.created` | `purchase.created` |
| `platon.purchase.events` | `platon.products.purchase.validation` | `purchase.requested` |
| `platon.purchase.events` | `platon.products.payment.rejected` | `payment.rejected` |

La cola de validacion conserva su TTL de 30000 ms. Las colas exclusivas `purchase.availability.checked.<uuid>` son temporales y Payments las crea por instancia para recibir respuestas correlacionadas; no forman parte del init persistente.

Los microservicios usan los nombres publicados en Config Server. Ya no declaran exchanges ni colas durables. La topologia estatica pertenece a DATABASE; las colas y los mensajes persisten al recrear el contenedor mientras se conserve el volumen.

```powershell
docker compose ps
docker compose logs -f rabbitmq
docker exec platon-rabbitmq rabbitmq-diagnostics -q check_running
docker exec platon-rabbitmq rabbitmqctl list_queues name messages consumers
```

Para reiniciar solo RabbitMQ:

```powershell
docker compose restart rabbitmq
```

No se debe ejecutar al mismo tiempo otro RabbitMQ que publique `5672` o `15672`. En este equipo, el contenedor anterior `rabbitmq` y su volumen `rabbitmq_rabbitmq-data` se conservan detenidos como respaldo de la migracion a este Compose. Sus mensajes y recursos existentes se copiaron al volumen de Platon con el broker detenido, conservando el hostname `rabbitmq` y la misma imagen.

`docker compose down` conserva los datos. `docker compose down -v` elimina los volumenes de PostgreSQL y RabbitMQ de esta pila; se usa solo para un reinicio deliberado desde cero.