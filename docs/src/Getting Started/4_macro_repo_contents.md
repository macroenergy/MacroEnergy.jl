# What is in the Macro repo?

If you have downloaded or cloned the Macro code, rather than simply import it as a Julia package (which is not currently possible if your are a beta-user), then you will find the following files in your Macro folder:

```ASCII
MacroEnergy.jl
├── docs
├── src
├── test
├── LICENSE
└── Project.toml
```

You will probably see several other files and folders but you can ignore these. They are mostly responsible for configuring and managing the GitHub repository.

The list below gives brief descriptions of the files and folders in the Macro repo.

- docs: This contains Macro's documentation. You will have to add content here if you create a new Asset or feature.
- src: This is the Macro source code. [Please follow this guide](@ref "Finding your way around the Macro repo") if you would like more information about the structure of the code.
- test: These are automatic tests, run every time an update is made to the Macro GitHub repository. They help us check that updates have not introduced bugs and that existing features still work as expected.
- LICENSE: Macro is released under an MIT license. These file gives the terms of the license.
- Project.toml: Macro works using a Julia project environment. This is defined in the Project.toml file. It describes all the required Julia packages, their versions, and gives some information on the current version of Macro and its authors.
