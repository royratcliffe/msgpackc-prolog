# Message Pack for SWI-Prolog using C

[![test](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml/badge.svg)](https://github.com/royratcliffe/msgpackc-prolog/actions/workflows/test.yaml)
![cov](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/cov.json)
![fail](https://shields.io/endpoint?url=https://gist.githubusercontent.com/royratcliffe/ccccef2ac1329551794f2a466ee61014/raw/fail.json)

Primarily implemented in Prolog but with core highly-optimised C support functions for handling endian transformations via machine-code byte swapping, re-interpreting between ordered bytes (octets) and IEEE-754 floating-point numbers and integers of different bit-widths.

The goal of this delicate balance between Prolog and C, between definite-clause grammar and low-level bit manipulation, aims to retain the flexibility and eligance of forward and backward unification between Message Pack and byte streams while gleaning the performance benefits of a C-based foreign support library.
