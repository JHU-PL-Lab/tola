## Experience and Observations

I’ve been working on _Package Managers à la Carte_ for a while. This project explores several representative package managers and models them as Version Logic equipped Distributed Versioned KV Maps. This work demonstrates that package managers should establish well-defined semantics for their operations. This model splits the package manager into two conceptual components:

- A low-level part that manages packages in isolated stores.
- A high-level part that handles version resolution and dependency management.

Before diving into what’s next, let's revisit the some issues and the big picture. However, let's spoiler ahead:

(1) There is no conceptual difference between the so-called language package managers and system package managers.

(2) Real-world package managers have to deal with the essential components of the whole (necessary) computer systems.

Let me share a recent experience of migrating Z3's build system from a python script to CMake. The motivation is to show why package managers are hard, as well as to share both language pkgms and system pkgms requires some understanding of the whole computer system.

Z3 is a SMT solver implemented in C++. It has bindings in other languages including C and OCaml. The previous building system of Z3 is a python script to generate `makefile` which contains targets to build z3 libraries and other bindings. Several package managers contain z3 packages including Debian's dpkg/apt, MacOS's Homebrew, and OCaml's opam. To make it clear, we follow Debian's terms, to name packages in package managers as _packages_ and the GitHub source of z3 as _upstream_.

_Work packages are all alike; every broken package is broken in its own way._. _Upstream_ often has implicit assumptions and hidden dependencies in its building, testing while they don't always hold and the dependencies may not be satisfied or falsely satisfiled. The server of the package managers may or may not have a checking mechanism. Or the configuration of the packaging may be incorrect or obsolete. Or maybe the problems may only appear after the packages are used by the end users.

**One problem is the linking path problem**. Linking is the system-level resolving process where a binary is constructed with correct symbol references. There are _similaries_ between (dynamic) linking and loading with compiling and running: the former step (linking and loading) performs against one developer-provided artifact, while the latter step (compiling and running) performs against one user-provided  artifact, which supposes to be compatible with the developer-provided one. This compatiblity is usually assumed but not guarantee by versioning systems. This compatiblity also assumes some resolving machanism, which is also not that reliable. MacOS with its linker and loader `dyld`, has a notorious mechanism for a long time. The linking details can be left to the future discussion, but the problem here includes:

(1) how shall we identify the problem?
(2) how can we model them in a shared abstraction understandable by package managers, upstream, and users?
(3) how we can derive a principled checking mechanism, that before and after each step, what guarantees or invariants can be established?

I think the problem is feasible and also worth solving in a programming language mindset. It's not a computationally hard problem that requires a lot of resources, but it's a fragile one that the specification and the semantics is not even studied. Fixes rely on expert manual work and repeated ad-hoc solutions.

**Another problem is the unavoidable shell and environment variables**. Specifically, package managers have to interact and embed shell languages in their configuration and implementation, e.g. z3's python script, CMake, opam package spec `opam` file, and any CI have to create shell command either by printing, invoking, or embeding. These shell code need to get or set environment variables or other shell variables. They share the same spirit and sutblties of the above _linking problem_: that is no clear specification. At the same time, embedding shell uses escaping and quoting, which introduce more problem, e.g. In `opam` file, we have an install instruction `install_name_tool -change \"$LIBZ3_KEY\" \"%{lib}%/stublibs/libz3.dylib\" \"%{lib}%/stublibs/dllz3ml.so\"` in which we need to use opam variable `%{lib}`, embed shell variable `$LIBZ3_KEY`, quote double quotes for shell `\"`. Incorrect in any of them may result in malfunctioning package installation. It may be reported if the package manager has a good checking mechamism, but it may not be reported until the package is used by the end users.

## Thinking and Solutions

These observations reveal that the same problems can occur in both language package managers and system package managers. In solving these problems, we not only need to understand the package managers (the previous work on structural modeling helps a lot), but also stepwise check (and debug) depending on the _target tool_ and _target artifact_. The tool includes both language tools like compilers, interpreters, build systems, and system tools like shells, linkers and loaders. The ultimate artifact containers are files. Depending on its file content, the files can be source code, binaries, packages, etc.

We can categorize these artifacts and concepts into three categories:

(1) **Records**: Files From projects to binaries. Even executables or libraries are record in ELF or Mach-O format, where the fields (symbols) can be checked via `otool` or `readelf`.
(2) **Functions**: The tools, no matter language tools or system tools, all consume and produces some files in expected format.
(3) **Binding and resolving**: In some sense, all related tools follow or construct some binding and resolving rules.

This approach can also be treated as an extension of the previous work, where we leave the modeling and checking for the V part i.e. `package` in the distributed KV map.Theses three categories also hint that why the system can be treated as a running interpreter, where it manipulates several distributed maps, for above categories. The actual functionality is provided by the tools while the pre-and-post conditions can be proviede and checked by our modeling. Checking should be derived from the target tool and target artifact during the steps, rather than wait for late-stage bug report.
