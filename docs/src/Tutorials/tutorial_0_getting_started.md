
# Tutorial 0: Getting Started with Macro

This tutorial will guide you through the steps to install Macro, a solver, and all the necessary dependencies.

## Installation
Before installing Macro, make sure you have the following requirements installed:

### Requirements
- **Julia**: you can download it [here](https://julialang.org/downloads/). 
- **Git**: you can download it [here](https://git-scm.com/downloads).
- (optional) **Jupyter Notebook**: you can install it using the following command:
```bash
pip install notebook
```

### Download Macro

**Note**: The following steps assume that you have a GitHub account and that you have already created a token to download the repository. To create a new token, you can go to your [GitHub settings](https://github.com/settings/tokens) and click on "Generate new token". Please refer to the [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token) for more information on how to create a token.

Since Macro is a **private repository**, you need to have permissions to clone the repository. Once your user has been added to the repository, to clone the repository you can use the following command in your terminal:
```bash
git clone -b <branch-name> https://<username>:<token>@github.com/macroenergy/Macro.git
```
Alternatively, you can setup an SSH key pair and use the SSH URL instead of the HTTPS URL.

### Installation steps
- **Navigate to the repository**:
```bash
cd Macro
```
- **Install Macro and all the dependencies**:
```bash
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```

### Setting up Jupyter Notebook
Once Macro is installed, to enable Jupyter Notebook support, you can run the following command:
```bash
julia --project -e 'using IJulia; IJulia.installkernel("Macro", "--project=@.")'
```
Once the kernel is installed, you can run Jupyter Notebook with one of the following commands:
```bash
jupyter lab
```
or 
```bash
jupyter notebook
```

## Testing the installation
To test the installation, you can run the following command:
```julia
using Macro
```
in a Jupyter Notebook cell or in a Julia terminal. If everything is set up correctly, you should see no errors and the package should load without any issues.

## Running these notebooks on GitHub Codespaces (optional)

One simple way to run the notebooks is by using [GitHub Codespaces](https://docs.github.com/en/codespaces/overview). 

**Note**: A GitHub Codespace is a cloud-based development environment that is hosted on GitHub's infrastructure. Therefore, a GitHub account is required to access it.

The repository is already configured to be used with GitHub Codespaces, and the following steps will guide you through the process:
1. Navigate to the repository on GitHub [Macro](https://github.com/macroenergy/Macro).
2. Change the branch to `tutorials`.
3. Click on the "Code" button and then on "Codespaces".
4. (Optional) GitHub allows you to configure the codespace to use a specific hardware. To do that, click on the three dots on the top right corner of the pop-up dialog and then click on "New with options". 
**Note**: All personal GitHub accounts are limited to 120 hours of compute time and 15GB of storage per month. You can learn more about the limitations [here](https://docs.github.com/en/billing/managing-billing-for-github-codespaces/about-billing-for-github-codespaces) and [here](https://docs.github.com/en/codespaces/codespaces-reference/understanding-billing-for-codespaces).
5. If you want to use the default hardware, skip the previous step and click on "Create codespace on tutorials".
6. Once the codespace is open, remember to install the dependencies of Macro by copying and pasting the following command in the terminal at the bottom of the page:
```bash
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
```
7. Once the dependencies are installed, you can run the notebooks by either opening the `.ipynb` files in the `tutorials` folder or by copying and pasting the following command in the terminal at the bottom of the page:
```bash
make run-notebooks
```
The last command will open a Jupyterlab instance in the browser. Once the Jupyterlab is open, you can run the notebooks by clicking on the "Open in Browser" button that should appear on the bottom left corner of the screen. If a token is required to access the notebook, you can find it in the terminal where you ran the `make run-notebooks` command. The token is usually located at the end of the URL shown in the terminal. For example:
```
http://<codespace-name>-<username>.app.github.dev/lab?token=<token>
```
Simply copy and paste the token in the box that appears in the browser. Alternatively, you can simply copy and paste the full URL in the browser's address bar.

If you also click on the "Make Public" button, you will be able to share the notebook with others over the web.

#### Hint: Speed up the build time of the codespace with a prebuild
To speed up the build time of the codespace, you can fork the repository and then setup a **Prebuild** for your fork. This will allow you to avoid to re-install all the dependencies every time you open a new codespace. To setup a prebuild:
1. Fork the repository.
2. Go to the **Settings** of your fork and then click on **Codespaces** under the **Code and automation** section.
3. Click on **Setup prebuild**.
4. Choose the correct branch (e.g. `tutorials`). 
5. Select if you want to prebuild the codespace on **Every push** to the branch or **On schedule**.
6. Select the **Region availability** for your prebuild.
7. Click on **Create** to finish the setup.

Once the prebuild is created, every time you open a new codespace from your fork, it will use the prebuild to speed up the build time.
