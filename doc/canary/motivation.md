# Canary Motivation

## Goal

Canary is a high-level testing generator for projects with:

- one upstream native/core library
- multiple language bindings
- bindings delivered through different package managers

These projects are fragile because a binding may be built, packaged, or
published against different versions of the upstream library. When
incompatibility appears, it is often unclear whether the issue comes from:

- the upstream library
- the binding implementation
- the package manager packaging
- the build environment
- the delivery pipeline

Canary exists to make these compatibility combinations explicit and test them
before end users discover breakage.

## Problem Shape

The core problem is not only "does the binding compile", but:

- which upstream library instance is being used
- how the binding is built against it
- how the binding is installed or delivered
- which artifacts are produced
- which downstream examples or checks should succeed or fail

For a single project, the testing space quickly becomes a matrix of:

- upstream source build vs prebuilt/system library
- different operating systems
- different language bindings
- different package managers
- different delivery modes (local build tree vs installed package)

This is exactly the kind of matrix that is easy to under-test manually and hard
to debug after the fact.

## Current Direction

The current implementation started from concrete CI jobs and steps, then moved
towards abstraction by extracting the repeated structure.

The current two examples are:

- `z3`: richer example with source build, external library use, packaging, and
  multiple bindings
- `sqlite3`: lightweight example focused on the prebuilt/system-library path

Having a second example is important because it reveals which parts are truly
general and which parts are only shaped like `z3`.

## Intended End State

The long-term goal is to collect a full declarative project configuration and
generate backends from it.

That configuration should describe:

- the project and its supported bindings
- the package managers involved
- the upstream library instances or versions
- the relevant environments
- the build and delivery paths
- the expected artifacts
- the expected success/failure properties

From that single source of truth, Canary should generate:

- GitHub Actions workflows
- local testing scripts
- potentially other execution backends later

The key idea is:

- configuration is primary
- backend-specific jobs are derived

## Why We Are Abstracting Gradually

The current implementation still discovers abstractions by starting with
concrete jobs and then lifting the repeated patterns into shared helpers.

This is intentional.

The abstraction is easier to trust when it is extracted from real jobs than when
it is designed too early in the abstract.

The current refactoring path is therefore:

1. write concrete jobs that express real project checks
2. identify repeated stages, job shapes, and capability gates
3. move only clearly shared concepts into common modules
4. keep project-specific logic close to the project until a second example proves
   the abstraction is real

## Current Type Model

Jobs are described by `job_spec`, which captures the role of a job in the
development lifecycle:

- `origin`: how the upstream library was produced — `Source` (built from source)
  or `Prebuilt` (system/external package)
- `location`: where the artifact lives — `Build_tree` (local build output),
  `System_pm` (apt/brew), `Lang_pm` (opam/pip), or `Wild` (arbitrary path)
- `test_bindings`: which language bindings to test (OCaml, Python)
- `example_name`, `build_api_path`: how to find and compile test examples
- `if_disabled`: whether the job is disabled in CI (e.g. YAML anchor trick)

A `job_spec` is a declarative description. The interpreter (`job_of_spec`)
converts it into a concrete job record. OCaml compile/run stages are generated
by `mk_ocaml_test_stages` from the spec + project config. Setup stages
(installing dependencies, configuring cmake) are composed at the call site.

The separation is:
- `job_of_spec`: spec → job structure
- `mk_ocaml_test_stages`: spec + config → OCaml compile/run steps
- `prebuilt_setup_stages`: prebuilt binding config → install/setup steps
- Project-specific stages: cmake configuration, python bindings, etc.

The goal is to grow `job_spec` until a single interpreter can derive complete
jobs from specs alone, with zero project-specific code.

## Artifact-Oriented Future

Today, many checks are still inserted manually.

The intended next level is to make stages describe:

- required artifacts
- produced artifacts

Once stages expose this information, Canary should be able to automatically
select or attach appropriate checkers.

Examples:

- a stage that produces a shared library can trigger symbol/export checks
- a stage that produces an installed package can trigger package load tests
- a stage that produces an executable can trigger run-result checks
- a stage that consumes an upstream library can trigger compatibility checks

This would reduce manual checker insertion and make testing more systematic.

## Design Principle

Canary should help answer "what combination broke?" before users hit it.

That means the system should be designed to make compatibility boundaries
explicit:

- upstream library boundary
- binding boundary
- package manager boundary
- artifact boundary
- environment boundary

The generated jobs are not the main product. The main product is a structured,
repeatable compatibility model from which those jobs are derived.

## Immediate Refactoring Guidance

Given the current codebase, the next steps should follow this rule:

- keep one source of truth for shared canary concepts
- keep tool-specific helpers separate from project-specific logic
- use the second example (`sqlite3`) to validate every claimed abstraction

In practice, this means:

- shared workflow/job concepts belong in `canary_basic`
- OCaml/package-manager helpers belong in tool-specific modules
- project workflows should be expressed as derived job lists from project
  capabilities
- artifact/check relationships should gradually replace manual check insertion
