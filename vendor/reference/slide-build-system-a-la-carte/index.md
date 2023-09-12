---
title: Build Systems à la Carte
theme : white
transition: none
customTheme : "style"
---

## Outline

**1. Components of Build Systems**

2. Components described in Haskell('s types)

3. Engineering and Experience

4. Looking Forward

---

## Trivias

The paper _Build Systems à la Carte_ is original presented at ICFP'18. 

Then an extended version _Build Systems à la Carte: Theory and Practice_ is presented at JFP'20.

The difference (from the paper outline) is an added section _Expereience_.

--

Author _Andrey Mokhov_ worked on Hadrian (based on author _Neil Mitchell_'s Shake), now is in GHC. He then joined Jane Street and is working on `dune`.

- Author _SPJ_, you-know-who.

---

## Components of Build Systems

1. Examples of Build Systems (sec 2)

2. Vocabulary for Build Systems (sec 3)

3. Components of Build Systems (sec 4 & 5)

--

## Examples of Build Systems

1. `make` (sec 2.1)
2. `excel` (sec 2.2)
3. `shake` (sec 2.3)
4. `bazel` (sec 2.4)

--

## `make`

```makefile
util.o: util.h util.c
  gcc -c util.c
main.o: util.h main.c
  gcc -c main.c
main.exe: util.o main.o
  gcc util.o main.o -o main.exe
```

--

## `makefile`:

1. Three `rule`s

```
target … : prerequisites …
        recipe
        …
        …
```

2. `target` and `prerequisites` can be filename patterns. `prerequisites` can be other `targets`.

3. (re-)run the recipt if files has a recent modification times

--

## Vocabulary for Build Systems

```makefile
util.o: util.h util.c
  gcc -c util.c
main.o: util.h main.c
  gcc -c main.c
main.exe: util.o main.o
  gcc util.o main.o -o main.exe
```

```
$ make main.exe
```

- `key`: file name
- `value`: file content
- `store`: file system
- `task description`: the `Makefile`
- `target key`: `main.exe`

--

## Vocabulary for Build Systems

- `key`, `value`, `store`

- `task` : one rule in `Makefile`

- `build` : to run one `task`

- `scheduler`: the order to run a `build`

- `rebuilder`: decide whether to re-run a `build`

- `build_system`: take all the above

--

## Core problem: Dependency

- `key`, `value`, `store`

- `task` : specify how `key` **depends** on what `value`(indexed by `key`)

- `build` : compute `value` of a `key`

- `scheduler`: the order to run a `build` (determined by **dependencies**)

- `rebuilder`: decide whether to re-run a `build` (determined by **dependencies**)

- `build_system`: resolve **dependencies**

--

## Core problem: Dependency

The main content of the paper is to

1. Model and categorize patterns of dependency
2. (those) in Haskell (or in types, typeclass, ...)

--

## Scheduler (sec 4)

1. Topological Scheduler
2. Restarting Scheduler
3. Suspending Scheduler

--

## Scheduler

1. Topological Scheduler

- Dependencies are _statically_ known before running any `task`

2. Restarting Scheduler

- Dependencies are _dynamically_ known during running a `task`
- Abort and restart a `task`

3. Suspending Scheduler

- Dependencies are _dynamically_ known during running a `task`
- Suspend and resume a `task`

--

# Rebuilder

A build system can be split into a scheduler and a rebuilder

- `scheduler` decides that a key should be brought up to date
- `rebuilder` decides whether we can a cached value of a key and whether to re-do a task

--

# Rebuilder

1. Dirty bit: When the next build starts, anything that changed between the two builds is marked dirty (`key` only)
2. Verifying traces: remember task-related `key` changed
3. Constructive traces: remember immediate dependent `key` changed and `value`
4. Deep constructive traces: remember deep dependent `key` changed and `value`

--

## Outline

1. Components of Build Systems

**2. Components described in Haskell('s types)**

3. Engineering and Experience

4. Looking Forward

--

## Types for Build Systems

- `task` : specify how `key` **depends** on what `value`(indexed by `key`)

```haskell
newtype Task c k v = Task (forall f. c f => (k -> f v) -> f v)
type Tasks c k v = k -> Maybe (Task c k v)
```

Type `Task` takes a constraint type `c` , a `key` and an effectful structure `f` (on building result `v`).

`Tasks` is the (global) lookup function.

--

## Types for Build Systems

- `task` : specify how `key` **depends** on what `value`(indexed by `key`)

```haskell
newtype Task c k v = Task (forall f. c f => (k -> f v) -> f v)
type Tasks c k v = k -> Maybe (Task c k v)

run :: c f => Task c k v -> (k -> f v) -> f v
run (Task task) fetch = task fetch
```

Q: What is `k -> f v`?

A: A dynamic `fetch` function to lookup other `key` when running a `task`.

--

## Types for Build Systems

```haskell
-- Abstract store containing a key/value map and persistent build information
data Store i k v -- i = info, k = key, v = value
initialise :: i -> (k -> v) -> Store i k v
getInfo :: Store i k v -> i
putInfo :: i -> Store i k v -> Store i k v
getValue :: k -> Store i k v -> v
putValue :: Eq k => k -> v -> Store i k v -> Store i k v

data Hash v -- a compact summary of a value with a fast equality check
hash :: Hashable v => v -> Hash v
getHash :: Hashable v => k -> Store i k v -> Hash v
```

A dict and a hash

--

## Types for Build Systems

```haskell
-- Build system (see §3.3)
type Build c i k v = Tasks c k v -> k -> Store i k v -> Store i k v
-- Build system components: a scheduler (see §4) and a rebuilder (see §5)
type Scheduler c i ir k v = Rebuilder c ir k v -> Build c i k v
type Rebuilder c ir k v = k -> v -> Task c k v -> Task (MonadState ir) k v
```

`ir` is _persistent build information_. `Rebuilder` takes a key `k`, its current `value`, the re-run `Task c k v` to wrap a new `Task` can may or may not really re-run and modify the _persistent build information_

--

## The Task Abstraction

```haskell
newtype Task c k v = Task (forall f. c f => (k -> f v) -> f v)
type Tasks c k v = k -> Maybe (Task c k v)
```

Let's revisit `c`, which can be

- `Applicative`: static dependencies (Make)
- `Monad`: dynamic dependencies (Shake)
- `Functor` exactly one static dependency (docker)
- `Selective`: finite choices 
- `MonadFail`: task can fail
- `MonadPlus`: nondeterminisitic task
- `MonadState`: task can read _persistent building info_

--

## The Task Abstraction

```haskell
newtype Task c k v = Task (forall f. c f => (k -> f v) -> f v)
type Tasks c k v = k -> Maybe (Task c k v)
```

In OCaml we can write `<?> : 'a task -> 'a task -> 'a task`

- `Applicative`: static dependencies (Make)
- `Monad`: dynamic dependencies (Shake)
- `Functor` exactly one static dependency (docker)
- `Selective`: finite choices 
- `MonadFail`: task can fail
- `MonadPlus`: nondeterminisitic task
- `MonadState`: task can read _persistent building info_

--

## Outline

1. Components of Build Systems

2. Components described in Haskell('s types)

3. Engineering and Experience

**4. Looking Forward**

--

## Looking Forward (Take-away)

- Nice paper with good modeling
- Too haskell-ish (demo)
- Author brings ideas into real-world build systems

--

```haskell
type Scheduler c i ir k v = Rebuilder c ir k v -> Build c i k v
type Rebuilder c ir k v = k -> v -> Task c k v -> Task (MonadState ir) k v
```

- We can still have other dividing of components
- `MonadState` is too low-level. `Rebuilder` can be derived by dependenci resolving and caching policies.
- Modeling algorithms in fixed-point algorithms.