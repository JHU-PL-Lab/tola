# modules

# computation

## Data Flow Analysis

`Fix`
(`Fix__.Core`) the least fixed point computation algorithm
cyclic dependencies
backward data flow analysis
dynamic dependency discovery

constructors: `Make` `ForOrderedType` `ForHashedType` `ForType`: `A_TYPE -> PROPERTY -> solver`.

`DataFlow`
forward data flow analysis
constructors: `Run` `ForOrderedType` `ForHashedType` `ForType`: `key_container -> PROPERTY -> solver`, also `ForIntSegment` and `ForCustomMaps`


## `Tabulate`

`Fix` eagerly.

constructors: `Make` `ForOrderedType` `ForHashedType` `ForType`: `FINITE_TYPE -> PROPERTY -> solver`.

## `Memoize`

`Fix` with memo.

## `MEMOIZER`

`Fix` with memo and detecting circular dependencie.

# Numbering

## `Numbering` `ONGOING_NUMBERING` `TWO_PHASE_NUMBERING`

assigning a unique number to each value in a certain finite set and translating (both ways) between values and their numbers.

constructors: `Make` `ForOrderedType` `ForHashedType` `ForType`: `A_TYPE -> PROPERTY -> solver`.

## `GraphNumbering`

discovering and numbering the reachable vertices in a finite directed graph

constructors: `Make` `ForOrderedType` `ForHashedType` `ForType`: `A_TYPE -> PROPERTY -> solver`.

# components

`Prop` implementations of the signature `PROPERTY`.

# other

`Glue` build various implementations of association maps (`A_TYPE`)

`Gensym` offers a simple facility for generating fresh integer identifiers.

`Indexing` constructs finite sets at the type level and for encoding the inhabitants of these sets as runtime integers.

`HashCons` sets up a hash-consed data type.

`CompactQueue` implements a mutable FIFO queue, used in `DataFlow.ForCustomMaps`