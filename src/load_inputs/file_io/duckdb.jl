###### ###### ###### ###### ###### ######
# DuckDB handling
###### ###### ###### ###### ###### ######

get_db_connection() = DBInterface.connect(DuckDB.DB, ":memory:")

function duckdb_read(file_path::AbstractString)
    db_connection = get_db_connection()
    return DBInterface.execute(db_connection, "SELECT * FROM '$file_path'")
end