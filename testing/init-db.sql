-- Create additional test databases
CREATE DATABASE IF NOT EXISTS app2;
CREATE DATABASE IF NOT EXISTS app3;

-- Setup app1 database (already created by MySQL container)
USE app1;
CREATE TABLE IF NOT EXISTS cache_data (id INT PRIMARY KEY, data TEXT);
CREATE TABLE IF NOT EXISTS cache_pages (id INT PRIMARY KEY, page_data TEXT);
CREATE TABLE IF NOT EXISTS sessions (id INT PRIMARY KEY, session_data TEXT);
CREATE TABLE IF NOT EXISTS users (id INT PRIMARY KEY, username VARCHAR(50), email VARCHAR(100));
INSERT INTO users VALUES (1, 'alice', 'alice@example.com'), (2, 'bob', 'bob@example.com');
INSERT INTO cache_data VALUES (1, 'cached content 1'), (2, 'cached content 2');
INSERT INTO sessions VALUES (1, 'session abc'), (2, 'session xyz');

-- Setup app2 database
USE app2;
CREATE TABLE IF NOT EXISTS temp_files (id INT PRIMARY KEY, filename VARCHAR(255));
CREATE TABLE IF NOT EXISTS cache (id INT PRIMARY KEY, data TEXT);
CREATE TABLE IF NOT EXISTS posts (id INT PRIMARY KEY, title VARCHAR(255), content TEXT);
INSERT INTO posts VALUES (1, 'Hello World', 'This is the first post'), (2, 'Second Post', 'This is another post');
INSERT INTO temp_files VALUES (1, 'temp1.txt'), (2, 'temp2.txt');

-- Setup app3 database
USE app3;
CREATE TABLE IF NOT EXISTS products (id INT PRIMARY KEY, name VARCHAR(100), price DECIMAL(10,2));
CREATE TABLE IF NOT EXISTS orders (id INT PRIMARY KEY, product_id INT, quantity INT);
INSERT INTO products VALUES (1, 'Widget', 19.99), (2, 'Gadget', 29.99);
INSERT INTO orders VALUES (1, 1, 5), (2, 2, 3);
