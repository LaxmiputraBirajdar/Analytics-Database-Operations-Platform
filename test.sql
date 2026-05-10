CREATE TABLE employee_sales (
    emp_id        INT,
    emp_name      VARCHAR(50),
    department    VARCHAR(30),
    city          VARCHAR(30),
    sale_amount   INT,
    sale_date     DATE,
    manager_id    INT
);


select * from employee_sales


INSERT INTO employee_sales VALUES
-- IT department
(1, 'Amit',   'IT', 'Pune',     5000, '2024-01-10', 101),
(1, 'Amit',   'IT', 'Pune',     7000, '2024-01-15', 101),
(2, 'Ravi',   'IT', 'Mumbai',   4000, '2024-01-12', 101),
(3, 'Neha',   'IT', 'Pune',     NULL, '2024-01-20', 101),

-- HR department
(4, 'Sneha',  'HR', 'Delhi',    3000, '2024-01-05', 102),
(5, 'Kiran',  'HR', 'Delhi',    2000, '2024-01-25', 102),
(5, 'Kiran',  'HR', 'Delhi',    2500, '2024-01-28', 102),

-- Sales department
(6, 'Rahul',  'Sales', 'Mumbai', 10000, '2024-01-03', 103),
(6, 'Rahul',  'Sales', 'Mumbai', 15000, '2024-01-18', 103),
(7, 'Pooja',  'Sales', 'Pune',    8000, '2024-01-22', 103),
(8, 'Ankit',  'Sales', 'Pune',    NULL, '2024-01-26', NULL),

-- Support department (small data)
(9, 'Sonal',  'Support', 'Chennai', 1000, '2024-01-08', 104);





