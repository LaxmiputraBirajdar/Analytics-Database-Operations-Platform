import pandas as pd
from dotenv import load_dotenv
import os
from openai import OpenAI
import re

# Load environment variables
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found in .env file")

# Initialize OpenAI client
client = OpenAI(api_key=OPENAI_API_KEY)


def clean_sql(sql):
    # Remove markdown ```sql ``` blocks if present
    sql = re.sub(r"```sql|```", "", sql, flags=re.IGNORECASE)
    return sql.strip()


def is_safe_sql(sql):
    sql = clean_sql(sql)
    sql_lower = sql.lower()

    return (
        sql_lower.startswith("select")
        and "insert" not in sql_lower
        and "update" not in sql_lower
        and "delete" not in sql_lower
        and "drop" not in sql_lower
        and "alter" not in sql_lower
    )


def ask_llm_for_sql(question, schema_description):
    prompt = f"""
You are a senior data analyst.

Database schema:
{schema_description}

Rules:
- Generate ONLY ONE SQL query
- Use SELECT only
- Do not modify data
- Do not use stored procedures
- Query should be suitable for PostreSQL

User question:
{question}

Return only SQL.
"""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "user", "content": prompt}
        ],
        temperature=0
    )

    return response.choices[0].message.content.strip()


def run_chat_query(cursor, question, schema_description):
    raw_sql = ask_llm_for_sql(question, schema_description)
    sql = clean_sql(raw_sql)

    if not is_safe_sql(sql):
        raise ValueError(f"Unsafe SQL detected:\n{sql}")

    cursor.execute(sql)
    data = cursor.fetchall()
    columns = [desc[0] for desc in cursor.description]

    return sql, pd.DataFrame(data, columns=columns)



def generate_insights(question, df):
    if df.empty:
        return ["No data returned for this question."]

    summary = {
        "rows": len(df),
        "columns": list(df.columns),
        "sample_rows": df.head(5).to_dict(orient="records")
    }

    prompt = f"""
You are a senior business analyst.

User question:
{question}

Query result summary:
- Total rows: {summary['rows']}
- Columns: {summary['columns']}
- Sample rows: {summary['sample_rows']}

Task:
- Provide only 2 clear business insights
- Use bullet points
- Be concise
- Avoid technical jargon
- Do NOT repeat raw numbers unless meaningful
"""

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3
    )

    text = response.choices[0].message.content.strip()

    # Convert to bullet list
    insights = [
        line.strip("-• ").strip()
        for line in text.split("\n")
        if line.strip()
    ]

    return insights


