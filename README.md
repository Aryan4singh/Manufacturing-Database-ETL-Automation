# Manufacturing Database: End-to-End ETL, Relational Migration & Automation Pipeline

## 📌 Project Overview
This project addresses a critical real-world manufacturing challenge: transitioning an expanding industrial plant from a fragmented, error-prone ecosystem of Excel spreadsheets to a centralized relational database system. 

As a **Data Analyst Portfolio Project**, this demonstrates an end-to-end data pipeline lifecycle: ingesting dirty staging data, modeling a normalized relational schema, writing complex multi-table transformation scripts, and implementing automated database triggers to guarantee operational business logic.

### The Business Challenge
The factory produces machinery components but was severely bottlenecked by data managed in standalone spreadsheets, resulting in:
* **Traceability Deficits:** No guaranteed unique identifiers for material batches, making root-cause defect tracking impossible.
* **Scheduling Anomalies:** Zero transactional links between assets, leading to scheduling line production runs on machines currently down for maintenance.
* **Dirty Structural Entries:** High data variance across rows (e.g., mixing metric variants like `Kg`, `KG`, and `Kilogram`, or naming variants like `SS-304` vs `Stainless 304`).

---

## 📊 Database Architecture & Data Modeling
The system transitions raw spreadsheet data into a highly normalized schema. This layout isolates structural dimensions (Masters) from high-velocity transactional tables (Facts), protecting data integrity across workflows.

### Entity-Relationship Diagram (ERD)
The database structure establishes clear primary/foreign key connections to capture the physical reality of the plant floor:

![Manufacturing Database ERD](assets/erd.png)

### Architectural Highlights:
* **The Analytics Hub (`PRODUCTIONORDERS`):** Acts as the central transactional hub, linking customer demands directly to machine assets, timelines, and operational statuses.
* **Many-to-Many Resolution (`PRODUCTIONMATERIALUSAGE`):** Resolves the complex relationship between production runs and specific material inventory batches, allowing granular tracking of exact component compositions.
* **Inventory Isolation:** Decouples `RAWMATERIALS` (the specifications, like grade) from `MATERIALINVENTORY` (the physical instance of a batch), enabling multi-vendor sourcing of identical materials.

---

## 📂 Repository Structure
To mirror enterprise development workflows, the production script is modularized into distinct execution phases:

```text
├── README.md               
│
├── assets/                 
│   └── erd.png            
│
├── data/                   
│   └── raw_factory_data.csv        
│
├── sql_scripts/            
│   ├── 1_schema_creation.sql
│   ├── 2_data_cleaning_etl.sql
│   ├── 3_data_migration.sql
│   └── 4_business_automation.sql
│
└── complete_implementation/  
    └── end_to_end_project.sql 

```

---

## 🛠️ Deep Dive: Code Implementation Showcase

### 1. Data Cleaning & Transformation (ETL Phase)
Data analysts spend the majority of their time cleaning data. This phase showcases T-SQL string profiling, trimming structural whitespace, handling messy customer entry data, and standardizing categorical strings into deterministic dimensions:

```sql
-- Standardizing multi-format naming variants into unified categorical entities
UPDATE DUMMY
SET SUPPLIERNAME = LTRIM(RTRIM(
    CASE
        WHEN SUPPLIERNAME LIKE '%PlasticPro%' THEN 'PlasticPro Inc.'
        WHEN SUPPLIERNAME LIKE 'Steel Corp%' THEN 'SteelCorp'
        WHEN SUPPLIERNAME LIKE 'Copper Co%' THEN 'CopperCo'
        WHEN SUPPLIERNAME LIKE 'Alu Works%' THEN 'AluWorks'
        WHEN SUPPLIERNAME LIKE '%GlobalMetals%' THEN 'Global Metals'
        ELSE SUPPLIERNAME
    END
));

-- Stripping non-numeric currency flags (\$) and text padding to execute clean numeric casting
SELECT INITIALQUANTITY,
       CAST(CAST(REPLACE(REPLACE(REPLACE(INITIALQUANTITY, '\$', ''), ',', ''), ' ', '') AS FLOAT) AS DECIMAL(10,2)) 
FROM ABC_10000 
WHERE InitialQuantity NOT LIKE '%[^0-9.]%';
```

### 2. Multi-Table Relational Migrations
This script handles the migration of complex dimensional records while generating unique IDs and mapping business entities securely using robust multi-table operations:

```sql
-- Complex Common Table Expression (CTE) used to cast data types and standardize 
-- non-uniform units of measure ('KGS', 'Kilogram' -> 'KG') during the migration pass
WITH CleanedInventory_CTE AS (
    SELECT 
        LEFT(RAWMATERIALBATCHID, 7) AS RAWMATERIALBATCHID,
        TRY_CONVERT(DATE, RECEIVEDATE, 105) AS RECEIVEDDATE,
        CAST(CAST(REPLACE(REPLACE(REPLACE(INITIALQUANTITY, '\$', ''), ',', ''), ' ', '') AS FLOAT) AS DECIMAL(10,2)) AS INITIAL_QUANTITY,
        CASE
            WHEN UPPER(TRIM(UNIT)) IN ('KG','KILOGRAM','KGS') THEN 'KG'
            WHEN UPPER(TRIM(UNIT)) IN ('M','METERS','METER') THEN 'M'
            WHEN UPPER(TRIM(UNIT)) IN ('PCS','PIECES') THEN 'PCS'
            ELSE NULL
        END AS STANDARDUNIT, 
        SUPPLIERNAME, MATERIALNAME, MATERIALGRADE
    FROM DUMMY
)
INSERT INTO MATERIALINVENTORY(ORIGINALBATCHID, MATERIALID, SUPPLIERID, RECEIVED_DATE, INITIAL_QUANTITY, UNIT)
SELECT 
    T.RAWMATERIALBATCHID, M.MATERIALID, S.SUPPLIERID, T.RECEIVEDDATE, T.INITIAL_QUANTITY, T.STANDARDUNIT 
FROM CleanedInventory_CTE AS T 
INNER JOIN SUPPLIERS AS S ON S.SUPPLIERNAME = T.SUPPLIERNAME
INNER JOIN RAWMATERIALS AS M ON M.MATERIALGRADE = T.MATERIALGRADE AND M.MATERIALNAME = T.MATERIALNAME;
```

### 3. Business Automation & Integrity Rules (Triggers)
To protect operations without requiring external software code, the database leverages automated transactional rules directly on table edits:

* **The Anti-Double Booking Engine (`TRG_CHECKMACHINESCHEDULE`)**: Dynamically intercepts incoming production orders and checks active timelines. If a machine is assigned to overlapping production timelines, it halts execution and issues a rolling transaction rejection.
* **The Failsafe Inventory Enforcer (`TRG_UPDATEMATERIALREMAINING`)**: Automatically recalculates remaining inventory quantities upon usage updates. If any material volume breaks below 0, it aborts the process to prevent data corruption.
* **Proactive Supply Chain Alerts (`TRG_LOWSTOCK`)**: Instantly logs a new procurement requisition entry into the tracking table if a material stock level drops below a 500-unit threshold.

---

## 📈 Business Insights Enabled by This Schema
By centralizing data, this database allows data analysts to answer critical operational questions in sub-seconds using analytical SQL queries:
1. **Overall Equipment Effectiveness (OEE):** Tracks machine availability by evaluating production time durations against downtime entries from logs.
2. **Supplier Quality Scorecards:** Evaluates defect trends per vendor by joining `QUALITYCHECKS` data directly back to initial batch suppliers.
3. **Inventory Burn Rates:** Aggregates rolling inventory requirements over historical run dates to streamline procurement timelines.

---

## 🛠️ Technical Tool Stack
* **Database Engine:** Microsoft SQL Server (T-SQL)
* **IDE / Tooling:** SQL Server Management Studio (SSMS)
* **Modeling Tool:** Microsoft SQL Server Database Diagram Designer
  
