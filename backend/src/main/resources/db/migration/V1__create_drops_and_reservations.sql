-- V1__create_drops_and_reservations.sql
-- Explicit migration script for drops and drop_reservations tables

CREATE TABLE IF NOT EXISTS drops (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    price DOUBLE PRECISION NOT NULL,
    image_url VARCHAR(500),
    restaurant_id INT NOT NULL,
    menu_item_id INT,
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP NOT NULL,
    total_slots INT NOT NULL,
    reserved_slots INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS drop_reservations (
    id SERIAL PRIMARY KEY,
    drop_id INT NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    customer_email VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    order_id INT
);

-- Indices for queries on drop_reservations
CREATE INDEX IF NOT EXISTS idx_drop_reservations_drop_id ON drop_reservations(drop_id);
CREATE INDEX IF NOT EXISTS idx_drop_reservations_order_id ON drop_reservations(order_id);
CREATE INDEX IF NOT EXISTS idx_drop_reservations_expires_at ON drop_reservations(expires_at);

-- Partial unique index to eliminate double-reservation concurrency gaps:
-- Prevents a user from having more than one active (HELD or CONFIRMED) slot for the same drop
CREATE UNIQUE INDEX IF NOT EXISTS idx_drop_res_active_unique 
ON drop_reservations (drop_id, customer_email) 
WHERE status IN ('HELD', 'CONFIRMED');
