-- =========================================================================
-- MODULE 2: DATA CLEANING, TRANSFORMATION, AND ETRIAL PIPELINE VIA STAGING
-- Description: Standardizes dirty legacy rows from spreadsheet uploads into the warehouse.
-- =========================================================================

-- Create an internal operational buffer replica to prevent mutations on source data
SELECT * INTO DUMMY FROM ABC_10000;

-- 1. CLEANING AND STANDARDIZING SUPPLIER ENTITY VARIATIONS
UPDATE DUMMY
SET SUPPLIERNAME = LTRIM(RTRIM(
    CASE
        WHEN SUPPLIERNAME LIKE '%PlasticPro%' THEN 'PlasticPro Inc.'
        WHEN SUPPLIERNAME LIKE 'Steel Corp%' THEN 'SteelCorp'
        WHEN SUPPLIERNAME LIKE 'Copper Co%' THEN 'CopperCo'
        WHEN SUPPLIERNAME LIKE 'Alu Works%' then 'AluWorks'
        WHEN SUPPLIERNAME LIKE '%GlobalMetals%' THEN 'Global Metals'
        ELSE SUPPLIERNAME
    END
));

-- 2. TRANSFORMATION LOGIC FOR MACHINE DATA FIELDS
-- Deduplicates prefixes ('P1-', 'P2-'), dynamically extracts Plant Location IDs, 
-- and safely extracts maximum functional maintenance intervals.

UPDATE DUMMY
SET MACHINENAME = TRIM(REPLACE(REPLACE(MACHINENAME, 'P1-', ''), 'P2-', '')),
    MACHINETYPE = TRIM(MACHINETYPE);

-- 3. VALIDATING TEXT STRING CASTS IN NUMERIC VALUES
-- Clears raw special symbols ($ Currency signs, blank text padding, comma strings)
-- to transform initial batch logs safely into explicit DECIMALS.

SELECT INITIALQUANTITY,
       CAST(CAST(REPLACE(REPLACE(REPLACE(INITIALQUANTITY, '$', ''), ',', ''), ' ', '') AS FLOAT) AS DECIMAL(10,2)) 
FROM ABC_10000 
WHERE InitialQuantity NOT LIKE '%[^0-9.]%';


--CLEANING [, $ SCIENTIFIC,SPACE]
SELECT INITIALQUANTITY,CAST(CAST( REPLACE(REPLACE(REPLACE(INITIALQUANTITY,'$',''),',',''),' ','')AS  FLOAT) AS DECIMAL(10,2)) FROM ABC_10000



