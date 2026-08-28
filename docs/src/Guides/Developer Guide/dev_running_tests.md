# Running the Test Suite

Macro's tests are split into two suites:

- **`short`** (the default) — everything except the tests that build and solve full cases. It is what CI runs on pull requests, and what you should run while iterating locally.
- **`long`** — the short suite plus the slow, full-case tests.

## Running the tests

From the root of the repository:

```bash
# short suite (default)
julia --project=. test/runtests.jl

# long suite
julia --project=. test/runtests.jl long
```

Or from the Julia REPL, using `Pkg`:

```julia
using Pkg
Pkg.test("MacroEnergy")                          # short suite
Pkg.test("MacroEnergy"; test_args=["long"])      # long suite
```

The suite can also be selected with the `MACRO_TEST_SUITE` environment variable, which is convenient in scripts and CI:

```bash
MACRO_TEST_SUITE=long julia --project=. test/runtests.jl
```

Command-line arguments take precedence over the environment variable. `runtests.jl` logs which suite it is running at startup.

## Adding a test to the long suite

The suite flag is defined in `test/utilities.jl`, which exposes `run_long_tests()`. To keep a slow test out of the short suite, guard the call to it:

```julia
function run_my_tests()
    @testset "My Tests" begin
        test_something_fast()
        if run_long_tests()
            test_something_slow()
        end
    end
end
```

Test files that do not already `include("utilities.jl")` will need to add it. A whole test file can be gated the same way from `test/runtests.jl`:

```julia
if run_long_tests()
    Test.@testset verbose = true "Slow tests" begin
        include("test_something_slow.jl")
    end
end
```

As a rule of thumb, a test belongs in the long suite if it solves a full case, downloads inputs, or otherwise takes more than a few seconds.
