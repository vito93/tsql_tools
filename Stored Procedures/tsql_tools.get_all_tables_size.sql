CREATE PROCEDURE tsql_tools.get_all_tables_size
AS
BEGIN

SET NOCOUNT ON;

DECLARE @tmpTableSizes TABLE
(
    tableName    VARCHAR(100),
    numberofRows VARCHAR(100),
    reservedSize VARCHAR(50),
    dataSize     VARCHAR(50),
    indexSize    VARCHAR(50),
    unusedSize   VARCHAR(50)
)

INSERT @tmpTableSizes 
    EXEC sp_MSforeachtable @command1="EXEC sp_spaceused '?'"

SELECT
    tableName,
    CAST(numberofRows AS INT)                              AS 'numberOfRows',
    CAST(LEFT(reservedSize, LEN(reservedSize) - 3) AS INT) AS 'reservedSize KB',
    CAST(LEFT(dataSize, LEN(dataSize) - 3) AS INT)         AS 'dataSize KB',
    CAST(LEFT(indexSize, LEN(indexSize) - 3) AS INT)       AS 'indexSize KB',
    CAST(LEFT(unusedSize, LEN(unusedSize) - 3) AS INT)     AS 'unusedSize KB'
    FROM
        @tmpTableSizes
    ORDER BY
        [reservedSize KB] DESC
END
GO