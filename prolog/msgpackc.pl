/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Jan 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack_object//1,                  % ?Object
            msgpack_objects//1                  % ?Objects
          ]).
:- use_foreign_library(foreign(msgpackc)).

%!  msgpack_object(?Object)// is semidet.
%
%   Encodes and decodes a single Message Pack object. Term encodes an
%   object as follows.
%
%       1. The _nil_ object becomes Prolog `nil` atom rather than `[]`
%       which Prolog calls "nil," the empty list termination. Prolog `[]`
%       decodes an empty Message Pack array.
%       2. Booleans become Prolog atoms `false` and `true`.
%       3. Integers become Prolog integers.
%
%       4. Floats become Prolog floats. Distinguishing between 32- and
%       64-bit float-point occurs by wrapping the Prolog-side in
%       float(Precision, Number) terms where Precision selects 32 or 64
%       bits. Setting up an epsilon threshold allows for automatic
%       precision adjustment when encoding.
%
%       5. Strings in UTF-8 become Prolog strings, never atoms.
%       6. Arrays become Prolog lists.
%       7. Maps become Prolog dictionaries.

msgpack_object(nil) --> [0xc0], !.
msgpack_object(false) --> [0xc2], !.
msgpack_object(true) --> [0xc3], !.
msgpack_object(Byte) -->
    byte(Byte),
    { Byte =< 0x7f
    },
    !.
msgpack_object(Integer) -->
    fixint(8, Integer).

fixint(8, Integer) -->
    { var(Integer)
    },
    byte(Byte),
    { Byte >= 0xe0,
      Integer is Byte - 0x100
    },
    !.
fixint(8, Integer) -->
    { integer(Integer),
      % Now that Integer is a non-variable and an integer, just reverse
      % the Integer from Byte solution above: swap the sides, add 256 to
      % both sides and swap the compute and threshold comparison; at
      % this point Integer must be negative. Grammar at byte//1 will
      % catch Integer values greater than 255.
      Byte is 0x100 + Integer,
      Byte >= 0xe0
    },
    byte(Byte).

%!  byte(Byte)// is semidet.
%
%   Simplifies the Message Pack grammar by asserting Byte constraints.
%   Every Byte is an integer in-between 0 and 255 inclusive. Other
%   high-level grammer components can presume these contraints as a
%   baseline and assert any addition limits appropriately.

byte(Byte) -->
    [Byte],
    { integer(Byte),
      Byte >= 0x00,
      Byte =< 0xff
    }.

%!  msgpack_objects(?Objects)// is semidet.
%
%   Zero or more Message Pack objects.

msgpack_objects([Object|Objects]) -->
    msgpack_object(Object),
    !,
    msgpack_objects(Objects).
msgpack_objects([]) --> [].
