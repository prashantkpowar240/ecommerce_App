========================================
CAR SERVICE DATABASE SCHEMA
========================================

-- Use schema (optional but recommended)
CREATE SCHEMA IF NOT EXISTS car_service;

SET search_path TO car_service;

========================================
1. USERS TABLE (REFERENCE)
========================================
-- Assuming users exist in ecommerce system
-- This is a reference structure (can be external)

CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(15),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

========================================
2. SERVICE TYPES
========================================

CREATE TABLE IF NOT EXISTS service_types (
    service_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed Data
INSERT INTO service_types (name, description) VALUES
('oil_change', 'Engine oil replacement'),
('car_wash', 'Exterior and interior cleaning'),
('repair', 'General repair services'),
('full_service', 'Complete car servicing')
ON CONFLICT (name) DO NOTHING;

========================================
3. SERVICE REQUESTS
========================================

CREATE TABLE IF NOT EXISTS service_requests (
    service_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    car_model VARCHAR(100) NOT NULL,
    car_number VARCHAR(20) NOT NULL,
    service_type_id INT NOT NULL,
    pickup_address TEXT NOT NULL,
    service_date DATE NOT NULL,
    notes TEXT,
    status VARCHAR(20) DEFAULT 'BOOKED',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_user
        FOREIGN KEY(user_id)
        REFERENCES users(user_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_service_type
        FOREIGN KEY(service_type_id)
        REFERENCES service_types(service_type_id),

    CONSTRAINT chk_status
        CHECK (status IN ('BOOKED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'))
);

========================================
4. SERVICE STATUS HISTORY (AUDIT LOG)
========================================

CREATE TABLE IF NOT EXISTS service_status_history (
    id SERIAL PRIMARY KEY,
    service_id UUID NOT NULL,
    status VARCHAR(20),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_service
        FOREIGN KEY(service_id)
        REFERENCES service_requests(service_id)
        ON DELETE CASCADE
);

========================================
5. INDEXES (PERFORMANCE)
========================================

CREATE INDEX idx_service_user_id 
ON service_requests(user_id);

CREATE INDEX idx_service_status 
ON service_requests(status);

CREATE INDEX idx_service_date 
ON service_requests(service_date);

========================================
6. TRIGGER: AUTO UPDATE updated_at
========================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = CURRENT_TIMESTAMP;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_timestamp
BEFORE UPDATE ON service_requests
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

========================================
7. TRIGGER: STATUS AUDIT LOG
========================================

CREATE OR REPLACE FUNCTION log_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO service_status_history(service_id, status)
        VALUES (NEW.service_id, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_status_change
AFTER UPDATE ON service_requests
FOR EACH ROW
EXECUTE FUNCTION log_status_change();

========================================
8. SAMPLE QUERY
========================================

-- Get all services for a user
SELECT * FROM service_requests
WHERE user_id = 'USER_UUID';

-- Get completed services
SELECT * FROM service_requests
WHERE status = 'COMPLETED';

========================================
NOTES
========================================
- UUID requires extension:
  CREATE EXTENSION IF NOT EXISTS "pgcrypto";

- Designed for microservices architecture
- Can be deployed via Kubernetes + Helm + Terraform
- Compatible with CI/CD pipelines (Liquibase / Flyway)

========================================