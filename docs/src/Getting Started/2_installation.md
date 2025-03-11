# Installation

## Requirements
- **Julia** 1.9 or later
- **Git** (to clone the repository)

## Installation steps
To install Macro, we recommend following these steps:

- **Clone the Macro repository**:
```bash
git clone https://github.com/macroenergy/MacroEnergy.jl.git
```

!!! note "Cloning a specific branch"
    If you want to clone a specific branch, you can use the `-b` flag:
    ```bash
    git clone -b <branch_name> https://github.com/macroenergy/MacroEnergy.jl.git
    ```

- **Navigate to the cloned repository**:
```bash
cd MacroEnergy.jl
```

- **Install Macro and all its dependencies**:
```bash
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

- **Test the installation**:
Start Julia with the project environment in a terminal:
```bash
$ julia --project
```
Load Macro in the Julia REPL:
```julia
using MacroEnergy
```

## Editing the installation

If the user wants to edit the installation, for example, to install a specific version of a dependency, they can do so by following the steps below:

- Run a Julia session with the Macro project environment activated:
```bash
$ cd MacroEnergy.jl
$ julia --project
```
Alternatively, you can first run Julia:
```bash
$ cd MacroEnergy.jl
$ julia
```
Then, enter the `Pkg` mode by pressing `]`, and activate the project environment:
```julia
] activate .
```

- Use the Pkg mode to install or update a dependency:
```julia
] rm <dependency_name>
] add <dependency_name>@<version>
```

For instance, to install the `JuMP` package version v1.22.2, you can use the following commands:
```julia
] rm JuMP
] add JuMP@v1.22.2
```

!!! note "Activating the project environment"
    When working with the Macro package, always remember to activate the project environment before running any commands. This ensures that the correct dependencies are used and that the project is in the correct state. 

    To activate the project environment, you can use the following commands:
    ```bash
    cd MacroEnergy.jl
    julia --project
    ```  
    or
    ```bash
    cd MacroEnergy.jl
    julia
    ] activate .
    ```
