###### ###### ###### ###### ###### ######
# DuckDB handling
###### ###### ###### ###### ###### ######

get_db_connection() = DBInterface.connect(DuckDB.DB, ":memory:")

function duckdb_read(file_path::AbstractString)
    db_connection = get_db_connection()
    try
        result = DBInterface.execute(db_connection, "SELECT * FROM '$file_path'")
        try
            # Materialize owned Julia columns before releasing DuckDB's resources.
            return DataFrame(result)
        finally
            DBInterface.close!(result)
        end
    finally
        DBInterface.close!(db_connection)
    end
end
