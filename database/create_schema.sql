
-- 1. Create the database if it does not exist
IF DB_ID('FinanceData') IS NULL
    CREATE DATABASE FinanceData;
GO

-- 2. Select the database
USE FinanceData;
GO

-- 3. Create the Finance schema if it does not exist
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'Finance'
)
    EXEC('CREATE SCHEMA Finance');
GO

-- 4. Create the Symbols table
IF OBJECT_ID('Finance.Symbols', 'U') IS NULL
BEGIN
    CREATE TABLE Finance.Symbols (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        SymbolName VARCHAR(50) NOT NULL,
        Description NVARCHAR(255) NULL
    );
END;
GO

-- 5. Create the HistoricalPrices table
IF OBJECT_ID('Finance.HistoricalPrices', 'U') IS NULL
BEGIN
    CREATE TABLE Finance.HistoricalPrices (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        SymbolID UNIQUEIDENTIFIER NOT NULL,
        PriceDate DATE NOT NULL,
        OpenPrice DECIMAL(18,4),
        ClosePrice DECIMAL(18,4),
        HighPrice DECIMAL(18,4),
        LowPrice DECIMAL(18,4),
        Volume BIGINT,
        PriceChange DECIMAL(18,4),

        CONSTRAINT FK_HistoricalPrices_Symbols
            FOREIGN KEY (SymbolID)
            REFERENCES Finance.Symbols(ID)
    );
END;
GO

-- 6. Create a unique index for historical prices
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_HistoricalPrices_Date_ID'
      AND object_id = OBJECT_ID('Finance.HistoricalPrices')
)
BEGIN
    CREATE UNIQUE INDEX IX_HistoricalPrices_Date_ID
        ON Finance.HistoricalPrices(PriceDate, SymbolID);
END;
GO

-- 7. Create the CalculatedIndicator table
IF OBJECT_ID('Finance.CalculatedIndicator', 'U') IS NULL
BEGIN
    CREATE TABLE Finance.CalculatedIndicator (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        SymbolID UNIQUEIDENTIFIER NOT NULL,
        IndicatorName VARCHAR(50) NOT NULL,
        CalculatedValue DECIMAL(18,4),
        CalculationDate DATE NOT NULL,

        CONSTRAINT FK_CalculatedIndicator_Symbols
            FOREIGN KEY (SymbolID)
            REFERENCES Finance.Symbols(ID)
    );
END;
GO

-- 8. Create the IntraDayIntervals table
IF OBJECT_ID('Finance.IntraDayIntervals', 'U') IS NULL
BEGIN
    CREATE TABLE Finance.IntraDayIntervals (
        IntervalSecond INT NOT NULL PRIMARY KEY,
        IntervalName VARCHAR(10) NOT NULL UNIQUE
    );
END;
GO

-- 9. Seed the IntraDayIntervals table
MERGE INTO Finance.IntraDayIntervals AS T
USING (
    VALUES
        (60, '1min'),
        (300, '5min'),
        (3600, '1hour')
) AS S(IntervalSecond, IntervalName)
ON T.IntervalSecond = S.IntervalSecond

WHEN MATCHED
    AND T.IntervalName <> S.IntervalName THEN
    UPDATE SET IntervalName = S.IntervalName

WHEN NOT MATCHED BY TARGET THEN
    INSERT (IntervalSecond, IntervalName)
    VALUES (S.IntervalSecond, S.IntervalName);
GO

-- 10. Create the IntraDayPrices table
IF OBJECT_ID('Finance.IntraDayPrices', 'U') IS NULL
BEGIN
    CREATE TABLE Finance.IntraDayPrices (
        ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
        SymbolID UNIQUEIDENTIFIER NOT NULL,
        IntervalSecond INT NOT NULL,
        PriceDateTime DATETIME2(0) NOT NULL,
        OpenPrice DECIMAL(18,4) NOT NULL,
        ClosePrice DECIMAL(18,4) NOT NULL,
        HighPrice DECIMAL(18,4) NOT NULL,
        LowPrice DECIMAL(18,4) NOT NULL,
        Volume BIGINT NOT NULL,
        IngestedTime DATETIME2(0) NOT NULL
            DEFAULT SYSUTCDATETIME(),

        CONSTRAINT FK_IntraDayPrices_Symbols
            FOREIGN KEY (SymbolID)
            REFERENCES Finance.Symbols(ID),

        CONSTRAINT FK_IntraDayPrices_Intervals
            FOREIGN KEY (IntervalSecond)
            REFERENCES Finance.IntraDayIntervals(IntervalSecond)
    );
END;
GO

-- 11. Create a unique index for intraday prices
IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE name = 'IX_IntraDayPrices_Symbol_Interval_Time'
      AND object_id = OBJECT_ID('Finance.IntraDayPrices')
)
BEGIN
    CREATE UNIQUE INDEX IX_IntraDayPrices_Symbol_Interval_Time
        ON Finance.IntraDayPrices(
            SymbolID,
            IntervalSecond,
            PriceDateTime
        );
END;
GO
