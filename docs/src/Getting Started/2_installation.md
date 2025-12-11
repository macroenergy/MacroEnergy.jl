# Installation

You can install Macro (aka. MacroEnergy.jl) using [installation steps](#installation-steps) below. If you wish to contribute to the development of Macro or modify its source code, please follow the [source code installation steps](#source-code-installation-steps).

Note, you can use the user-additions features of Macro to add new commodities and assets without making changes to the source code. The most common reasons to modify the source code are to add new constraint types, add solution algorithms, or modify the outputs written. If you are unsure whether you need to modify the source code, please contact the Macro development team through [the MacroEnergy.jl issues page.](https://github.com/macroenergy/MacroEnergy.jl/issues)

## Requirements

- **Julia** 1.9 or later. We recommend using the latest stable release of Julia. Installation instructions can be found on [the official Julia website](https://julialang.org/install/).
- **Git**, to clone the repository.

## Installation steps

If you want to use Macro for your own projects without making any changes to the source code, you can install it using the Julia package manager. Open a Julia REPL and run the following commands:

```julia
using Pkg
Pkg.add("MacroEnergy")
```

## Source code installation steps

To download and install the Macro source code, we recommend following these steps:

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
julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.precompile()"
```

- **Test the installation**:
Start Julia with the project environment in a terminal:

```bash
$ julia --project=.
```

Load Macro in the Julia REPL:

```julia
using MacroEnergy
```

## Editing the installation

If you want to edit the installation, for example, to install a specific version of a dependent package, you can do so by following the steps below:

- Run a Julia session with the Macro project environment activated:

```bash
$ cd MacroEnergy.jl
$ julia --project=.
```

Alternatively, you can first run Julia:

```bash
$ cd MacroEnergy.jl
$ julia
```

Then, enter the package manager (aka. `Pkg`) mode by pressing `]`, and activate the project environment:

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
julia --project=.
```

or

```bash
cd MacroEnergy.jl
julia
] activate .
```
