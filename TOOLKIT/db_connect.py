"""
db_connect.py
=============
Reusable database connection template.
Copy into any project. Fill in your credentials. Done.
Never rewrite connection strings again.
"""

import pandas as pd
import sqlalchemy


# ── FILL THESE IN FOR EACH PROJECT ───────────────────────────────────────
DB_CONFIG = {
    "host": "localhost",  # e.g. localhost or your server IP
    "port": 5432,  # default PostgreSQL port
    "database": "your_database",  # your database name
    "user": "postgres",  # your username
    "password": "your_password",  # your password
}
# ─────────────────────────────────────────────────────────────────────────


def get_engine(config=DB_CONFIG):
    """
    Returns a SQLAlchemy engine connected to your database.
    Use this when you need to run multiple queries efficiently.
    """
    url = (
        f"postgresql://{config['user']}:{config['password']}"
        f"@{config['host']}:{config['port']}/{config['database']}"
    )
    return sqlalchemy.create_engine(url)


def query(sql, config=DB_CONFIG):
    """
    Run a SQL query and return a pandas DataFrame.
    Use this for quick one-off queries.

    Example:
        from db_connect import query
        df = query('SELECT * FROM sales_orders WHERE status = \\'Completed\\'')
    """
    engine = get_engine(config)
    return pd.read_sql(sql, engine)


def pull_table(table_name, config=DB_CONFIG):
    """
    Pull an entire table into a DataFrame.
    Use this for reference/lookup tables.

    Example:
        from db_connect import pull_table
        df_reps = pull_table('reps')
    """
    return query(f"SELECT * FROM {table_name}", config)


def test_connection(config=DB_CONFIG):
    """
    Test your connection before running analysis.
    Always run this first on a new project.
    """
    try:
        engine = get_engine(config)
        with engine.connect() as conn:
            result = pd.read_sql("SELECT 1 AS connected", conn)
        print(f"Connected to {config['database']} on {config['host']}")
        return True
    except Exception as e:
        print(f"Connection failed: {e}")
        return False


# ── USAGE EXAMPLES ────────────────────────────────────────────────────────
# Run this file directly to test your connection:
#   python db_connect.py
#
# In your notebook or script:
#   from db_connect import query, pull_table, get_engine
#
#   df_sales    = pull_table('sales_orders')
#   df_reps     = pull_table('reps')
#   df_custom   = query('SELECT * FROM orders WHERE year = 2024')
#   engine      = get_engine()   # for pd.read_sql with custom options

if __name__ == "__main__":
    test_connection()
