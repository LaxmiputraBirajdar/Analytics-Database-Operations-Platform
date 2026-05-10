-- CREATE TABLE products (
--     product_id INT PRIMARY KEY,
--     product_name TEXT NOT NULL,
--     category TEXT,
--     price NUMERIC(10,2),
--     stock_quantity INT,
--     reorder_level INT,
--     supplier_id INT
-- );


-- DROP TABLE IF EXISTS products;

-- CREATE TABLE products_raw (
--     product_id TEXT,
--     product_name TEXT,
--     category TEXT,
--     price TEXT,
--     stock_quantity TEXT,
--     reorder_level TEXT,
--     supplier_id TEXT
-- );


-- SELECT * FROM products_raw limit 5;


-- CREATE TABLE products AS
-- SELECT
--     product_id::INT,
--     product_name,
--     category,
--     price::NUMERIC(10,2),
--     stock_quantity::INT,
--     reorder_level::INT,
--     supplier_id::INT
-- FROM products_raw
-- WHERE product_id <> 'product_id';


-- DROP TABLE IF EXISTS products_raw;

-- SELECT * FROM products limit 5;



-- CREATE TABLE reorders_raw (
--     reorder_id TEXT,
--     product_id TEXT,
--     reorder_quantity TEXT,
--     reorder_date TEXT,
--     status TEXT
-- );


-- CREATE TABLE reorders AS
-- SELECT
--     reorder_id::INT AS reorder_id,
--     product_id::INT AS product_id,
--     reorder_quantity::INT AS reorder_quantity,
--     TO_DATE(reorder_date, 'YYYY-MM-DD') AS reorder_date,
--     status
-- FROM reorders_raw
-- WHERE reorder_id <> 'reorder_id';


-- select * from reorders limit 2



-- CREATE TABLE shipments_raw (
--     shipment_id TEXT,
--     product_id TEXT,
--     supplier_id TEXT,
--     quantity_received TEXT,
--     shipment_date TEXT
-- );

-- CREATE TABLE shipments AS
-- SELECT
--     shipment_id::INT AS shipment_id,
--     product_id::INT AS product_id,
--     supplier_id::INT AS supplier_id,
--     quantity_received::INT AS quantity_received,
--     TO_DATE(shipment_date, 'YYYY-MM-DD') AS shipment_date
-- FROM shipments_raw
-- WHERE shipment_id <> 'shipment_id';



-- select * from shipments limit 3


-- CREATE TABLE suppliers_raw (
--     supplier_id TEXT,
--     supplier_name TEXT,
--     contact_name TEXT,
--     email TEXT,
--     phone TEXT,
--     address TEXT
-- );

-- CREATE TABLE suppliers AS
-- SELECT
--     supplier_id::INT AS supplier_id,
--     supplier_name,
--     contact_name,
--     email,
--     phone,
--     address
-- FROM suppliers_raw
-- WHERE supplier_id <> 'supplier_id';


-- select * from suppliers limit 5


-- CREATE TABLE stock_entries_raw (
--     entry_id TEXT,
--     product_id TEXT,
--     change_quantity TEXT,
--     change_type TEXT,
--     entry_date TEXT
-- );

-- CREATE TABLE stock_entries AS
-- SELECT
--     entry_id::INT AS entry_id,
--     product_id::INT AS product_id,
--     change_quantity::INT AS change_quantity,
--     change_type,
--     TO_DATE(entry_date, 'YYYY-MM-DD') AS entry_date
-- FROM stock_entries_raw
-- WHERE entry_id <> 'entry_id';



-- select * from products limit 5;
select * from reorders limit 5;
-- select * from shipments limit 5;
select * from stock_entries limit 5;
-- select * from suppliers limit 5;


-- 1: Total supplieirs

select count(*) as total_suppliers from suppliers

-- 2: Total Products

select count(*) as total_products from products


-- 3: total categories

select count(distinct category) as total_categories from products

-- 4. total sales values made in last 3 months


SELECT ROUND(SUM(ABS(se.change_quantity) * p.price), 2) as total_sales_value_in_last_3_month
FROM stock_entries se
JOIN products p
  ON se.product_id = p.product_id
WHERE se.change_type = 'Sale'
  AND se.entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 months'
        FROM stock_entries
      );


-- 5 total restock values made in last 3 months

SELECT ROUND(SUM(ABS(se.change_quantity) * p.price), 2) as total_Restock_value_in_last_3_month
FROM stock_entries se
JOIN products p
  ON se.product_id = p.product_id
WHERE se.change_type = 'Restock'
  AND se.entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 month'
        FROM stock_entries
      );



SELECT 
    ROUND(SUM(ABS(se.change_quantity) * p.price), 2) 
        AS total_restock_value_last_3_months
FROM stock_entries se
JOIN products p
    ON se.product_id = p.product_id
WHERE se.change_type = 'Restock'
  AND se.entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 months'
        FROM stock_entries
        WHERE change_type = 'Restock'
      );



-- 6 No of products have less quatity that required and have not placed orders for them

select count(*) from products p where p.stock_quantity<p.reorder_level
and product_id not in (select distinct product_id from reorders where status='Pending' )


-- 7. Supplier contact details

select supplier_name, email, email, phone from suppliers



-- 8. Product with their supplier and stock details


select p.product_name, s.supplier_name, p.stock_quantity, p.reorder_level from products p 
join suppliers s
on p.supplier_id=s.supplier_id
order by product_name

-- 9. products needed laptop

select product_id, product_name, stock_quantity, reorder_level 
from products
where stock_quantity<reorder_level


-- Operational Task 

select * from products
select * from shipments
select * from stock_entries


CREATE OR REPLACE PROCEDURE add_new_product(
    p_name TEXT,
    p_category TEXT,
    p_price NUMERIC,
    p_stock INT,
    p_reorder INT,
    p_supplier INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_prod_id INT;
    new_shipment_id INT;
    new_entry_id INT;
BEGIN
    -- Generate new product_id
    SELECT COALESCE(MAX(product_id), 0) + 1
    INTO new_prod_id
    FROM products;

    -- Insert into products table
    INSERT INTO products (
        product_id,
        product_name,
        category,
        price,
        stock_quantity,
        reorder_level,
        supplier_id
    )
    VALUES (
        new_prod_id,
        p_name,
        p_category,
        p_price,
        p_stock,
        p_reorder,
        p_supplier
    );

    -- Generate new shipment_id
    SELECT COALESCE(MAX(shipment_id), 0) + 1
    INTO new_shipment_id
    FROM shipments;

    -- Insert into shipments table
    INSERT INTO shipments (
        shipment_id,
        product_id,
        supplier_id,
        quantity_received,
        shipment_date
    )
    VALUES (
        new_shipment_id,
        new_prod_id,
        p_supplier,
        p_stock,
        CURRENT_DATE
    );

    -- Generate new entry_id
    SELECT COALESCE(MAX(entry_id), 0) + 1
    INTO new_entry_id
    FROM stock_entries;

    -- Insert into stock_entries table
    INSERT INTO stock_entries (
        entry_id,
        product_id,
        change_quantity,
        change_type,
        entry_date
    )
    VALUES (
        new_entry_id,
        new_prod_id,
        p_stock,
        'Restock',
        CURRENT_DATE
    );
END;
$$;



CALL add_new_product(
    'Smart Watch',
    'Electronics',
    99.99,
    100,
    25,
    5
);

select * from products where product_name='laptop'

select * from shipments

select * from stock_entries  order by entry_date



SELECT COALESCE(
    ROUND(SUM(ABS(se.change_quantity) * p.price), 2),
    0
)
FROM stock_entries se
JOIN products p ON se.product_id = p.product_id
WHERE se.change_type = 'Sale'
  AND se.entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 months'
        FROM stock_entries
        WHERE change_type = 'Sale'
      );







SELECT COUNT(*)
FROM stock_entries
WHERE change_type = 'Sale'
  AND entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 months'
        FROM stock_entries
      );


SELECT ROUND(SUM(ABS(se.change_quantity) * p.price), 2) as total_sales_value_in_last_3_month
    FROM stock_entries se
    JOIN products p
    ON se.product_id = p.product_id
    WHERE se.change_type = 'Sale'
    AND se.entry_date >= (
            SELECT MAX(entry_date) - INTERVAL '3 months'
            FROM stock_entries
        );


SELECT ROUND(SUM(ABS(se.change_quantity) * p.price), 2) as total_sales_value_in_last_3_month
FROM stock_entries se
JOIN products p
  ON se.product_id = p.product_id
WHERE se.change_type = 'Sale'
  AND se.entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 months'
        FROM stock_entries
      );



SELECT ROUND(SUM(ABS(se.change_quantity) * p.price), 2) as total_Restock_value_in_last_3_month
FROM stock_entries se
JOIN products p
  ON se.product_id = p.product_id
WHERE se.change_type = 'Restock'
  AND se.entry_date >= (
        SELECT MAX(entry_date) - INTERVAL '3 months'
        FROM stock_entries
      );


-- 11. Product History (Finding Shipment, sales and purchases)
CREATE VIEW Product_inventory_history AS
select pih.*, pr.supplier_id from(
select product_id,
'Shipment' as record_type,
shipment_date as record_date, 
quantity_received as quantity,
null::TEXT change_type
from shipments
union all 
select product_id, 
'Stock Entry' as record_type, 
entry_date as record_date, 
change_quantity as quantity, 
change_type
from stock_entries) pih join products pr on pih.product_id=pr.product_id



select * 
from product_inventory_history
where product_id=123
order by record_date desc



-- 12 Place reorder

insert into reorders(reorder_id, product_id, reorder_quantity, reorder_date, status)
select max(reorder_id)+1, 101, 200, CURRENT_DATE, 'Ordered' from reorders

select * from reorders order by reorder_date desc



-- 13 Receive Order

CREATE OR REPLACE PROCEDURE mark_reorder_as_received(IN in_reorder_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    prod_id INT;
    qty INT;
    sup_id INT;
BEGIN
    -- Start transaction (implicit in procedure call)
    
    -- Get product_id and quantity from reorders
    SELECT product_id, reorder_quantity
    INTO prod_id, qty
    FROM reorders
    WHERE reorder_id = in_reorder_id;

    -- Get supplier_id from products
    SELECT supplier_id
    INTO sup_id
    FROM products
    WHERE product_id = prod_id;

    -- Update reorder status
    UPDATE reorders
    SET status = 'Received'
    WHERE reorder_id = in_reorder_id;

    -- Update stock in products table
    UPDATE products
    SET stock_quantity = stock_quantity + qty
    WHERE product_id = prod_id;

    -- Insert shipment record
    INSERT INTO shipments (
        product_id,
        supplier_id,
        quantity_received,
        shipment_date
    )
    VALUES (
        prod_id,
        sup_id,
        qty,
        CURRENT_DATE
    );

    -- Insert stock entry
    INSERT INTO stock_entries (
        product_id,
        change_quantity,
        change_type,
        entry_date
    )
    VALUES (
        prod_id,
        qty,
        'Restock',
        CURRENT_DATE
    );

END;
$$;


select * from reorders where reorder_id=2



CALL mark_reorder_as_received(2);


select * from reorders where product_id=27

select * from products where product_name='Scene Table'




SELECT COALESCE(
            ROUND(SUM(ABS(se.change_quantity) * p.price), 2),
            0
        )
        FROM stock_entries se
        JOIN products p ON se.product_id = p.product_id
        WHERE se.change_type = 'Restock'
        AND se.entry_date >= (
                SELECT MAX(entry_date) - INTERVAL '3 months'
                FROM stock_entries
                WHERE change_type' = 'Sale
            );


-- output - 1529482.99

SELECT 
    DATE_TRUNC('month', entry_date) AS month,
    SUM(price * change_quantity) AS total_sale_value
FROM 
    stock_entries se
JOIN 
    products p ON se.product_id = p.product_id
WHERE 
    se.change_type = 'sale' 
    AND entry_date >= (SELECT MAX(entry_date) - INTERVAL '3 months' FROM stock_entries)
GROUP BY 
    month
ORDER BY 
    month;


SELECT SUM(p.price * se.change_quantity) AS total_sale_value
FROM products p
JOIN stock_entries se ON p.product_id = se.product_id
WHERE se.change_type = 'sale'
AND se.entry_date >= (CURRENT_DATE - INTERVAL '3 months')
AND se.entry_date <= CURRENT_DATE;


  SELECT COALESCE(
            ROUND(SUM(ABS(se.change_quantity) * p.price), 2),
            0
        ) AS total_restock_value_in_last_3_month
        FROM stock_entries se
        JOIN products p
        ON se.product_id = p.product_id
        WHERE se.change_type = 'Restock'
        AND se.entry_date >= (
                SELECT MAX(entry_date) - INTERVAL '3 months'
                FROM stock_entries
                WHERE change_type = 'Restock'
            );

-- output - 84614.71


WITH daily_sales AS (
    SELECT
        entry_date,
        SUM(ABS(change_quantity)) AS total_sales
    FROM stock_entries
    WHERE change_type = 'sale'
    GROUP BY entry_date
)
SELECT entry_date, total_sales
FROM daily_sales
WHERE total_sales < (SELECT AVG(total_sales) FROM daily_sales);





