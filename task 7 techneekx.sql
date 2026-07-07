-- 1. DROP EXTANT TABLES TO ENSURE IDEMPOTENCY
DROP TABLE IF EXISTS api_logs CASCADE;
DROP TABLE IF EXISTS invoices CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

-- 2. CREATE SCHEMAS
CREATE TABLE companies (
    company_id INT PRIMARY KEY,
    company_name VARCHAR(100),
    tier VARCHAR(20) DEFAULT 'Free',
    created_at DATE
);

CREATE TABLE users (
    user_id INT PRIMARY KEY,
    company_id INT REFERENCES companies(company_id),
    full_name VARCHAR(100),
    role VARCHAR(50),
    status VARCHAR(20) DEFAULT 'Active',
    joined_at DATE
);

CREATE TABLE invoices (
    invoice_id INT PRIMARY KEY,
    company_id INT REFERENCES companies(company_id),
    amount_usd DECIMAL(10, 2),
    status VARCHAR(20), -- 'Paid', 'Overdue', 'Refunded'
    billing_date DATE
);

CREATE TABLE api_logs (
    log_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(user_id),
    endpoint VARCHAR(100),
    response_code INT,
    latency_ms INT,
    requested_at TIMESTAMP
);

-- 3. INJECT ENTERPRISE DUMMY DATA
INSERT INTO companies VALUES 
(1, 'Techneek X Corp', 'Enterprise', '2025-01-15'),
(2, 'Aura Flow Inc', 'Growth', '2025-03-10'),
(3, 'Alpha Beta LLC', 'Free', '2025-05-01'),
(4, 'Delta Data Corp', 'Enterprise', '2025-06-20');

INSERT INTO users VALUES 
(501, 1, 'Hardik Techneek', 'Admin', 'Active', '2025-01-16'),
(502, 1, 'Sarah Jenkins', 'Developer', 'Active', '2025-01-20'),
(503, 1, 'John Doe', 'Developer', 'Suspended', '2025-02-01'),
(504, 2, 'Jane Miller', 'Admin', 'Active', '2025-03-11'),
(505, 2, 'Mike Ross', 'Developer', 'Active', '2025-03-15'),
(506, 3, 'Alex Mercer', 'Admin', 'Active', '2025-05-02'),
(507, 4, 'Bruce Wayne', 'Admin', 'Active', '2025-06-21');

INSERT INTO invoices VALUES 
(901, 1, 5000.00, 'Paid', '2025-02-01'),
(902, 1, 5000.00, 'Paid', '2025-03-01'),
(903, 1, 5200.00, 'Paid', '2025-04-01'),
(904, 1, 5200.00, 'Overdue', '2025-05-01'),
(905, 2, 1200.00, 'Paid', '2025-04-10'),
(906, 2, 1200.00, 'Paid', '2025-05-10'),
(907, 4, 8000.00, 'Paid', '2025-07-01'),
(908, 3, 0.00, 'Paid', '2025-06-01');

INSERT INTO api_logs (user_id, endpoint, response_code, latency_ms, requested_at) VALUES 
(501, '/v1/auth', 200, 45, '2026-06-01 09:00:00'),
(502, '/v1/data/export', 200, 1200, '2026-06-01 09:05:00'),
(502, '/v1/data/export', 500, 3400, '2026-06-01 09:06:00'),
(505, '/v1/auth', 401, 30, '2026-06-01 09:10:00'),
(505, '/v1/auth', 200, 42, '2026-06-01 09:11:00'),
(502, '/v1/dashboard', 200, 150, '2026-06-01 09:15:00'),
(501, '/v1/settings', 200, 80, '2026-06-01 10:00:00'),
(504, '/v1/dashboard', 200, 210, '2026-06-01 10:02:00'),
(506, '/v1/free-feature', 403, 15, '2026-06-01 10:05:00'),
(502, '/v1/dashboard', 200, 180, '2026-06-01 10:20:00'),
(502, '/v1/dashboard', 200, 130, '2026-06-01 10:22:00');

SELECT * FROM companies;
SELECT * FROM users;
SELECT * FROM invoices;
SELECT * FROM api_logs;

-- QUERY 1
SELECT company_id,billing_date,amount_usd,SUM(amount_usd)  OVER (ORDER BY billing_date) AS total_revenue FROM invoices WHERE status = 'Paid' ORDER BY billing_date;

-- QUERY 2
SELECT company_id,SUM(amount_usd) AS total_paid FROM invoices WHERE status = 'Paid' AND company_id IN (SELECT company_id FROM invoices WHERE status = 'Overdue') GROUP BY company_id;

-- QUERY 3
SELECT c.tier, AVG(i.amount_usd) AS avg_invoice_amount FROM companies c JOIN invoices i ON c.company_id = i.company_id GROUP BY c.tier ORDER BY avg_invoice_amount DESC;

-- QUERY 4
SELECT user_id,endpoint,requested_at,LAG(requested_at) OVER(PARTITION BY user_id ORDER BY requested_at) AS previous_request FROM api_logs;

-- QUERY 5
SELECT * FROM (SELECT log_id,user_id,endpoint,latency_ms,DENSE_RANK() OVER (PARTITION BY endpoint ORDER BY latency_ms DESC) AS rnk FROM api_logs) WHERE rnk<=2;

-- QUERY 6
SELECT user_id,requested_at,COUNT(*) OVER(PARTITION BY user_id ORDER BY requested_at) AS running_requests FROM api_logs WHERE DATE(requested_at) = '2026-06-01' ORDER BY user_id,requested_at;

-- QUERY 7 
WITH error_developers AS (SELECT u.user_id,u.company_id,u.full_name FROM users u JOIN api_logs a ON u.user_id = a.user_id WHERE u.role = 'Developer' AND a.response_code = 500) SELECT ed.user_id,ed.full_name,c.company_name FROM error_developers ed JOIN companies c ON ed.company_id = c.company_id WHERE c.tier = 'Enterprise';

-- QUERY 8

SELECT * FROM companies c WHERE NOT EXISTS (SELECT 1 FROM users u JOIN api_logs a ON u.user_id = a.user_id WHERE u.company_id = c.company_id);

-- QUERY 9 
SELECT user_id,AVG(latency_ms) AS avg_latency FROM api_logs GROUP BY user_id HAVING AVG(latency_ms) > (SELECT AVG(latency_ms) FROM api_logs);

-- QUERY 10 
SELECT endpoint,ROUND(100.0 * SUM (CASE WHEN response_code <> 200 THEN 1 ELSE 0 END)/ COUNT(*),2)AS error_rate FROM api_logs GROUP BY endpoint;

-- QUERY 11
SELECT user_id,DATE(requested_at) AS day, COUNT(*) AS failed_attempts FROM api_logs WHERE response_code IN (401,403) GROUP BY user_id,DATE (requested_at) HAVING COUNT(*) > 2;

-- QUERY 12
SELECT EXTRACT(HOUR FROM requested_at) AS hour,COUNT(*) AS requests FROM api_logs GROUP BY hour ORDER BY hour;

-- QUERY 13 
SELECT c.company_name,SUM(CASE WHEN i.status = 'Paid' THEN i.amount_usd ELSE 0 END )AS paid_amount,SUM(CASE WHEN i.status = 'Overdue' THEN i.amount_usd ELSE 0 END ) AS overdue_amount FROM companies c LEFT JOIN  invoices i ON c.company_id = i.company_id
GROUP BY c.company_name;

-- QUERY 14
SELECT u.user_id,u.full_name,a.endpoint,a.requested_at FROM users u JOIN api_logs a ON u.user_id = a.user_id WHERE u.status  = 'Suspended';

-- QUERY 15 
DELETE FROM api_logs WHERE latency_ms < 50 AND response_code = 200;