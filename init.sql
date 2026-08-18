-- init.sql
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(258) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    failed_attempts INT DEFAULT 0
);