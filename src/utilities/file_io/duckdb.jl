###### ###### ###### ###### ###### ######
# DuckDB handling
###### ###### ###### ###### ###### ######

get_db_connection() = DBInterface.connect(DuckDB.DB, ":memory:")

function duckdb_read(file_path::AbstractString)
    db_connection = get_db_connection()
    try
        # DBInterface.execute leaves an internal pending query alive until GC,
        # retaining CSV handles even after the result and database are closed.
        result = DuckDB.query(db_connection, "SELECT * FROM '$file_path'")
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
