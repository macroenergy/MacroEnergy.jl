# How to contribute guide

**MacroEnergy.jl** is an open-source software project and contributions are welcome! This guide is a quickstart guide to help you contribute to the project.

## Opening an issue

The most straightforward way to contribute to MacroEnergy.jl is to provide feedback directly on the [issues page](https://github.com/MacroEnergy/MacroEnergy.jl/issues). By clicking on the `New issue` button, you will see four types of issues you can open:

- [`Bug Report`](https://github.com/macroenergy/MacroEnergy.jl/issues/new?template=bug_report.yml) - for reporting bugs and errors
- [`Question`](https://github.com/macroenergy/MacroEnergy.jl/issues/new?template=question.yml) - for asking questions: "How do I do ...?"
- [`Feature Request`](https://github.com/macroenergy/MacroEnergy.jl/issues/new?template=feature_request.yml) - for requesting new features
- [`Other`](https://github.com/macroenergy/MacroEnergy.jl/issues/new) - for other types of contributions

## Opening a PR

The second way to contribute to MacroEnergy.jl is to open a [pull request](https://github.com/macroenergy/MacroEnergy.jl/pulls). This allows you to implement changes and new features and propose them to the repository. Below are some guidelines for opening a PR (for reference, check the official [GitHub guide](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request)).

### Before opening a PR

1. We recommend **opening an issue** before opening a PR. This will allow us to discuss the changes you want to make and provide feedback.

2. **Fork the repository** (if you don't have already done so):
   - Click the "Fork" button in the top-right corner of the [MacroEnergy.jl repository](https://github.com/MacroEnergy/MacroEnergy.jl).
   - This creates your own copy of the repository where you can make changes.

3. **Clone your fork**:

   ```bash
   # Replace YOUR-USERNAME with your GitHub username
   git clone https://github.com/YOUR-USERNAME/MacroEnergy.jl.git
   cd MacroEnergy.jl
   ```

4. **Add the original repository as upstream**:

   ```bash
   # This allows you to keep your fork in sync with the main repository
   git remote add upstream https://github.com/macroenergy/MacroEnergy.jl.git
   # Verify the remotes are set up correctly
   git remote -v
   ```

5. **Create a new branch** for your changes:

   ```bash
   # Get the latest changes from the main repository
   git checkout main
   git pull upstream main
   
   # Create and switch to a new branch
   # Replace your-branch-name with a descriptive name
   git checkout -b your-branch-name
   ```

!!! note "Branch name"
    The recommended name for the branch is `<user_id>/<short_description>`, where `<user_id>` can be a short version of your name or a nickname, and `<short_description>` is a short description of the changes you are making.

6. **Make your changes** and commit them (this step can be done multiple times, each for a different change):

   ```bash
   # Stage your changes
   git add .
   
   # Commit with a descriptive message
   git commit -m "Description of your changes"
   
   # If you need to make more changes, repeat the process
   ```

7. **Push to your fork**:

   ```bash
   # Push your branch to your fork
   git push origin your-branch-name
   
   # If this is the first time pushing this branch, use:
   git push -u origin your-branch-name
   ```

### How to open a PR (once the changes are in a good state)

8. **Create a Pull Request**:

   - Go to your fork on GitHub
   - Click "New Pull Request"
   - Select your branch
   - Select the base repository as `macroenergy/MacroEnergy.jl` and the base branch as `main` (or the correct target branch)
   - Fill out the PR template
   - Submit the PR

9. **Keep your fork up to date** (every time a PR is merged into the upstream repository):

   ```bash
   # Fetch the latest changes from the main repository
   git fetch upstream
   
   # Switch to main branch
   git checkout main
   
   # Merge the changes from upstream
   git merge upstream/main
   
   # Push the updated main branch to your fork
   git push origin main
   ```
   
Alternatively, use the `Sync fork` button in the GitHub website.

!!! note "Updating a PR"
    Once a PR is created, you can still make changes to your code. You can do this by committing new changes to your branch and pushing them to your fork. The PR will automatically update to reflect the new changes.

### PR review process

1. Your PR will be reviewed by maintainers who will provide feedback on the PR.
2. If any changes are requested, you can push a new commit to your branch, which will update the PR.
3. If any conflicts arise, you can resolve them by pulling the latest changes from the upstream repository and merging them into your branch (you can use the conflict resolution tool provided by GitHub).
4. Once the PR is approved, it will be merged into the upstream repository.
5. You can delete the branch from your fork to clean up.

!!! warning "Recommendations for a good PR"
    - Make sure to have **reviewed** your code before opening a PR.
    - Make sure to have added **comments** to your code, in particular in hard-to-understand places.
    - Make sure to have updated the **docs** if you added new functions or changed existing ones, to help other users use your code.
    - Make sure to have **tested** your code, and to provide an example case that the reviewer can use to test the code + how to interpret the results (set of json + csv + julia files).
    - Try to write a good PR description, including the motivation for the changes you made.
    - Try to make small PRs, ideally each one focusing on a single change.
    - Help review your PR, for instance by highlighting places where you would particularly like reviewer feedback.

## Some useful links

- [Creating an issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/creating-an-issue) (GitHub)
- [Creating a pull request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request) (GitHub)
- [Creating a pull request from a fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request-from-a-fork) (GitHub)
- [Git guide](https://git-scm.com/docs)
- [ColPrac](https://github.com/SciML/ColPrac): Contributor's Guide on Collaborative Practices for Community Packages
- [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/)

## Contributing to Macro

## Contributing to the documentation

### Adding a tutorial
