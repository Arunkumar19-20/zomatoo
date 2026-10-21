-- V2__create_processed_webhook_events.sql
-- Table to store processed webhook event IDs with primary key unique constraint for idempotency

CREATE TABLE IF NOT EXISTS processed_webhook_events (
    event_id VARCHAR(255) PRIMARY KEY,
    event_type VARCHAR(255),
    processed_at TIMESTAMP NOT NULL
);
