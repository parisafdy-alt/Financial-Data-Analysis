CREATE DATABASE FinanceData;
GO

USE FinanceData;
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name='Finance')
    EXEC('CREATE SCHEMA Finance');
GO


IF OBJECT_ID('Finance.Symbols', 'U') IS NULL
CREATE TABLE Finance.Symbols(
    ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),  -- NEWID -> snowflake ID
    SymbolName VARCHAR(50) NOT NULL,
    Description VARCHAR(255)
);
GO


IF OBJECT_ID('Finance.HistoricalPrices', 'U') IS NULL
CREATE TABLE Finance.HistoricalPrices(
    ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    SymbolID UNIQUEIDENTIFIER NOT NULL,
    PriceDate DATE NOT NULL,
    OpenPrice DECIMAL(18,4),
    ClosePrice DECIMAL(18,4),
    HighPrice DECIMAL(18,4),
    LowPrice DECIMAL(18,4),
    Volume BIGINT,
    Change DECIMAL(18,4),
    CONSTRAINT FK_HistoricalPrices_Symbols
                FOREIGN KEY (SymbolID) REFERENCES Finance.Symbols(ID)
);
GO


IF NOT EXISTS(
        SELECT 1 FROM sys.indexes WHERE name='IX_HistoricalPrice_Date_ID'
        AND object_id=OBJECT_ID('Finance.HistoricalPrices')
)
CREATE UNIQUE INDEX IX_HistoricalPrice_Date_ID
        ON Finance.HistoricalPrices(PriceDate,SymbolID);
GO



IF OBJECT_ID('Finance.CalculatedIndicators', 'U') IS NULL
CREATE TABLE Finance.CalculatedIndicators(
    ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    SymbolID UNIQUEIDENTIFIER NOT NULL,
    IndicatorName VARCHAR(50) NOT NULL,
    CalculatedValue DECIMAL(18,4),
    CalculationDate DATE NOT NULL,
    CONSTRAINT FK_CalculatedIndicators_Symbols
                FOREIGN KEY (SymbolID) REFERENCES Finance.Symbols(ID)
);
GO


IF OBJECT_ID('Finance.IntraDayIntervals', 'U') IS NULL
CREATE TABLE Finance.IntraDayIntervals(
    IntervalSecond INT NOT NULL PRIMARY KEY,    -- 60, 300, 600, 3600
    IntervalName VARCHAR(10) NOT NULL UNIQUE    -- '1min', '5min', '10min', '1hour'
);
GO


-- Seed Finance.IntraDayIntervals Table
MERGE INTO Finance.IntraDayIntervals AS T
USING (VALUES
    (60, '1min'),
    (300, '5min'),
    (3600, '1hour')
) AS S(IntervalSecond, IntervalName)
ON T.IntervalSecond = S.IntervalSecond
WHEN NOT MATCHED BY TARGET THEN
    INSERT (IntervalSecond, IntervalName) VALUES (S.IntervalSecond, S.IntervalName);
GO



IF OBJECT_ID('Finance.IntraDayPrices', 'U') IS NULL
CREATE TABLE Finance.IntraDayPrices(
    ID UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    SymbolID UNIQUEIDENTIFIER NOT NULL,
    IntervalSecond INT NOT NULL,
    OpenPrice DECIMAL(18,4) NOT NULL,
    ClosePrice DECIMAL(18,4) NOT NULL,
    HighPrice DECIMAL(18,4) NOT NULL,
    LowPrice DECIMAL(18,4) NOT NULL,
    Volume BIGINT NOT NULL,
    IngestedTime DATETIME2() NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_IntraDayPrices_Symbols
                FOREIGN KEY (SymbolID) REFERENCES Finance.Symbols(ID),

    CONSTRAINT FK_IntraDayPrices_IntraDayIntervals
                FOREIGN KEY (IntervalSecond) REFERENCES Finance.IntraDayIntervals(IntervalSecond)
);
GO



IF NOT EXISTS(
        SELECT 1 FROM sys.indexes WHERE name='IX_IntraDayPrices_Symbol_Interval_IngestedTime'
        AND object_id=OBJECT_ID('Finance.IntraDayPrices')
)
CREATE UNIQUE INDEX IX_IntraDayPrices_Symbol_Interval_IngestedTime
        ON Finance.IntraDayPrices(IntervalSecond,SymbolID,IngestedTime);
GO



IF NOT EXISTS(
        SELECT 1 FROM sys.indexes WHERE name='IX_IntraDayPrices_Symbol_Ingested'
        AND object_id=OBJECT_ID('Finance.IntraDayPrices')
)
CREATE INDEX IX_IntraDayPrices_Symbol_Ingested
        ON Finance.IntraDayPrices(IngestedTime,SymbolID);
GO


-- VIEW