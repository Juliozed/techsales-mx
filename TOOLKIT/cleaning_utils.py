"""
cleaning_utils.py
=================
Standard data cleaning functions for analyst work.
Copy into any project. Import what you need.
Real data is always messy — these functions handle the most common problems.
"""

import pandas as pd
import numpy as np


# ══════════════════════════════════════════════════════════════════════════
# 1. DATA PROFILING — always run this first on any new dataset
# ══════════════════════════════════════════════════════════════════════════


def profile(df, name="DataFrame"):
    """
    Full data quality report in one function call.
    Run this on every new dataset before touching anything.

    Example:
        from cleaning_utils import profile
        profile(df_sales, 'Sales Orders')
    """
    print(f"\n{'=' * 50}")
    print(f"PROFILE: {name}")
    print(f"{'=' * 50}")
    print(f"Shape:      {df.shape[0]:,} rows  x  {df.shape[1]} columns")
    print(f"Memory:     {df.memory_usage(deep=True).sum() / 1024**2:.1f} MB")

    print(f"\n--- DATA TYPES ---")
    print(df.dtypes.to_string())

    print(f"\n--- MISSING VALUES ---")
    missing = df.isnull().sum()
    missing_pct = (missing / len(df) * 100).round(2)
    missing_df = pd.DataFrame({"count": missing, "pct_%": missing_pct})
    missing_df = missing_df[missing_df["count"] > 0]
    if len(missing_df) == 0:
        print("No missing values")
    else:
        print(missing_df.to_string())

    print(f"\n--- DUPLICATES ---")
    dupes = df.duplicated().sum()
    print(f"Duplicate rows: {dupes:,}")

    print(f"\n--- NUMERIC SUMMARY ---")
    print(df.describe().round(2).to_string())

    print(f"\n--- CATEGORICAL COLUMNS ---")
    cat_cols = df.select_dtypes(include="object").columns
    for col in cat_cols:
        n_unique = df[col].nunique()
        print(f"\n{col} ({n_unique} unique):")
        print(df[col].value_counts().head(5).to_string())

    print(f"\n{'=' * 50}\n")


# ══════════════════════════════════════════════════════════════════════════
# 2. COLUMN CLEANING — fix the most common column problems
# ══════════════════════════════════════════════════════════════════════════


def clean_column_names(df):
    """
    Standardize all column names to lowercase with underscores.
    Removes spaces, special characters, leading/trailing spaces.

    Before: 'Sales Rep Name', 'Revenue (MXN)', ' Order ID '
    After:  'sales_rep_name', 'revenue_mxn',  'order_id'

    Example:
        df = clean_column_names(df)
    """
    df = df.copy()
    df.columns = (
        df.columns.str.strip()
        .str.lower()
        .str.replace(r"[^a-z0-9]+", "_", regex=True)
        .str.strip("_")
    )
    return df


def clean_text_column(df, col):
    """
    Fix common text problems: strip whitespace, fix casing, remove extra spaces.
    Use on any column that will be used for filtering or joining.

    Example:
        df = clean_text_column(df, 'status')
        df = clean_text_column(df, 'rep_name')
    """
    df = df.copy()
    df[col] = df[col].astype(str).str.strip().str.replace(r"\s+", " ", regex=True)
    return df


def fix_currency_column(df, col):
    """
    Convert currency strings to numeric.
    Handles: '$1,234.56', '1,234', '$1234', '1.234,56' (European format)

    Before: '$25,990.00'
    After:  25990.0

    Example:
        df = fix_currency_column(df, 'revenue')
        df = fix_currency_column(df, 'cost')
    """
    df = df.copy()
    df[col] = (
        df[col]
        .astype(str)
        .str.replace(r"[$,\s]", "", regex=True)
        .str.replace(r"[^\d.-]", "", regex=True)
    )
    df[col] = pd.to_numeric(df[col], errors="coerce")
    return df


def fix_percentage_column(df, col):
    """
    Convert percentage strings to decimal (0.0 to 1.0).

    Before: '45.5%'
    After:  0.455

    Example:
        df = fix_percentage_column(df, 'profit_pct')
    """
    df = df.copy()
    df[col] = df[col].astype(str).str.replace("%", "", regex=False).str.strip()
    df[col] = pd.to_numeric(df[col], errors="coerce") / 100
    return df


def fix_date_column(df, col, format=None):
    """
    Convert any date string or object to proper datetime.
    Handles most common formats automatically.

    Example:
        df = fix_date_column(df, 'order_date')
        df = fix_date_column(df, 'order_date', format='%d/%m/%Y')
    """
    df = df.copy()
    df[col] = pd.to_datetime(df[col], format=format, errors="coerce")
    n_failed = df[col].isnull().sum()
    if n_failed > 0:
        print(f"Warning: {n_failed} dates could not be parsed in '{col}'")
    return df


def extract_date_parts(df, date_col):
    """
    Extract year, month, day, weekday, quarter from a datetime column.
    Run after fix_date_column.

    Adds columns: year, month, month_name, day, weekday, quarter, period

    Example:
        df = fix_date_column(df, 'order_date')
        df = extract_date_parts(df, 'order_date')
    """
    df = df.copy()
    df["year"] = df[date_col].dt.year
    df["month"] = df[date_col].dt.month
    df["month_name"] = df[date_col].dt.strftime("%b %Y")
    df["day"] = df[date_col].dt.day
    df["weekday"] = df[date_col].dt.day_name()
    df["quarter"] = df[date_col].dt.quarter
    df["period"] = df[date_col].dt.strftime("%Y-%m")
    return df


# ══════════════════════════════════════════════════════════════════════════
# 3. NULL HANDLING — deal with missing values properly
# ══════════════════════════════════════════════════════════════════════════


def fill_nulls(df, fills):
    """
    Fill nulls in multiple columns at once.

    fills: dict of {column: fill_value}

    Example:
        df = fill_nulls(df, {
            'revenue': 0,
            'rep_name': 'Unknown',
            'notes': '',
        })
    """
    df = df.copy()
    for col, value in fills.items():
        if col in df.columns:
            df[col] = df[col].fillna(value)
        else:
            print(f"Warning: column '{col}' not found")
    return df


def drop_nulls_in(df, required_cols):
    """
    Drop rows where any of the specified columns are null.
    Use for columns that must never be missing (IDs, dates, etc.)

    Example:
        df = drop_nulls_in(df, ['order_id', 'order_date', 'revenue'])
    """
    before = len(df)
    df = df.dropna(subset=required_cols)
    dropped = before - len(df)
    if dropped > 0:
        print(f"Dropped {dropped:,} rows with nulls in: {required_cols}")
    return df


# ══════════════════════════════════════════════════════════════════════════
# 4. DEDUPLICATION — remove repeated rows properly
# ══════════════════════════════════════════════════════════════════════════


def remove_duplicates(df, key_cols=None, keep="first"):
    """
    Remove duplicate rows.

    key_cols: columns to check for duplicates — None means all columns
    keep:     'first' keeps earliest, 'last' keeps latest, False drops all

    Example:
        df = remove_duplicates(df)                        # exact duplicates
        df = remove_duplicates(df, key_cols=['order_id']) # duplicate order IDs
    """
    before = len(df)
    df = df.drop_duplicates(subset=key_cols, keep=keep)
    dropped = before - len(df)
    if dropped > 0:
        print(f"Removed {dropped:,} duplicate rows")
    else:
        print("No duplicates found")
    return df


# ══════════════════════════════════════════════════════════════════════════
# 5. OUTLIER DETECTION — find and flag extreme values
# ══════════════════════════════════════════════════════════════════════════


def flag_outliers(df, col, method="iqr", threshold=1.5):
    """
    Add a boolean column flagging outliers.
    Adds column: {col}_is_outlier

    method: 'iqr' (standard) or 'zscore' (normal distributions)
    threshold: 1.5 = mild outliers, 3.0 = extreme outliers only

    Example:
        df = flag_outliers(df, 'revenue')
        df = flag_outliers(df, 'revenue', method='zscore', threshold=3.0)
    """
    df = df.copy()
    if method == "iqr":
        Q1 = df[col].quantile(0.25)
        Q3 = df[col].quantile(0.75)
        IQR = Q3 - Q1
        lower = Q1 - threshold * IQR
        upper = Q3 + threshold * IQR
        df[f"{col}_is_outlier"] = (df[col] < lower) | (df[col] > upper)
    elif method == "zscore":
        z = np.abs((df[col] - df[col].mean()) / df[col].std())
        df[f"{col}_is_outlier"] = z > threshold

    n_outliers = df[f"{col}_is_outlier"].sum()
    print(
        f"Flagged {n_outliers:,} outliers in '{col}' ({n_outliers / len(df) * 100:.1f}%)"
    )
    return df


# ══════════════════════════════════════════════════════════════════════════
# 6. FULL CLEAN PIPELINE — run everything at once
# ══════════════════════════════════════════════════════════════════════════


def run_clean_pipeline(df, config):
    """
    Run a full cleaning pipeline from a config dictionary.
    Define your cleaning steps once, run them in order.

    config example:
    {
        'clean_column_names': True,
        'text_columns':   ['status', 'rep_name', 'region'],
        'currency_cols':  ['revenue', 'cost', 'profit'],
        'pct_cols':       ['profit_pct'],
        'date_cols':      ['order_date'],
        'date_parts_col': 'order_date',
        'fill_nulls':     {'revenue': 0, 'rep_name': 'Unknown'},
        'required_cols':  ['order_id', 'order_date'],
        'dedup_key':      ['order_id'],
    }

    Example:
        from cleaning_utils import run_clean_pipeline

        config = {
            'clean_column_names': True,
            'text_columns': ['status'],
            'currency_cols': ['revenue'],
            'date_cols': ['order_date'],
            'date_parts_col': 'order_date',
            'required_cols': ['order_id'],
        }
        df_clean = run_clean_pipeline(df_raw, config)
    """
    print("Running cleaning pipeline...")

    if config.get("clean_column_names"):
        df = clean_column_names(df)
        print("  ✓ Column names standardized")

    for col in config.get("text_columns", []):
        df = clean_text_column(df, col)
    if config.get("text_columns"):
        print(f"  ✓ Text columns cleaned: {config['text_columns']}")

    for col in config.get("currency_cols", []):
        df = fix_currency_column(df, col)
    if config.get("currency_cols"):
        print(f"  ✓ Currency columns fixed: {config['currency_cols']}")

    for col in config.get("pct_cols", []):
        df = fix_percentage_column(df, col)
    if config.get("pct_cols"):
        print(f"  ✓ Percentage columns fixed: {config['pct_cols']}")

    for col in config.get("date_cols", []):
        df = fix_date_column(df, col)
    if config.get("date_cols"):
        print(f"  ✓ Date columns fixed: {config['date_cols']}")

    if config.get("date_parts_col"):
        df = extract_date_parts(df, config["date_parts_col"])
        print(f"  ✓ Date parts extracted from: {config['date_parts_col']}")

    if config.get("fill_nulls"):
        df = fill_nulls(df, config["fill_nulls"])
        print(f"  ✓ Nulls filled")

    if config.get("required_cols"):
        df = drop_nulls_in(df, config["required_cols"])

    if config.get("dedup_key"):
        df = remove_duplicates(df, key_cols=config["dedup_key"])

    print(f"Pipeline complete: {df.shape[0]:,} rows, {df.shape[1]} columns")
    return df
