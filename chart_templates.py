"""
chart_templates.py
==================
Copy-paste chart templates for data analysts.
Swap the data and labels — everything else stays the same.
No memorization needed. Just copy, paste, modify 3 lines.
"""

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import seaborn as sns

# ── Global style — run this once at the top of any notebook ──────────────
plt.rcParams.update(
    {
        "font.family": "Arial",
        "axes.facecolor": "#F8F9FA",
        "figure.facecolor": "white",
        "axes.grid": True,
        "grid.alpha": 0.3,
    }
)
BLUE = "#2E75B6"
NAVY = "#003049"
GREEN = "#1E6B3C"
ORANGE = "#F77F00"
RED = "#D62828"
GRAY = "#595959"


# ══════════════════════════════════════════════════════════════════════════
# TEMPLATE 1 — BAR CHART
# Use for: comparing categories (revenue by rep, orders by region)
# ══════════════════════════════════════════════════════════════════════════
def bar_chart(
    data,
    x_col,
    y_col,
    title,
    xlabel,
    ylabel,
    color=BLUE,
    value_fmt="${:,.0f}",
    figsize=(10, 6),
    save_as=None,
):
    """
    data     : DataFrame with your data
    x_col    : column name for the x-axis (categories)
    y_col    : column name for the bar heights (numbers)
    title    : chart title
    xlabel   : x-axis label
    ylabel   : y-axis label
    value_fmt: format string for labels on bars — '${:,.0f}' or '{:.1f}%'
    save_as  : filename to save e.g. 'revenue_by_rep.png' (None = don't save)
    """
    fig, ax = plt.subplots(figsize=figsize)

    bars = ax.bar(data[x_col], data[y_col], color=color, edgecolor="white", width=0.6)

    # Value labels on top of each bar
    for bar in bars:
        height = bar.get_height()
        ax.text(
            bar.get_x() + bar.get_width() / 2,
            height * 1.01,
            value_fmt.format(height),
            ha="center",
            va="bottom",
            fontsize=10,
            fontweight="bold",
            color=NAVY,
        )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15, color=NAVY)
    ax.set_xlabel(xlabel, fontsize=11, color=GRAY)
    ax.set_ylabel(ylabel, fontsize=11, color=GRAY)
    ax.tick_params(axis="x", rotation=15)

    plt.tight_layout()
    if save_as:
        plt.savefig(save_as, dpi=150, bbox_inches="tight")
        print(f"Saved: {save_as}")
    plt.show()


# ══════════════════════════════════════════════════════════════════════════
# TEMPLATE 2 — LINE CHART
# Use for: trends over time (monthly revenue, growth rate)
# ══════════════════════════════════════════════════════════════════════════
def line_chart(
    data,
    x_col,
    y_cols,
    title,
    xlabel,
    ylabel,
    colors=None,
    figsize=(12, 5),
    rotation=30,
    label_every=1,
    save_as=None,
):
    """
    y_cols      : single column name OR list of column names for multiple lines
    colors      : list of colors for each line (optional)
    rotation    : angle of x-axis labels — 0=flat, 45=diagonal, 90=vertical
    label_every : show every nth x-axis label — use 3 for 36 months, 2 for 24 months
    save_as     : filename to save e.g. 'trend.png' (None = don't save)
    """
    if isinstance(y_cols, str):
        y_cols = [y_cols]
    if colors is None:
        colors = [BLUE, ORANGE, GREEN, RED, GRAY]

    fig, ax = plt.subplots(figsize=figsize)

    for i, col in enumerate(y_cols):
        ax.plot(
            data[x_col],
            data[col],
            marker="o",
            linewidth=2.5,
            color=colors[i % len(colors)],
            label=col,
            markersize=5,
        )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15, color=NAVY)
    ax.set_xlabel(xlabel, fontsize=11, color=GRAY)
    ax.set_ylabel(ylabel, fontsize=11, color=GRAY)

    # Smart x-axis label spacing
    all_labels = list(range(len(data)))
    shown = all_labels[::label_every]
    ax.set_xticks(shown)
    ax.set_xticklabels(
        data[x_col].iloc[::label_every],
        rotation=rotation,
        ha="right" if rotation > 0 else "center",
    )

    if len(y_cols) > 1:
        ax.legend(fontsize=10)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    plt.tight_layout()
    if save_as:
        plt.savefig(save_as, dpi=150, bbox_inches="tight")
        print(f"Saved: {save_as}")
    plt.show()


# ══════════════════════════════════════════════════════════════════════════
# TEMPLATE 3 — SCATTER PLOT
# Use for: correlation between two numeric variables
# ══════════════════════════════════════════════════════════════════════════
def scatter_plot(
    data,
    x_col,
    y_col,
    title,
    xlabel,
    ylabel,
    color_col=None,
    color=BLUE,
    figsize=(9, 6),
    save_as=None,
):
    """
    color_col: optional column to color-code dots by category
    """
    fig, ax = plt.subplots(figsize=figsize)

    if color_col:
        categories = data[color_col].unique()
        colors = [BLUE, ORANGE, GREEN, RED, GRAY]
        for i, cat in enumerate(categories):
            subset = data[data[color_col] == cat]
            ax.scatter(
                subset[x_col],
                subset[y_col],
                label=cat,
                color=colors[i % len(colors)],
                alpha=0.7,
                s=60,
                edgecolors="white",
                linewidth=0.5,
            )
        ax.legend(title=color_col, fontsize=9)
    else:
        ax.scatter(
            data[x_col],
            data[y_col],
            color=color,
            alpha=0.6,
            s=60,
            edgecolors="white",
            linewidth=0.5,
        )

    # Add trend line
    import numpy as np

    z = np.polyfit(data[x_col], data[y_col], 1)
    p = np.poly1d(z)
    ax.plot(
        sorted(data[x_col]),
        p(sorted(data[x_col])),
        "--",
        color=RED,
        linewidth=1.5,
        alpha=0.7,
        label="Trend",
    )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15, color=NAVY)
    ax.set_xlabel(xlabel, fontsize=11, color=GRAY)
    ax.set_ylabel(ylabel, fontsize=11, color=GRAY)

    plt.tight_layout()
    if save_as:
        plt.savefig(save_as, dpi=150, bbox_inches="tight")
        print(f"Saved: {save_as}")
    plt.show()


# ══════════════════════════════════════════════════════════════════════════
# TEMPLATE 4 — HISTOGRAM
# Use for: distribution of one numeric variable (revenue spread, order sizes)
# ══════════════════════════════════════════════════════════════════════════
def histogram(
    data, col, title, xlabel, bins=30, color=BLUE, figsize=(10, 5), save_as=None
):
    """
    bins: number of bars in the histogram — more bins = more detail
    """
    fig, ax = plt.subplots(figsize=figsize)

    ax.hist(
        data[col].dropna(), bins=bins, color=color, edgecolor="white", linewidth=0.5
    )

    # Add mean and median lines
    mean_val = data[col].mean()
    median_val = data[col].median()

    ax.axvline(
        mean_val,
        color=RED,
        linestyle="--",
        linewidth=2,
        label=f"Mean: ${mean_val:,.0f}",
    )
    ax.axvline(
        median_val,
        color=ORANGE,
        linestyle="--",
        linewidth=2,
        label=f"Median: ${median_val:,.0f}",
    )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15, color=NAVY)
    ax.set_xlabel(xlabel, fontsize=11, color=GRAY)
    ax.set_ylabel("Frequency", fontsize=11, color=GRAY)
    ax.legend(fontsize=10)

    plt.tight_layout()
    if save_as:
        plt.savefig(save_as, dpi=150, bbox_inches="tight")
        print(f"Saved: {save_as}")
    plt.show()


# ══════════════════════════════════════════════════════════════════════════
# TEMPLATE 5 — HEATMAP
# Use for: correlation matrix, or two-way table (rep × region revenue)
# ══════════════════════════════════════════════════════════════════════════
def heatmap(data, title, fmt=".0f", cmap="Blues", figsize=(10, 7), save_as=None):
    """
    data : a pivot table or correlation matrix DataFrame
    fmt  : number format inside cells — '.0f' integers, '.2f' 2 decimals, '.1%' percentages
    cmap : color scheme — 'Blues', 'RdYlGn', 'coolwarm', 'YlOrRd'
    """
    fig, ax = plt.subplots(figsize=figsize)

    sns.heatmap(
        data,
        annot=True,
        fmt=fmt,
        cmap=cmap,
        linewidths=0.5,
        linecolor="white",
        cbar_kws={"shrink": 0.8},
        ax=ax,
    )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15, color=NAVY)
    ax.tick_params(axis="x", rotation=30)
    ax.tick_params(axis="y", rotation=0)

    plt.tight_layout()
    if save_as:
        plt.savefig(save_as, dpi=150, bbox_inches="tight")
        print(f"Saved: {save_as}")
    plt.show()


# ══════════════════════════════════════════════════════════════════════════
# TEMPLATE 6 — BOX PLOT
# Use for: outlier detection, spread comparison across groups
# ══════════════════════════════════════════════════════════════════════════
def box_plot(
    data, x_col, y_col, title, xlabel, ylabel, color=BLUE, figsize=(10, 6), save_as=None
):
    """
    x_col: categorical column (rep, region, status)
    y_col: numeric column to show distribution of (revenue, days_to_ship)
    """
    fig, ax = plt.subplots(figsize=figsize)

    # Get category order by median value (highest median first)
    order = data.groupby(x_col)[y_col].median().sort_values(ascending=False).index

    sns.boxplot(
        data=data,
        x=x_col,
        y=y_col,
        order=order,
        color=color,
        width=0.5,
        linewidth=1.5,
        flierprops=dict(marker="o", markerfacecolor=RED, markersize=4, alpha=0.5),
        ax=ax,
    )

    ax.set_title(title, fontsize=14, fontweight="bold", pad=15, color=NAVY)
    ax.set_xlabel(xlabel, fontsize=11, color=GRAY)
    ax.set_ylabel(ylabel, fontsize=11, color=GRAY)
    ax.tick_params(axis="x", rotation=15)

    plt.tight_layout()
    if save_as:
        plt.savefig(save_as, dpi=150, bbox_inches="tight")
        print(f"Saved: {save_as}")
    plt.show()


# ══════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE — which chart for which question
# ══════════════════════════════════════════════════════════════════════════
"""
QUESTION                                    CHART           FUNCTION
──────────────────────────────────────────────────────────────────────
Which rep/region has most revenue?          Bar chart       bar_chart()
How has revenue trended month over month?   Line chart      line_chart()
Does units sold correlate with profit?      Scatter plot    scatter_plot()
What does the spread of order sizes look?   Histogram       histogram()
Revenue by rep AND region in one table?     Heatmap         heatmap()
Which region has the most outlier orders?   Box plot        box_plot()
"""
