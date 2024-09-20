# Installation

To install the Macro package in Julia, please follow these steps:

- **Start Julia**: You can start Julia by typing `julia` on your command line.

- **Open the Julia package manager (Pkg REPL)**: Once Julia has started, you can open the package manager by typing `]`. Your command line should display something like `(v1.x) pkg>`.

- **(Optional) Activate the Environment**: If you want to install the Macro package in a specific environment, you can activate it by typing `activate` followed by the path to the environment. For instance, if your environment `MyEnv` is located in the directory `/path/to/environment`, your command should look like this:
```julia
(v1.x) pkg> activate /path/to/environment
(MyEnv) pkg>
```

- **Add Macro to the environment**: you can install Macro using the Git URL (you might need to provide your GitHub username and password):
```julia
(MyEnv) pkg> add https://github.com/macroenergy/Macro.git
```

!!! tip "SSH key pair"
    If an SSH key pair is set up on your GitHub account, you can use the SSH URL instead of the HTTPS URL. 
    ```julia
    (MyEnv) pkg> add git@github.com:macroenergy/Macro.git
    ```

Julia will now clone the package from the provided Git repository and install it, along with any dependencies the package might have.

- **Exit the Package Manager**: When the installation is complete, you can exit the package manager by pressing backspace. 

- **Import the package**: You are now ready to use the Macro package in your Julia code. Simply import it by typing:

```julia
using Macro
```
