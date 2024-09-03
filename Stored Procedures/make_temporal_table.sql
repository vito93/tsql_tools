CREATE PROCEDURE tsql_tools.make_temporal_table
	@table_name SYSNAME
	, @schema_name SYSNAME
	, @start_time_column SYSNAME = 'sys_start_time'
	, @end_time_column SYSNAME = 'sys_end_time'
	, @period_cols_type SYSNAME = 'DATETIME2'
	, @period_cols_length TINYINT = 3
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @schema_id INT, @table_id INT, @full_table_name VARCHAR(256) = CONCAT(@schema_name, '.', @table_name)
	, @temporal_type INT, @SQL VARCHAR(MAX), @period_cols_full_type SYSNAME, @history_table_name SYSNAME;

	DECLARE @start_period_default_constraint SYSNAME = CONCAT('DF_', @schema_name, '_', @table_name, '_', @start_time_column),
	@end_period_default_constraint SYSNAME = CONCAT('DF_', @schema_name, '_', @table_name, '_', @end_time_column);

	-- Lookup table and schema IDs
	SELECT @schema_id = sch.schema_id, @table_id = tab.object_id
	FROM sys.schemas AS sch
	LEFT JOIN sys.tables AS tab ON sch.schema_id = tab.schema_id
	WHERE sch.name = @schema_name AND tab.name = @table_name;

	/* Throw errors if:

	1. Input schema does not exist;
	2. Input table does not exist;
	3. Input table is already temporal.

	*/

	IF @schema_id IS NULL
	BEGIN;
		THROW 50001, 'Input schema does not exist', 1;
	END;

	IF (OBJECT_ID(@table_id) IS NULL)
	BEGIN;
		THROW 50002, 'Input table does not exist', 1;
	END;

	SELECT @temporal_type = temporal_type FROM sys.tables WHERE name = @table_name AND schema_id = @schema_id;

	if @temporal_type = 2
	BEGIN;
		THROW 50003, 'Input table is already temporal', 1;
	END;

	SET @period_cols_full_type = CONCAT(@period_cols_type, '(', CAST(@period_cols_length AS CHAR(1)), ')'); 

	DECLARE @col_id INT = (SELECT column_id FROM sys.columns WHERE Name = @start_time_column AND Object_ID = @table_id);
	
	-- Add sys_start_time
	IF @col_id IS NULL
	BEGIN
	SET @SQL = FORMATMESSAGE('ALTER TABLE %s
	ADD %s %s NOT NULL CONSTRAINT %s DEFAULT SYSDATETIME();
	END;', @full_table_name, @start_time_column, @period_cols_full_type, @start_period_default_constraint);

	EXEC (@SQL);

	END;

	SET @col_id = (SELECT column_id FROM sys.columns WHERE Name = @end_time_column AND Object_ID = @table_id);
	
	IF @col_id IS NULL
	BEGIN
		SET @SQL = FORMATMESSAGE('ALTER TABLE %s
	ADD %s %s NOT NULL CONSTRAINT %s DEFAULT %s;
	END;', @full_table_name, @end_time_column, @period_cols_full_type, @end_period_default_constraint, '''9999-12-31''');
	
	END;

	EXEC (@SQL);

	SET @SQL = FORMATMESSAGE('ALTER TABLE %s
	ADD PERIOD FOR SYSTEM_TIME(%s, %s);
	', @full_table_name, @start_time_column, @end_time_column);

	EXEC ('
	ALTER TABLE dbo.environment
	ADD PERIOD FOR SYSTEM_TIME(sys_start_time, sys_end_time);
	');

	EXEC (@SQL);

	SET @SQL = FORMATMESSAGE('
	ALTER TABLE %s
	ALTER COLUMN %s
	ADD HIDDEN;
	
	ALTER TABLE %s
	ALTER COLUMN %s
	ADD HIDDEN;
	', @full_table_name, @start_time_column, @full_table_name, @end_time_column);
	
	EXEC(@SQL);

	SET @SQL = FORMATMESSAGE('ALTER TABLE %s SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE=%s_history, DATA_CONSISTENCY_CHECK=ON));', @full_table_name, @full_table_name);

	EXEC(@SQL);
END;
GO
