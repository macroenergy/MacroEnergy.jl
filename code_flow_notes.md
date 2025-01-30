# Notes on code flow

## Starting from file_path of a JSON system data file

### 1. load_system(path; lazy_load)

- path can be absolute or relative to caller

- path can be a file name or a directory name, in which case the file name is assumed to be `system_data.json`

- lazy_load controls whether the entire system data file is loaded into memory upfront (eager) or as items are created (lazy)

### 2. system = empty_system(dirname(path))

- A System is created, and the directory containing the system data file is set as the system's data_directory field

- The system contains:
    - `data_dirpath`: The data_directory, which all other file searches will be relative to
    - `settings`: An empty NamedTuple to store the system settings
    - `commodities`: An empty Dict{Symbol, DataType} to store the system commodities
    - `time_data`: An empty Dict{Symbol, TimeData} to store the time series data for each commodity
    - `assets`: An empty Vector of Assets
    - `locations`: An empty Vector of nodes

### 3. system_data = load_system_data(path; lazy_load)

- The system data is loaded from the file into a dictionary, with lazy or eager loading

- Macro checks where path is a relative or absolute path and whether the file exists

- #### 3a. prep_system_data(file_path, default_file_path)

    - The input file is loaded and any missing default fields are added

- #### 3b. system_data = load_json_inputs(file_path; lazy_load)

    - The JSON file is loaded into a dictionary

### 4. generate_system!(system, system_data)

- The system is populated using the system_data dictionary

### 5. The system is returned

---

## system_data = load_json_inputs(file_path; lazy_load)

### 1.Print info on the file being loaded

- @info("Loading JSON data from $file_path")

- json_data = read_json(file_path)

    - The JSON file is read into a JSON3 object

- If lazy_load = true, return json_data

- Otherwise, load and expand all the fields of json_data

### 2. json_data = load_paths(json_data, path_key, root_path, lazy_load)

- If json_data is a JSON3 object, convert it to Dict{Symbol, Any}. This is not great to have to do, but makes Types easier to work with later

- For each key, value:

    - If key == `path_key`, load the file at the path using fetch_file, and insert the contents into the dictionary

    - If key == `AbstractDict{Symbol,Any}`, recursively call load_paths on the value

    - If key == `AbstractVector{<:AbstractDict{Symbol,Any}}`, recursively call load_paths on each element of the value