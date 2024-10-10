# Installation

To install the Macro package in Julia, we recommend following these steps:

1. **Create a new folder**: Before starting Julia, create a new folder for your Macro installation. You can do this in your terminal:

```bash
mkdir MyMacroFolder
cd MyMacroFolder
```
Replace "MyMacroFolder" with your preferred name.

2. **Start Julia**: Start Julia in this new folder by typing `julia` in your terminal.

3. **Open the Julia package manager (Pkg REPL)**: Once Julia has started, open the package manager by typing `]`. Your command line should display something like `(v1.x) pkg>`.

4. **Create and activate a new environment**: Create a new environment in your current folder:

```julia
(v1.x) pkg> activate .
(MyMacroFolder) pkg>
```

This creates and activates a new environment in the current folder. The prompt will change to show the name of your folder.

5. **Add Macro to the environment**: Now you can install Macro using the Git URL (you might need to provide your GitHub username and password):

```julia
(MyMacroFolder) pkg> add https://github.com/macroenergy/Macro.git
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
