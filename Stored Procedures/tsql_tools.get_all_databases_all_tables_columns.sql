CREATE PROCEDURE tsql_tools.get_all_databases_all_tables_columns
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE ##temp_meta(database_name SYSNAME
                                 , schema_name SYSNAME
                                 , table_name SYSNAME
                                 , column_name SYSNAME
                                 , column_id TINYINT
                                 , type_name SYSNAME
                                 , max_length INT
                                 , precision TINYINT
                                 , scale TINYINT
                                 , is_nullable BIT
                                 , is_identity BIT)
    
        EXEC sp_MSforeachdb '
    
        if(''?'' not in (''master'', ''msdb'', ''model'', ''tempdb''))
        begin
            USE [?]
            insert into ##temp_meta
            SELECT 
               ''?'',
               s.[name] AS schema_name,
               t.name AS table_name,
               c.[name] as column_name,
               c.column_id,
               ty.name as type_name,
               c.max_length,
               c.precision,
               c.scale,
               c.is_nullable,
               c.is_identity
          FROM sys.columns c
          JOIN sys.types ty
            ON ty.system_type_id = c.system_type_id
          JOIN sys.tables t
            ON c.object_id = t.object_id
          JOIN sys.schemas s
            ON s.schema_id = t.schema_id
            
        end'
END
GO