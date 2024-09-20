function read_file(file_path::AbstractString)
    if isjson(file_path)
        return read_json(file_path)
    elseif iscsv(file_path)
        return read_csv(file_path)
    else
        error("Unsupported file format for $file_path")
    end
end
