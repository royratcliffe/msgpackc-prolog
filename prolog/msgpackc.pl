/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Jan 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack_object//1                   % ?Term
          ]).
:- use_foreign_library(foreign(msgpackc)).

%!  msgpack_object(?Term)// is semidet.
%
%   Encodes and decodes a single Message Pack object. Term encodes an
%   object as follows.
%
%       1. The _nil_ object becomes Prolog `nil` atom rather than `[]`
%       which Prolog calls nil, the empty list termination. Prolog `[]`
%       decodes an empty Message Pack array.
%       2. Booleans become Prolog atoms `false` and `true`.
%       3. Integers become Prolog integers.
%       4. Floats become Prolog floats.
%       2. Strings in UTF-8 become Prolog strings, never atoms.
%       2. Arrays become Prolog lists.
%       3. Maps become Prolog dictionaries.

msgpack_object(nil) --> [0xc0].
