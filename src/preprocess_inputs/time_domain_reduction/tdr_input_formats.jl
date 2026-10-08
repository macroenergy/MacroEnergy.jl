"""Read JSON or a model-input CSV into the same lazy, string-keyed representation.

Ordinary CSV tables return `nothing`. Model CSV tables are retained separately
so copied inputs preserve their original format, row order and column order.
"""
function tdr_read_input_data(path::String, csv_tables::Dict{String,DataFrame}=Dict{String,DataFrame}())
    isjson(path) && return mutable_json_data(read_json(path))
    iscsv(path) || return nothing
    headers = csv_headers(path)
    :Type in headers && :id in headers || return nothing
    table = DataFrame(duckdb_read(path))
    rows = csv_to_json(copy(table))
    csv_tables[path] = table
    name = splitext(basename(path))[1]
    return mutable_json_data(Dict(Symbol(name) => rows))
end

"""Write adjusted input dictionaries in their original JSON or model-CSV format.

CSV cells follow the original headers' `--` addresses into the shared parsed
representation; unchanged columns retain their original values and types.
Columns are removed only when their fields are deliberately removed from every
parsed row, such as excluded policies in isolated subperiod inputs.
"""
function tdr_write_input_data(path::String, data, csv_tables::Dict{String,DataFrame})
    if !haskey(csv_tables, path)
        write_json(path, data)
        return nothing
    end
    table = copy(csv_tables[path])
    rows = only(values(data))
    length(rows) == nrow(table) || throw(ArgumentError("TDR changed model CSV row count: $path"))
    for header in names(table)
        keys = header == "Type" ? ["type"] : ["instance_data"; split(header, "--")]
        cells = map(rows) do row
            value = row
            for key in keys
                value isa AbstractDict && haskey(value, key) || return (false, missing)
                value = value[key]
            end
            (true, value)
        end
        if !isempty(cells) && all(cell -> !first(cell), cells)
            select!(table, Not(header))
            continue
        end
        cell_values = last.(cells)
        isequal(cell_values, table[!, header]) || (table[!, header] = cell_values)
    end
    CSV.write(path, table; compress=endswith(path, ".gz"))
    return nothing
end
