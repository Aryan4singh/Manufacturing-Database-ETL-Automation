-- =========================================================================
-- MODULE 4: PRODUCTION OPERATIONAL CONTROL AUTOMATION & DATABASE TRIGGERS
-- Description: Implements strict validation engines to prevent operational anomalies.
-- =========================================================================

-- -------------------------------------------------------------------------
-- BUSINESS RULE 1: FAIL-SAFE REWORK AUTOMATION
-- If a finished batch fails quality control, instantly flag the production order as 'REWORK REQUIRED'.
-- -------------------------------------------------------------------------
CREATE TRIGGER UPDATEPRODUCTIONSTATUS_ONFAIL
ON QUALITYCHECKS
AFTER INSERT
AS 
BEGIN
    SET NOCOUNT ON;
    UPDATE P
    SET P.STATUS = 'REWORK REQUIRED'
    FROM INSERTED AS I
    INNER JOIN PRODUCTIONORDERS AS P ON I.PRODUCTIONORDERID = P.PRODUCTIONID
    WHERE I.RESULT = 'FAILED';
END;
GO

-- -------------------------------------------------------------------------
-- BUSINESS RULE 2: REAL-TIME TRANSACTIONAL INVENTORY ENFORCEMENT
-- Tracks changes to material usage, updates inventory balances, and blocks production transactions if stock drops below 0.
-- -------------------------------------------------------------------------
CREATE TRIGGER TRG_UPDATEMATERIALREMAINING
ON PRODUCTIONMATERIALUSAGE
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Step A: Restore inventory for items that were updated or replaced
    IF EXISTS(SELECT 1 FROM DELETED)
    BEGIN
        UPDATE MI
        SET MI.REMAINING_QUANTITY = MI.REMAINING_QUANTITY + D.QUANTITY_USED
        FROM DELETED AS D 
        INNER JOIN MATERIALINVENTORY AS MI ON D.BATCHID = MI.BATCHID AND D.MATERIALID = MI.MATERIALID;
    END

    -- Step B: Deduct stock for new material utilization
    UPDATE MI
    SET MI.REMAINING_QUANTITY = MI.REMAINING_QUANTITY - I.QUANTITY_USED
    FROM MATERIALINVENTORY AS MI 
    INNER JOIN INSERTED AS I ON I.BATCHID = MI.BATCHID AND I.MATERIALID = MI.MATERIALID;

    -- Step C: Roll back the transaction if inventory falls below zero
    IF EXISTS (
        SELECT 1
        FROM MATERIALINVENTORY AS MI 
        INNER JOIN INSERTED AS I ON I.BATCHID = MI.BATCHID AND I.MATERIALID = MI.MATERIALID
        WHERE MI.REMAINING_QUANTITY < 0
    )
    BEGIN 
        RAISERROR('TRANSACTION DENIED: Insufficient raw material inventory in stock.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END 
END;


-- -------------------------------------------------------------------------
-- BUSINESS RULE 3: ANTI-DOUBLE-BOOKING ENGINE (MACHINE OVERLAP PREVENTION)
-- Validates time allocations to block overlapping schedules on the same asset.
-- -------------------------------------------------------------------------
CREATE TRIGGER TRG_CHECKMACHINESCHEDULE
ON PRODUCTIONORDERS 
AFTER INSERT, UPDATE
AS 
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM INSERTED AS I 
        JOIN PRODUCTIONORDERS AS P ON I.ASSIGNEDMACHINEID = P.ASSIGNEDMACHINEID
            AND I.PRODUCTIONID <> P.PRODUCTIONID -- Exclude self-updates
        WHERE I.STATUS NOT IN ('COMPLETED', 'CANCELLED')
          AND P.STATUS NOT IN ('COMPLETED', 'CANCELLED')
          AND (I.SCHEDULEDSTARTDATE < P.SCHEDULEENDDATE) -- Structural Overlap Intersection Check
          AND (I.SCHEDULEENDDATE > P.SCHEDULEDSTARTDATE)
    )
    BEGIN 
        RAISERROR ('SCHEDULE CONFLICT: The assigned machine asset is already booked for an overlapping run.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO

-- -------------------------------------------------------------------------
-- BUSINESS RULE 4: PROACTIVE SUPPLY CHAIN ALARM INDEXING
-- Automatically generates a purchasing ticket if a material batch falls below 500 units.
-- -------------------------------------------------------------------------
CREATE TRIGGER TRG_LOWSTOCK
ON MATERIALINVENTORY 
AFTER INSERT, UPDATE
AS 
BEGIN 
    SET NOCOUNT ON;
    INSERT INTO MATERIALLOWSTOCKLOG(MATERIALID, MATERIALNAME, MATERIALGRADE, ALERTTRIGGERQUANTITY, QUANTITYORDEER)
    SELECT 
        I.MATERIALID, M.MATERIALNAME, M.MATERIALGRADE, I.REMAINING_QUANTITY, 
        (4000 - I.REMAINING_QUANTITY) -- Calculates target reorder volume dynamically
    FROM INSERTED AS I
    INNER JOIN RAWMATERIALS AS M ON I.MATERIALID = M.MATERIALID
    WHERE I.REMAINING_QUANTITY < 500;
END;

