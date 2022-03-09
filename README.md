# Message Pack for SWI-Prolog using C

[![test](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml/badge.svg)](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml)
![cov](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/cov.json)
![fail](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/fail.json)

## Usage

Install the Prolog pack in SWI-Prolog using:

```prolog
pack_install(msgpackc).
```

Pack messages via Definite-Clause Grammar `msgpack//1` using compound terms. Prolog grammars operate by "unifying" terms with codes, in this case only byte codes rather than Unicodes. Unification works in both directions and even with partial knowns. The grammar back-tracks through all possible solutions non-deterministically until it finds one, else fails.

The implementation supports all the MessagePack formats including timestamps and
any other extensions. The multi-file predicate hook `msgpack:type_ext_hook/3`
unifies arbitrary types and bytes with their terms.

## Brief examples

All the following succeed.

```prolog
?- [library(msgpackc)].
true.

?- phrase(msgpack(float(1e9)), Bytes).
Bytes = [202, 78, 110, 107, 40].

?- phrase(msgpack(float(1e18)), Bytes).
Bytes = [203, 67, 171, 193, 109, 103, 78, 200, 0].

?- phrase(msgpack(float(Float)), [203, 67, 171, 193, 109, 103, 78, 200, 0]).
Float = 1.0e+18.

?- phrase(msgpack(array([str("hello"), str("world")])), Bytes), phrase(msgpack(Term), Bytes).
Bytes = [146, 165, 104, 101, 108, 108, 111, 165, 119|...],
Term = array([str("hello"), str("world")]).
```

## Project goals

Primarily implemented in Prolog but with core highly-optimised C support functions for handling endian transformations via machine-code byte swapping, re-interpreting between ordered bytes (octets) and IEEE-754 floating-point numbers and integers of different bit-widths.

The goal of this delicate balance between Prolog and C, between
definite-clause grammar and low-level bit manipulation, aims to retain
the flexibility and elegance of forward and backward unification between
Message Pack and byte streams while gleaning the performance benefits of
a C-based foreign support library. Much of the pure C Message Pack
implementation concerns storage and memory management. To a large
extent, any Prolog implementation can ignore memory. Prolog was not
designed for deeply-embedded hardware targets with extreme memory
limitations.

## Functors, fundamentals and primitives

The package presents a three-layered interface.

  1. Top layer via `msgpack//1` grammar, usage as `phrase(msgpack(nil), A)` for example.
  2. Fundamental using `msgpack_object//1`, usage as `phrase(msgpack_object(nil), A)` for example.
  3. Primitive predicates, e.g. `msgpack_nil`.

C functions implement some of the key integer and float predicates at the
primitive level.

The top-level grammar is `msgpack//1`. The definition is simple. It maps terms
to primitives. Unification succeeds both forwards and backwards, meaning the
grammar magically parses *and* generates.

```prolog
msgpack(nil) --> msgpack_nil, !.
msgpack(bool(false)) --> msgpack_false, !.
msgpack(bool(true)) --> msgpack_true, !.
msgpack(int(Int)) --> msgpack_int(Int), !.
msgpack(float(Float)) --> msgpack_float(Float), !.
msgpack(str(Str)) --> msgpack_str(Str), !.
msgpack(bin(Bin)) --> msgpack_bin(Bin), !.
msgpack(array(Array)) --> msgpack_array(msgpack, Array), !.
msgpack(map(Map)) --> msgpack_map(msgpack_pair(msgpack, msgpack), Map), !.
msgpack(Term) --> msgpack_ext(Term).
```

Note that this does _not_ include a sequence of back-to-back messages.
High-order grammar predicates will unify with message sequences, e.g.
`sequence(msgpack, Terms)` where Terms is a lists of `msgpack//1` argument
terms.

The fundamental layer via `msgpack_object//1` attempts to match messages to
fundamental types.

## Integer space

The `msgpack//1` implementation does the correct thing when attempting to render
integers at integer boundaries; it correctly fails.

```prolog
A is 1 << 64, phrase(sequence(msgpack, [int(A)]), B)
```

Prolog utilises the GNU Multiple Precision Arithmetic library when values fall
outside the bit-width limits of the host machine. Term `A` exceeds 64 bits in
the example above; Prolog happily computes the correct value within integer
space but it requires 65 bits at least in order to store the value in an
ordinary flat machine word. Hence fails the phrase when attempting to find a
solution to `int(A)` since no available representation of a Message Pack integer
accomodates a 65-bit value.

The same phrase for `float(A)` _will_ succeed however by rendering a Message
Pack 32-bit float. A float term accepts integers. They convert to equivalent
floating-point values; in that case matching IEEE-754 big-endian sequence `[95,
0, 0, 0]` as a Prolog byte-code list.

## Useful links

* [MessagePack specification](https://github.com/msgpack/msgpack/blob/master/spec.md)
