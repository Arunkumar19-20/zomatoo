-- V3__create_drop_waitlist.sql
-- FIFO waitlist for sold-out drops. A freed slot is handed directly to the oldest WAITING entry.

CREATE TABLE IF NOT EXISTS drop_waitlist (
    id SERIAL PRIMARY KEY,
    drop_id INT NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    customer_email VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    offered_at TIMESTAMP,
    reservation_id INT
);

CREATE INDEX IF NOT EXISTS idx_drop_waitlist_drop_status ON drop_waitlist(drop_id, status, id);
CREATE INDEX IF NOT EXISTS idx_drop_waitlist_reservation ON drop_waitlist(reservation_id);

-- A customer can have at most one live (WAITING or OFFERED) entry per drop.
CREATE UNIQUE INDEX IF NOT EXISTS idx_drop_waitlist_active_unique
ON drop_waitlist (drop_id, lower(customer_email))
WHERE status IN ('WAITING', 'OFFERED');
