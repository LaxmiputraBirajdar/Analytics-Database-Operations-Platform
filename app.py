import streamlit as st
import pandas as pd
from db_functions import (connect_db, get_basic_info, get_additonal_tables, add_products, get_categories, get_suppliers, get_all_products, get_product_history, place_reorder, get_pending_reorders, mark_reorder_as_received, get_last_3_months_sales, format_number)
from chat_with_data import run_chat_query, generate_insights




# side bar
st.sidebar.title("Inventory management")
option = st.sidebar.radio("Select Option:", ["Basic Information", "Operational Task", "Chat With Data"])

  



SCHEMA_DESCRIPTION = """
Tables:
- products(product_id, product_name, category, price, stock_quantity, reorder_level, supplier_id)
- suppliers(supplier_id, supplier_name, contact_name, email, phone, address)
- stock_entries(entry_id, product_id, change_quantity, change_type, entry_date)
- reorders(reorder_id, product_id, reorder_quantity, reorder_date, status)
- Shipment(shipment_id, product_id, supplier_id, quantity_received, shipment_date)
"""


#Main Space
st.title("Inventory Decision Intelligence System")
conn = connect_db()
cursor = conn.cursor()


# -------------------- BASIC INFORMATION PAGE --------------------


if option == "Basic Information":
    st.header("Basic Metrics")

    basic_info = get_basic_info(cursor)

    cols = st.columns(3)
    keys = list(basic_info.keys())

    for i in range(3):
        cols[i].metric(
            label=keys[i],
            value=format_number(basic_info[keys[i]])
        )

    cols = st.columns(3)

    for i in range(3, 6):
        cols[i - 3].metric(
            label=keys[i],
            value=format_number(basic_info[keys[i]])
        )

    st.divider()


    # Fetch and display detailed tables
    tables = get_additonal_tables(cursor)

    for table, (data, columns) in tables.items():
        st.header(table)
        df = pd.DataFrame(data, columns=columns)
        st.dataframe(df)
        st.divider()

elif option == "Operational Task":
    st.header("Operational task")
    selected_task = st.selectbox("Choose an task", ["Add New Product", "Product History", "Place Reorder", "Receive Order"])

    if selected_task == "Add New Product":
        st.header("Add New Product")

        categories = get_categories(cursor)
        suppliers = get_suppliers(cursor)

        with st.form("Add_Product_Form"):
            product_name = st.text_input("Product_Name")
            product_category = st.selectbox("Category", categories)
            product_price = st.number_input("Price", min_value=0.00)
            product_stock = st.number_input("Stock Quantity", min_value=0, step=1)
            product_level = st.number_input("Reorder Level", min_value=0, step=1)

            supplier_ids = [s[0] for s in suppliers]
            supplier_names = [s[1] for s in suppliers]

            supplier_id = st.selectbox(
            "Supplier",
            options=supplier_ids,
            format_func=lambda x: supplier_names[supplier_ids.index(x)])

            submitted = st.form_submit_button("Add Product")
            if submitted:
                if not product_name:
                    st.error("Please enter the product name")
                else:
                    try:
                        add_products(cursor, conn, product_name, product_category, product_price, product_stock, product_level, supplier_id)
                        st.success(f"Product {product_name} added successfully ")
                    except Exception as e:
                        st.error(f"Error adding the product {e}")
        
    elif selected_task == "Product History":
        st.header("Product Inventory History")

        products = get_all_products(cursor)

        # products -> [(id, name)]
        product_ids = [p[0] for p in products]
        product_names = [p[1] for p in products]

        selected_product_name = st.selectbox(
            "Select a product",
            options=product_names
        )

        if selected_product_name:
            selected_product_id = product_ids[
                product_names.index(selected_product_name)
            ]

            history_data = get_product_history(cursor, selected_product_id)

            if history_data:
                df = pd.DataFrame(
                    history_data,
                    columns=["product_id", "record_type", "record_date", "quantity", "change_type"]
                )
                st.dataframe(df)
            else:
                st.info("No history found for the selected product")

    elif selected_task == "Place Reorder":
        st.header("Place an Reorder")

        products = get_all_products(cursor)
        product_names = [p[1] for p in products]
        product_ids = [p[0] for p in products]

        selected_product_name = st.selectbox("Select An product", options=product_names)
        reorder_qty = st.number_input("Reorder Quantity", min_value=1, step=1)

        if st.button("Place Reorder"):
            if not selected_product_name:
                st.error("Please Select an Product")
            elif reorder_qty <= 0:
                st.error("Reorder Quantity must be greater than 0")
            else:
                selected_product_id = product_ids[product_names.index(selected_product_name)]
                try:
                    place_reorder(cursor, conn, selected_product_id, reorder_qty)
                    st.success(
                        f"Order placed for {selected_product_name} with quantity {reorder_qty}"
                    )
                except Exception as e:
                    st.error(f"Error Placing reorder {e}")
          


    # ---------------- RECEIVING AN ORDER ----------------

    elif selected_task == "Receive Order":
        st.header("Mark Reorder as Received")

        # Fetch orders in Ordered Stage
        pending_reorders = get_pending_reorders(cursor)

        if not pending_reorders:
            st.info("No Pending Orders to Receive.")
        else:
            reorder_ids = [r[0] for r in pending_reorders]
            reorder_labels = [
                f"ID {r[0]} - {r[1]}"
                for r in pending_reorders
            ]

            selected_label = st.selectbox(
                "Select Reorder to mark As Received",
                options=reorder_labels
            )

            if selected_label:
                selected_reorder_id = reorder_ids[
                    reorder_labels.index(selected_label)
                ]

                if st.button("Mark as Received"):
                    try:
                        mark_reorder_as_received(
                            cursor,
                            conn,
                            selected_reorder_id
                        )
                        st.success(
                            f"Reorder ID {selected_reorder_id} marked as received"
                        )
                    except Exception as e:
                        st.error(f"Error: {e}")

elif option == "Chat With Data":
    st.header("Chat with Inventory Data")

    question = st.text_area(
        "Ask a question about inventory, sales, suppliers, or reorders",
        height=100,
        placeholder="e.g. Show top 5 products by sales in last 3 months"
    )

    if st.button("Ask"):
        try:
            sql, df = run_chat_query(
                cursor,
                question,
                SCHEMA_DESCRIPTION
            )

            st.subheader("Generated SQL")
            st.code(sql, language="sql")

            st.subheader("Result")
            st.dataframe(df)

            # 🔥 NEW: Insights section
            st.subheader("Key Insights")
            insights = generate_insights(question, df)

            for insight in insights:
                st.markdown(f"- {insight}")

        except Exception as e:
            st.error(str(e))

    


