# Message Pack for SWI-Prolog using C

[![test](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml/badge.svg)](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml)
![cov](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/cov.json)
![fail](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/fail.json)

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

## Useful links

* [MessagePack specification](https://github.com/msgpack/msgpack/blob/master/spec.md)
