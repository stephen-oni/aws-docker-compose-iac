-- init.sql
CREATE DATABASE IF NOT EXISTS my_website_db;
USE my_website_db;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    failed_attempts INT DEFAULT 0
);