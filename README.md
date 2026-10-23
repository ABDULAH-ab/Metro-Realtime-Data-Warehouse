# Near-Real-Time Data Warehouse Prototype for METRO Pakistan

This project implements a near-real-time Data Warehouse (DW) prototype for METRO Cash & Carry. It uses the Polyzotis (2008) MESHJOIN algorithm in Java to perform stream-relation joins between incoming transactions and master data, stores enriched sales data in a MySQL Star Schema, and executes 10 OLAP analytical queries.

---

## Project Structure

```text
├── starschema.sql                  # DDL script to create Star Schema tables in MySQL
├── com/
│   └── sample/
│       └── LoadAndMeshJoin.java    # Java MESHJOIN ETL pipeline implementation
├── Analysis.sql                    # 10 OLAP analytical SQL queries
├── customers_data.csv              # Customers master data
├── products_data.csv               # Products, stores, and suppliers master data
├── transactions.csv                # Transactional stream data (~30,000 records)
└── README.md                       # Project documentation and execution guide
```

---

## Prerequisites

1. **MySQL Server** (version 8.0 or 9.x) running locally on port `3306`.
2. **Java Development Kit (JDK)** version 17 or higher.
3. **MySQL JDBC Driver**: `lib/mysql-connector-j-9.0.0.jar` (included in repository).

---

## Step-by-Step Execution Guide

### Step 1: Set Up MySQL Database Schema
Open MySQL Workbench (or the MySQL command line client) and execute the `starschema.sql` script:

```sql
-- Run in MySQL Workbench or CLI
SOURCE /path/to/starschema.sql;
```

This will drop any existing `METRO_DW` database and create:
- **Dimension Tables**: `Customers`, `Suppliers`, `Stores`, `Products`
- **Fact Table**: `SalesFact` (with composite key and foreign key constraints)

---

### Step 2: Compile and Run the MESHJOIN Java ETL

Open a terminal (PowerShell, Command Prompt, or Bash) in the project root directory:

#### 1. Compile:
```bash
javac -cp "lib/mysql-connector-j-9.0.0.jar;." com/sample/LoadAndMeshJoin.java
```

#### 2. Run:
```bash
java -cp "lib/mysql-connector-j-9.0.0.jar;." com.sample.LoadAndMeshJoin
```

#### 3. Execution:
- When prompted, enter your MySQL username (press `Enter` for `root`).
- Enter your MySQL password.

**What the program does:**
1. Loads dimension tables (`Customers`, `Suppliers`, `Stores`, `Products`) into MySQL.
2. Partitions master data into disk buffers ($b_R = 20$).
3. Streams transactions from `transactions.csv` in chunks ($w = 500$) into an in-memory Queue and Hash Table.
4. Traverses master data partitions cyclically, probes the Hash Table, enriches matched records (`total_sale = quantity * price`), and batch-inserts them into `SalesFact`.

---

### Step 3: Run OLAP Queries

Once the Java ETL finishes loading transactions into `SalesFact`, open [`Analysis.sql`](Analysis.sql) in MySQL Workbench and execute the queries:

- **Q1**: Top 5 revenue-generating products on weekdays vs. weekends with monthly drill-down.
- **Q2**: Quarterly revenue growth rate for each store using `LAG()`.
- **Q3**: Supplier sales contribution breakdown by store and product.
- **Q4**: Seasonal sales drill-down (Spring, Summer, Fall, Winter).
- **Q5**: Store-wise and supplier-wise month-to-month revenue volatility.
- **Q6**: Product affinity analysis (top 5 products purchased together).
- **Q7**: Hierarchical yearly revenue trends using `WITH ROLLUP`.
- **Q8**: H1 vs. H2 revenue and volume comparison per product.
- **Q9**: High-revenue spikes and outlier detection (> 2x daily average).
- **Q10**: Creation and analysis of the `STORE_QUARTERLY_SALES` view.

---

## Schema Overview

- **Fact Table**: `SalesFact` (`Order_ID`, `Order_Date`, `Customer_ID`, `Product_ID`, `Store_ID`, `Supplier_ID`, `Quantity_Ordered`, `Time_ID`, `Total_Sale`)
- **Dimension Tables**:
  - `Customers` (`Customer_ID`, `Customer_Name`, `Gender`)
  - `Products` (`Product_ID`, `Product_Name`, `Price`)
  - `Stores` (`Store_ID`, `Store_Name`)
  - `Suppliers` (`Supplier_ID`, `Supplier_Name`)
