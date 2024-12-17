# Installation

## Requirements
- **Julia** 1.9 or later
- **Git** (to clone the repository)

!!! warning "Access to the Macro repository"
    The following steps assume that the user has a GitHub account and a PAT (Personal Access Token) or SSH key pair. For more information on how to create a PAT or SSH key pair, please refer to the [GitHub documentation](https://docs.github.com/en/authentication).

    **Current version: 0.1.0**: We also assume that the user has been added to the Macro repository as a collaborator (the repository is private).

## Installation steps
To install the Macro package in Julia, we recommend following these steps:

- **Clone the Macro repository**:

If you are using a PAT, you can use the following command:
```bash
git clone https://<your_username>:<your_pat>@github.com/macroenergy/Macro.git
```
If you are using an SSH key pair instead of a PAT, you can use the following command:
```bash
git clone git@github.com:macroenergy/Macro.git
```

!!! note "Cloning a specific branch"
    If you want to clone a specific branch, you can use the `-b` flag:
    ```bash
    git clone -b <branch_name> https://<your_username>:<your_pat>@github.com/macroenergy/Macro.git
    ```

- **Navigate to the cloned repository**:
```bash
cd Macro
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
Load the Macro package in the Julia REPL:
```julia
using Macro
```

## Editing the installation

If the user wants to edit the installation, for example, to install a specific version of a dependency, they can do so by following the steps below:

- Run a Julia session with the Macro project environment activated:
```bash
$ cd Macro
$ julia --project
```
Alternatively, you can first run Julia and then enter the Pkg mode to activate the project environment:
```bash
$ cd Macro
$ julia
```
In the Julia REPL, enter the Pkg mode by pressing `]`, then activate the project environment:
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
    cd Macro
    julia --project
    ```  
    or
    ```bash
    cd Macro
    julia
    ] activate .
    ```
