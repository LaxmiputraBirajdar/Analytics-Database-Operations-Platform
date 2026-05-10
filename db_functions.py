import pandas as pd
import numpy as np
import psycopg2
import os
from dotenv import load_dotenv
from decimal import Decimal

# Load environment variables
load_dotenv()

pass_word = os.getenv("password")



def connect_db():
    return psycopg2.connect(
    host="localhost",
    port="5432",
    database="analytics_ops_db",
    user="postgres",
    password=pass_word
    )

conn = connect_db()

cursor = conn.cursor()




def format_number(value):
    if isinstance(value, (int, float, Decimal)):
        return f"{value:,.2f}" if isinstance(value, (float, Decimal)) else f"{value:,}"
    return value


def get_basic_info(cursor):
    queries = {
    "Total Suppliers": "SELECT COUNT(*) AS count FROM suppliers",

    "Total Products": "SELECT COUNT(*) AS count FROM products",

    "Total Categories Dealing": "SELECT COUNT(DISTINCT category) AS count FROM products",

    "Total Sale Value (Last 3 Months)": """
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

    """,

    "Total Restock Value (Last 3 Months)": """
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
                WHERE change_type = 'Sale'
            );

    """,

    "Below Reorder & No Pending Reorders": """
    select count(*) from products p where p.stock_quantity<p.reorder_level
    and product_id not in (select distinct product_id from reorders where status='Pending' )
    """
    }


    result = {}

    for label, query in queries.items():
        cursor.execute(query)
        row = cursor.fetchone()
        result[label]=row[0]

    return result



def get_additonal_tables(cursor):
    queries = {
        "Suppliers Contact Details": "SELECT supplier_name, contact_name, email, phone FROM suppliers",

        "Products with Supplier and Stock": """
            SELECT 
                p.product_name,
                s.supplier_name,
                p.stock_quantity,
                p.reorder_level
            FROM products p
            JOIN suppliers s ON p.supplier_id = s.supplier_id
            ORDER BY p.product_name ASC
        """,

        "Products Needing Reorder": """
            SELECT product_name, stock_quantity, reorder_level
            FROM products
            WHERE stock_quantity <= reorder_level
        """
    }
    tables = {}

    for label, query in queries.items():
        cursor.execute(query)
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        tables[label] = (rows, columns)


    return tables
    

def get_categories(cursor):
    cursor.execute("select distinct category from products order by category")
    rows = cursor.fetchall()
    return [row[0] for row in rows]



def get_suppliers(cursor):
    cursor.execute("select distinct supplier_id, supplier_name from suppliers order by supplier_name")
    return cursor.fetchall()



def add_products(cursor, conn, p_name, p_category, p_price, p_stock, p_reorder, p_supplier):
    procedure_call = "CALL add_new_product(%s, %s, %s, %s, %s, %s)"
    params = (p_name, p_category, p_price, p_stock, p_reorder, p_supplier)
    cursor.execute(procedure_call, params)
    conn.commit()



def get_all_products(cursor):
    cursor.execute("SELECT product_id, product_name FROM products ORDER BY product_name")
    return cursor.fetchall()

def get_product_history(cursor, product_id):
    cursor.execute(
        """
        SELECT product_id, record_type, record_date, quantity, change_type
        FROM product_inventory_history
        WHERE product_id = %s
        ORDER BY record_date DESC
        """,
        (product_id,)
    )
    return cursor.fetchall()


def place_reorder(cursor, conn, product_id, reorder_quantity):
    query = """
    insert into reorders (reorder_id, product_id, reorder_quantity, reorder_date, status)
    select
    max(reorder_id)+1,
    %s,
    %s,
    CURRENT_DATE,
    'Ordered'
    from reorders
    """
    cursor.execute(query, (product_id, reorder_quantity))
    conn.commit()



def get_pending_reorders(cursor):
    cursor.execute("""
        SELECT r.reorder_id, p.product_name
        FROM reorders r
        JOIN products p ON r.product_id = p.product_id
        WHERE r.status = 'Ordered'
    """)
    return cursor.fetchall()


def mark_reorder_as_received(cursor, db, reorder_id):
    cursor.execute(
        "CALL mark_reorder_as_received(%s)",
        (reorder_id,)
    )
    db.commit()



def get_last_3_months_sales(cursor, product_id=None):
    query = """
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
    )
    AND (%s IS NULL OR se.product_id = %s);
    """
    cursor.execute(query, (product_id, product_id))
    return cursor.fetchone()[0]


