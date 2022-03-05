/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Jan 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack//1,

            msgpack_object//1,                  % ?Object
            msgpack_objects//1,                 % ?Objects

            msgpack_nil//0,
            msgpack_false//0,
            msgpack_true//0,

            msgpack_float//2,                   % ?Width,?Float
            msgpack_float//1,                   % ?Float

            % str format family
            msgpack_str//1,                     % ?String
            msgpack_fixstr//1,                  % ?String
            msgpack_str//2,                     % ?Width,?String

            msgpack_bin//2,                     % ?Width,?Bytes
            msgpack_bin//1                      % ?Bytes
          ]).
:- autoload(library(dcg/high_order), [sequence//2, sequence/4]).
:- autoload(library(utf8), [utf8_codes/3]).

:- use_module(memfilesio).

:- use_foreign_library(foreign(msgpackc)).

:- meta_predicate
    msgpack_array(3, ?, ?, ?).

/** <module> C-Based Message Pack for SWI-Prolog

The predicates have three general categories.

    1. High-order recursive for normal use by application software.
    2. Parameterised mid-level grammar components such as `msgpack_nil`
    designed for two-way unification between fundamental types and
    their Message Pack byte encoded representations.
    3. Low-level C predicates and functions interfacing with the machine
    byte-swapping hardware.

## Optimal message packing

Prolog has the uncanny ability to find optimal solutions to seemingly
intractible problems. Back-tracking allows the message sender to search
for the shortest message possible amongst all available encodings. In
most cases, message transmittion latency presents the narrowest
bottleneck. Encoding and decoding is just one small part. As message
frequency and complexity increases, an optimal encoding might improve
overall messaging throughput over channels with limited bandwidth.
Optimisation could complete in microseconds whereas transmission
improvements might aggregate to milliseconds.

@author Roy Ratcliffe
*/

%!  msgpack(?Object:compound)// is nondet.
%
%   Where Object is a compound arity-1 functor, never a list term. The
%   functor carries the format choice.
%
%   Packing arrays and maps necessarily recurses. Array elements are
%   themselves objects; arrays are objects hence arrays of arrays
%   nested up to any number of dimensions. Same goes for maps.

msgpack(nil) --> msgpack_nil, !.
msgpack(bool(false)) --> msgpack_false, !.
msgpack(bool(true)) --> msgpack_true, !.
msgpack(int(Int)) --> msgpack_int(Int), !.
msgpack(str(Str)) --> msgpack_str(Str), !.
msgpack(array(Array)) --> msgpack_array(msgpack, Array).

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
%
%   Unsigned and signed integers share a common pattern. The
%   least-significant two bits, 00 through 11, select eight through 64
%   bits of width. The ordering of the Message Pack specification
%   arranges the types in order to exploit this feature.

msgpack_object(nil) --> [0xc0], !.
msgpack_object(false) --> [0xc2], !.
msgpack_object(true) --> [0xc3], !.
msgpack_object(Integer) -->
    msgpack_int(Integer),
    { integer(Integer)
    },
    !.
msgpack_object(Float) -->
    msgpack_float(Float),
    { float(Float)
    },
    !.
msgpack_object(String) --> msgpack_str(_, String), !.
msgpack_object(Array) --> msgpack_array(msgpack_object, _, Array), !.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
You cannot use a MemoryFile as a ground term because no way of
determining whether or not the incoming term is a memory file without
attempting to open it.

msgpack_object(MemoryFile) --> msgpack_memory_file(MemoryFile).
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_nil// is semidet.
%!  msgpack_false// is semidet.
%!  msgpack_true// is semidet.
%
%   The simplest packing formats for nil and Booleans.

msgpack_nil --> [0xc0].

msgpack_false --> [0xc2].

msgpack_true --> [0xc3].

%!  msgpack_float(?Width, ?Float)// is nondet.
%!  msgpack_float(?Float)// is semidet.
%
%   Delivers two alternative solutions by design, both valid. Uses the
%   different renderings to select the best compromise between 32- and
%   64-bit representation for any given number. Prolog lets the
%   implementation explore the alternatives. Chooses 32 bits only when
%   the least-significant 32 bits match zero. In this case, the 64-bit
%   double representation is redundant because the 32-bit representation
%   fully meets the resolution requirements of the float value.
%
%   The arity-1 version of the predicate duplicates the encoding
%   assumptions. The structure aims to implement precision width
%   selection but _without_ re-rendering. It first unifies a 64-bit
%   float with eight bytes. Parsing from bytes to Float will fail if
%   the bytes run out at the end of the byte stream.
%
%   Predicates float32//1 and float64//1 unify with integer-valued
%   floats as well as floating-point values. This provides an
%   alternative representation for many integers.

msgpack_float(32, Float) --> [0xca], float32(Float).
msgpack_float(64, Float) --> [0xcb], float64(Float).

msgpack_float(Float) -->
    { float64(Float, Bytes, []),
      Bytes \= [_, _, _, _, 0, 0, 0, 0]
    },
    !,
    [0xcb|Bytes].
msgpack_float(Float) --> [0xca], float32(Float).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_int(?Integer:integer)// is semidet.
%
%   Finds the optimum integer representation, shortest first. Tries
%   fixed integer at first which works for a small subset of integers
%   between -32 and 127. If that fails because the integer falls outside
%   that small range, the second attempt applies unsigned
%   representation; it only applies signed formats for negatives. This
%   assumes that the difference does not matter. An overlap exists
%   between signed and unsigned integers.

msgpack_int(Integer) --> msgpack_fixint(_, Integer), !.
msgpack_int(Integer) -->
    { integer(Integer),
      Integer < 0,
      !
    },
    msgpack_int(_, Integer).
msgpack_int(Integer) --> msgpack_uint(_, Integer), !.
msgpack_int(Integer) --> msgpack_int(_, Integer).

%!  msgpack_uint(?Width, ?Integer)// is nondet.
%!  msgpack_int(?Width, ?Integer)// is nondet.

msgpack_uint(8, Integer) --> [0xcc], byte(Integer).
msgpack_uint(16, Integer) --> [0xcd], uint16(Integer).
msgpack_uint(32, Integer) --> [0xce], uint32(Integer).
msgpack_uint(64, Integer) --> [0xcf], uint64(Integer).

msgpack_int(8, Integer) --> [0xd0], int8(Integer).
msgpack_int(16, Integer) --> [0xd1], int16(Integer).
msgpack_int(32, Integer) --> [0xd2], int32(Integer).
msgpack_int(64, Integer) --> [0xd3], int64(Integer).

%!  float(?Width, ?Float)// is nondet.
%!  uint(?Width, ?Integer)// is nondet.
%!  int(?Width, ?Integer)// is nondet.
%
%   Wraps the underlying C big- and little-endian support functions for
%   unifying bytes with floats and integers.

float(32, Float) --> float32(Float).
float(64, Float) --> float64(Float).

uint(8, Integer) --> uint8(Integer).
uint(16, Integer) --> uint16(Integer).
uint(32, Integer) --> uint32(Integer).
uint(64, Integer) --> uint64(Integer).

int(8, Integer) --> int8(Integer).
int(16, Integer) --> int16(Integer).
int(32, Integer) --> int32(Integer).
int(64, Integer) --> int64(Integer).

%!  msgpack_fixint(?Width, ?Integer)// is semidet.
%
%   Width is the integer bit width, only 8 and never 16, 32 or 64.

msgpack_fixint(8, Integer) --> fixint8(Integer).

%!  fixint8(Integer)// is semidet.
%
%   Very similar to int8//1 except for adding an additional constraint:
%   the Integer must not fall below -32. All other constraints also
%   apply for signed 8-bit integers. Rather than falling between -128
%   and 127 however, the _fixed_ 8-bit integer does not overlap the bit
%   patterns reserved for other Message Pack type codes.

fixint8(Integer) -->
    int8(Integer),
    { Integer >= -32
    }.

%!  byte(?Byte)// is semidet.
%!  uint8(?Integer)// is semidet.
%!  int8(?Integer)// is semidet.
%
%   Simplifies the Message Pack grammar by asserting Byte constraints.
%   Every Byte is an integer in-between 0 and 255 inclusive; fails
%   semi-deterministically otherwise. Other high-level grammer
%   components can presume these contraints as a baseline and assert any
%   addition limits appropriately.
%
%   Predicate uint8//1 is just a synonym for byte//1. The int8//1
%   grammar accounts for signed integers between -128 through 127
%   inclusive.
%
%   Importantly, phrases such as the following example fail. There _is
%   no_ byte sequence that represents an unsigned integer in 8 bits.
%   Other sub-grammars for Message Pack depend on this type of
%   last-stage back-tracking while exploring the realm of possible
%   matches.
%
%       phrase(msgpackc:uint8(256), _)
%
%   @tbd A reasable argument exists for translating byte//1 and all the
%   8-bit grammar components to C for performance reasons; either that
%   or in its stead some performance benchmarking work that demonstrates
%   negligable difference.

byte(Byte) -->
    [Byte],
    { integer(Byte),
      Byte >= 0x00,
      Byte =< 0xff
    }.

uint8(Integer) --> byte(Integer).

int8(Integer) -->
    byte(Integer),
    { Integer =< 0x7f
    },
    !.
int8(Integer) -->
    { var(Integer)
    },
    byte(Byte),
    { Byte >= 0x80,
      Integer is Byte - 0x100
    },
    !.
int8(Integer) -->
    { integer(Integer),
      % Now that Integer is non-variable and an integer, just reverse
      % the Integer from Byte solution above: swap the sides, add 256 to
      % both sides and swap the compute and threshold comparison; at
      % this point Integer must be negative. Grammar at byte//1 will
      % catch Integer values greater than -1.
      Byte is 0x100 + Integer
    },
    byte(Byte).

%!  msgpack_objects(?Objects)// is semidet.
%
%   Zero or more Message Pack objects.

msgpack_objects(Objects) --> sequence(msgpack_object, Objects).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    str format family

    +--------+========+
    |101XXXXX|  data  | fixstr
    +--------+========+

    +--------+--------+========+
    |  0xd9  |YYYYYYYY|  data  | str 8
    +--------+--------+========+

    +--------+--------+--------+========+
    |  0xda  |ZZZZZZZZ|ZZZZZZZZ|  data  | str 16
    +--------+--------+--------+========+

    +--------+--------+--------+--------+--------+========+
    |  0xdb  |AAAAAAAA|AAAAAAAA|AAAAAAAA|AAAAAAAA|  data  | str 32
    +--------+--------+--------+--------+--------+========+

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_str(?String)// is semidet.
%
%   Unifies String with the shortest packed UTF-8 string message.

msgpack_str(String) --> msgpack_fixstr(String), !.
msgpack_str(String) --> msgpack_str(_, String), !.

%!  msgpack_fixstr(?String)// is semidet.
%
%   Unifies Message Pack byte codes with fixed String of length between
%   0 and 31 inclusive.

msgpack_fixstr(String) -->
    { var(String),
      !
    },
    byte(Format),
    { fixstr_format_length(Format, Length),
      length(Bytes, Length)
    },
    sequence(byte, Bytes),
    { phrase(utf8_codes(Codes), Bytes),
      string_codes(String, Codes)
    }.
msgpack_fixstr(String) -->
    { string(String),
      string_codes(String, Codes),
      phrase(utf8_codes(Codes), Bytes),
      length(Bytes, Length),
      fixstr_format_length(Format, Length)
    },
    byte(Format),
    sequence(byte, Bytes).

fixstr_format_length(Format, Length), var(Format) =>
    Format is 0b101 00000 + Length,
    fixstr_format(Format).
fixstr_format_length(Format, Length) =>
    fixstr_format(Format),
    Length is Format - 0b101 00000.

fixstr_format(Format) :-
    Format >= 0b101 00000,
    Format =< 0b101 11111.

%!  msgpack_str(?Width, ?String)// is semidet.
%
%   Refactors common string-byte unification utilised by all string
%   grammars for the Message Pack protocol's 8, 16 and 32 bit lengths.
%   Unifies for Length number of bytes for String. Length is *not* the
%   length of String in Unicodes but the number of bytes in its UTF-8
%   representation.

msgpack_str(Width, String) -->
    { var(String),
      !,
      str_width_format(Width, Format)
    },
    [Format],
    uint(Width, Length),
    { length(Bytes, Length)
    },
    sequence(byte, Bytes),
    { phrase(utf8_codes(Codes), Bytes),
      string_codes(String, Codes)
    }.
msgpack_str(Width, String) -->
    { string(String),
      str_width_format(Width, Format),
      string_codes(String, Codes),
      phrase(utf8_codes(Codes), Bytes),
      length(Bytes, Length)
    },
    [Format],
    uint(Width, Length),
    sequence(byte, Bytes).

str_width_format( 8, 0xd9).
str_width_format(16, 0xda).
str_width_format(32, 0xdb).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    bin format family

    +--------+--------+========+
    |  0xc4  |XXXXXXXX|  data  |
    +--------+--------+========+

    +--------+--------+--------+========+
    |  0xc5  |YYYYYYYY|YYYYYYYY|  data  |
    +--------+--------+--------+========+

    +--------+--------+--------+--------+--------+========+
    |  0xc6  |ZZZZZZZZ|ZZZZZZZZ|ZZZZZZZZ|ZZZZZZZZ|  data  |
    +--------+--------+--------+--------+--------+========+

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_bin(?Width, ?Bytes:list)// is nondet.
%
%   Works very much like the string grammar except that the Bytes remain
%   as 8-bit byte lists.

msgpack_bin(Width, Bytes) -->
    { var(Bytes),
      !,
      bin_width_format(Width, Format)
    },
    [Format],
    uint(Width, Length),
    { length(Bytes, Length)
    },
    sequence(byte, Bytes).
msgpack_bin(Width, Bytes) -->
    { is_list(Bytes),
      bin_width_format(Width, Format),
      length(Bytes, Length)
    },
    [Format],
    uint(Width, Length),
    sequence(byte, Bytes).

bin_width_format( 8, 0xc4).
bin_width_format(16, 0xc5).
bin_width_format(32, 0xc6).

%!  msgpack_bin(?Bytes)// is semidet.
%
%   Succeeds only once when Bytes unifies with the Message Pack byte
%   stream for the first time. Relies on the width ordering: low to
%   high and attempts 8 bits first, 16 bits next and finally 32. Fails
%   if 32 bits is not enough to unify the number of bytes because the
%   byte-list has more than four thousand megabytes.

msgpack_bin(Bytes) --> msgpack_bin(_, Bytes), !.

msgpack_memory_file(MemoryFile) -->
    { var(MemoryFile),
      !
    },
    msgpack_bin(Bytes),
    { memory_file_bytes(MemoryFile, Bytes)
    }.
msgpack_memory_file(MemoryFile) -->
    { memory_file_bytes(MemoryFile, Bytes)
    },
    msgpack_bin(Bytes).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    array format family

    +--------+~~~~~~~~~~~~~~~~~+
    |1001XXXX|    X objects    | fixarray
    +--------+~~~~~~~~~~~~~~~~~+

    +--------+--------+--------+~~~~~~~~~~~~~~~~~+
    |  0xdc  |YYYYYYYY|YYYYYYYY|    Y objects    | array 16
    +--------+--------+--------+~~~~~~~~~~~~~~~~~+

    +--------+--------+--------+--------+--------+~~~~~~~~~~~~~~~~~+
    |  0xdd  |ZZZZZZZZ|ZZZZZZZZ|ZZZZZZZZ|ZZZZZZZZ|    Z objects    | 32
    +--------+--------+--------+--------+--------+~~~~~~~~~~~~~~~~~+

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

msgpack_array(OnElement, Array) --> msgpack_fixarray(OnElement, Array), !.
msgpack_array(OnElement, Array) --> msgpack_array(OnElement, _, Array), !.

%!  msgpack_fixarray(:OnElement, Array)// is semidet.
%!  msgpack_array(:OnElement, ?Width, ?Array)// is nondet.
%
%   Non-deterministically unify with Array of Message Pack objects, zero
%   or more msgpack_object(Object) phrases.
%
%   Does not prescribe how to extract the elements. OnElement defines
%   the sequence's element.

msgpack_fixarray(OnElement, Array) -->
    { var(Array),
      !
    },
    byte(Format),
    { fixarray_format_length(Format, Length),
      length(Array, Length)
    },
    sequence(OnElement, Array).
msgpack_fixarray(OnElement, Array) -->
    { length(Array, Length),
      fixarray_format_length(Format, Length)
    },
    [Format],
    sequence(OnElement, Array).

fixarray_format_length(Format, Length) :-
    fix_format_length(shift(0b1001, 4), Format, Length).

msgpack_array(OnElement, Width, Array) -->
    { var(Array),
      !,
      array_width_format(Width, Format)
    },
    [Format],
    uint(Width, Length),
    { length(Array, Length)
    },
    sequence(OnElement, Array).
msgpack_array(OnElement, Width, Array) -->
    { is_list(Array),
      array_width_format(Width, Format),
      length(Array, Length)
    },
    [Format],
    uint(Width, Length),
    sequence(OnElement, Array).

array_width_format(16, 0xdc).
array_width_format(32, 0xdd).

%!  fix_format_length(Fix, Format, Length) is semidet.
%
%   Useful tool for unifying a Format and Length using a Fix where Fix
%   typically matches a Min-Max pair. The Fix can also have the
%   shift(Bits, Left) form where the amount of Left shift implies the
%   minimum and maximum range.

fix_format_length(Fix, Format, Length), var(Format) =>
    fix_min_max(Fix, Min, Max),
    Format is Min + Length,
    Format >= Min,
    Format =< Max.
fix_format_length(Fix, Format, Length) =>
    fix_min_max(Fix, Min, Max),
    Format >= Min,
    Format =< Max,
    Length is Format - Min.

fix_min_max(Min-Max, Min, Max) => true.
fix_min_max(shift(Bits, Left), Min, Max) =>
    Min is Bits << Left,
    Max is Min \/ ((1 << Left) - 1).
