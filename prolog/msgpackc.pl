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
            msgpack_str//1,                     % ?Str
            msgpack_fixstr//1,                  % ?Str
            msgpack_str//2,                     % ?Width,?Str

            msgpack_bin//2,                     % ?Width,?Bytes
            msgpack_bin//1                      % ?Bytes
          ]).
:- autoload(library(dcg/high_order), [sequence//2, sequence/4]).
:- autoload(library(utf8), [utf8_codes/3]).

:- use_foreign_library(foreign(msgpackc)).

:- use_module(memfilesio).

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

:- meta_predicate
    msgpack_array(3, ?, ?, ?),
    msgpack_map(3, ?, ?, ?),
    msgpack_dict(3, ?, ?, ?).

:- multifile type_ext_hook/3.

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
msgpack(bin(Bin)) --> msgpack_bin(Bin), !.
msgpack(array(Array)) --> msgpack_array(msgpack, Array), !.
msgpack(map(Map)) --> msgpack_map(msgpack_pair(msgpack, msgpack), Map), !.
msgpack(Term) --> msgpack_ext(Term).

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
%
%   Prolog has no native type for raw binary objects in the vein of R's
%   raw vector.

msgpack_object(nil) --> msgpack_nil, !.
msgpack_object(false) --> msgpack_false, !.
msgpack_object(true) --> msgpack_true, !.
msgpack_object(Int) -->
    msgpack_int(Int),
    { integer(Int)
    },
    !.
msgpack_object(Float) -->
    msgpack_float(Float),
    { float(Float)
    },
    !.
msgpack_object(Str) --> msgpack_str(Str), !.
msgpack_object(bin(MemoryFile)) --> msgpack_memory_file(MemoryFile), !.
msgpack_object(Array) --> msgpack_array(msgpack_object, Array), !.
msgpack_object(Map) -->
    msgpack_dict(msgpack_pair(msgpack_key, msgpack_object), Map),
    !.
msgpack_object(ext(Ext)) --> msgpack_ext(Ext).

msgpack_key(Key) --> msgpack_int(Key), !.
msgpack_key(Key) --> msgpack_str(Key).

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

%!  msgpack_int(?Int:integer)// is semidet.
%
%   Finds the optimum integer representation, shortest first. Tries
%   fixed integer at first which works for a small subset of integers
%   between -32 and 127. If that fails because the integer falls outside
%   that small range, the second attempt applies unsigned
%   representation; it only applies signed formats for negatives. This
%   assumes that the difference does not matter. An overlap exists
%   between signed and unsigned integers.

msgpack_int(Int) --> msgpack_fixint(_, Int), !.
msgpack_int(Int) -->
    { integer(Int),
      Int < 0,
      !
    },
    msgpack_int(_, Int).
msgpack_int(Int) --> msgpack_uint(_, Int), !.
msgpack_int(Int) --> msgpack_int(_, Int).

%!  msgpack_uint(?Width, ?Int)// is nondet.
%!  msgpack_int(?Width, ?Int)// is nondet.

msgpack_uint( 8, Int) --> [0xcc], byte(Int).
msgpack_uint(16, Int) --> [0xcd], uint16(Int).
msgpack_uint(32, Int) --> [0xce], uint32(Int).
msgpack_uint(64, Int) --> [0xcf], uint64(Int).

msgpack_int( 8, Int) --> [0xd0], int8(Int).
msgpack_int(16, Int) --> [0xd1], int16(Int).
msgpack_int(32, Int) --> [0xd2], int32(Int).
msgpack_int(64, Int) --> [0xd3], int64(Int).

%!  float(?Width, ?Float)// is nondet.
%!  uint(?Width, ?Int)// is nondet.
%!  int(?Width, ?Int)// is nondet.
%
%   Wraps the underlying C big- and little-endian support functions for
%   unifying bytes with floats and integers.

float(32, Float) --> float32(Float).
float(64, Float) --> float64(Float).

uint( 8, Int) --> uint8(Int).
uint(16, Int) --> uint16(Int).
uint(32, Int) --> uint32(Int).
uint(64, Int) --> uint64(Int).

int( 8, Int) --> int8(Int).
int(16, Int) --> int16(Int).
int(32, Int) --> int32(Int).
int(64, Int) --> int64(Int).

%!  msgpack_fixint(?Width, ?Int)// is semidet.
%
%   Width is the integer bit width, only 8 and never 16, 32 or 64.

msgpack_fixint(8, Int) --> fixint8(Int).

%!  fixint8(Int)// is semidet.
%
%   Very similar to int8//1 except for adding an additional constraint:
%   the Int must not fall below -32. All other constraints also
%   apply for signed 8-bit integers. Rather than falling between -128
%   and 127 however, the _fixed_ 8-bit integer does not overlap the bit
%   patterns reserved for other Message Pack type codes.

fixint8(Int) -->
    int8(Int),
    { Int >= -32
    }.

%!  byte(?Byte)// is semidet.
%!  uint8(?Int)// is semidet.
%!  int8(?Int)// is semidet.
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

uint8(Int) --> byte(Int).

int8(Int) -->
    byte(Int),
    { Int =< 0x7f
    },
    !.
int8(Int) -->
    { var(Int)
    },
    byte(Byte),
    { Byte >= 0x80,
      Int is Byte - 0x100
    },
    !.
int8(Int) -->
    { integer(Int),
      % Now that Int is non-variable and an integer, just reverse
      % the Int from Byte solution above: swap the sides, add 256 to
      % both sides and swap the compute and threshold comparison; at
      % this point Int must be negative. Grammar at byte//1 will
      % catch Int values greater than -1.
      Byte is 0x100 + Int
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

%!  msgpack_str(?Str)// is semidet.
%
%   Unifies Str with the shortest packed UTF-8 string message.

msgpack_str(Str) --> msgpack_fixstr(Str), !.
msgpack_str(Str) --> msgpack_str(_, Str), !.

%!  msgpack_fixstr(?Str)// is semidet.
%
%   Unifies Message Pack byte codes with fixed Str of length between
%   0 and 31 inclusive.

msgpack_fixstr(Str) -->
    { var(Str),
      !
    },
    byte(Format),
    { fixstr_format_length(Format, Length),
      length(Bytes, Length)
    },
    sequence(byte, Bytes),
    { phrase(utf8_codes(Codes), Bytes),
      string_codes(Str, Codes)
    }.
msgpack_fixstr(Str) -->
    { string(Str),
      string_codes(Str, Codes),
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

%!  msgpack_str(?Width, ?Str)// is semidet.
%
%   Refactors common string-byte unification utilised by all string
%   grammars for the Message Pack protocol's 8, 16 and 32 bit lengths.
%   Unifies for Length number of bytes for Str. Length is *not* the
%   length of Str in Unicodes but the number of bytes in its UTF-8
%   representation.

msgpack_str(Width, Str) -->
    { var(Str),
      !,
      str_width_format(Width, Format)
    },
    [Format],
    uint(Width, Length),
    { length(Bytes, Length)
    },
    sequence(byte, Bytes),
    { phrase(utf8_codes(Codes), Bytes),
      string_codes(Str, Codes)
    }.
msgpack_str(Width, Str) -->
    { string(Str),
      str_width_format(Width, Format),
      string_codes(Str, Codes),
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
    { is_list(Array),
      length(Array, Length),
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

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    map format family

    +--------+~~~~~~~~~~~~~~~~~+
    |1000XXXX|   X*2 objects   | fixmap
    +--------+~~~~~~~~~~~~~~~~~+

    +--------+--------+--------+~~~~~~~~~~~~~~~~~+
    |  0xde  |YYYYYYYY|YYYYYYYY|   Y*2 objects   | map 16
    +--------+--------+--------+~~~~~~~~~~~~~~~~~+

    +--------+--------+--------+--------+--------+~~~~~~~~~~~~~~~~~+
    |  0xdf  |ZZZZZZZZ|ZZZZZZZZ|ZZZZZZZZ|ZZZZZZZZ|   Z*2 objects   | 32
    +--------+--------+--------+--------+--------+~~~~~~~~~~~~~~~~~+

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

msgpack_map(OnPair, Map) --> msgpack_fixmap(OnPair, Map), !.
msgpack_map(OnPair, Map) --> msgpack_map(OnPair, _, Map), !.

msgpack_fixmap(OnPair, Map) -->
    { var(Map),
      !
    },
    [Format],
    { fixmap_format_length(Format, Length),
      length(Map, Length)
    },
    sequence(OnPair, Map).
msgpack_fixmap(OnPair, Map) -->
    { is_list(Map),
      length(Map, Length),
      fixmap_format_length(Format, Length)
    },
    [Format],
    sequence(OnPair, Map).

fixmap_format_length(Format, Length) :-
    fix_format_length(shift(0b1000, 4), Format, Length).

msgpack_map(OnPair, Width, Map) -->
    { var(Map),
      !,
      map_width_format(Width, Format)
    },
    [Format],
    uint(Width, Length),
    { length(Map, Length)
    },
    sequence(OnPair, Map).
msgpack_map(OnPair, Width, Map) -->
    { is_list(Map),
      map_width_format(Width, Format),
      length(Map, Length)
    },
    [Format],
    uint(Width, Length),
    sequence(OnPair, Map).

map_width_format(16, 0xde).
map_width_format(32, 0xdf).

msgpack_pair(OnKey, OnValue, Key-Value) -->
    call(OnKey, Key),
    call(OnValue, Value).

msgpack_dict(OnPair, Dict) -->
    { var(Dict),
      !
    },
    msgpack_map(OnPair, Pairs),
    { dict_create(Dict, _, Pairs)
    }.
msgpack_dict(OnPair, Dict) -->
    { dict_pairs(Dict, _, Pairs)
    },
    msgpack_map(OnPair, Pairs).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    ext format family

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_ext(?Term)// is semidet.
%
%   In (++) mode, meaning fully ground with no variables, the ++Term
%   first unifies Term with its Type and Ext bytes using
%   msgpack:type_ext_hook/3 multi-file predicate.

msgpack_ext(Term) -->
    { ground(Term),
      !,
      type_ext_hook(Type, Ext, Term)
    },
    msgpack_ext(Type, Ext).
msgpack_ext(Term) -->
    msgpack_ext(Type, Ext),
    !,
    { type_ext_hook(Type, Ext, Term)
    }.

msgpack_ext(Type, Ext) --> msgpack_fixext(Type, Ext), !.
msgpack_ext(Type, Ext) --> msgpack_ext(_, Type, Ext), !.

msgpack_fixext(Type, Ext) -->
    { var(Type),
      var(Ext),
      !,
      fixext_length_format(Length, Format)
    },
    [Format],
    int8(Type),
    { length(Ext, Length)
    },
    sequence(byte, Ext).
msgpack_fixext(Type, Ext) -->
    { integer(Type),
      is_list(Ext),
      fixext_length_format(Length, Format),
      length(Ext, Length)
    },
    [Format],
    int8(Type),
    sequence(byte, Ext).

fixext_length_format( 1, 0xd4).
fixext_length_format( 2, 0xd5).
fixext_length_format( 4, 0xd6).
fixext_length_format( 8, 0xd7).
fixext_length_format(16, 0xd8).

msgpack_ext(Width, Type, Ext) -->
    { var(Ext),
      !,
      ext_width_format(Width, Format)
    },
    [Format],
    uint(Width, Length),
    int8(Type),
    { length(Ext, Length)
    },
    sequence(byte, Ext).
msgpack_ext(Width, Type, Ext) -->
    { integer(Type),
      is_list(Ext),
      ext_width_format(Width, Format),
      length(Ext, Length)
    },
    [Format],
    uint(Width, Length),
    int8(Type),
    sequence(byte, Ext).

ext_width_format( 8, 0xc7).
ext_width_format(16, 0xc8).
ext_width_format(32, 0xc9).

%!  type_ext_hook(Type:integer, Ext:list, Term) is semidet.
%
%   Parses the extension byte block.
%
%   The timestamp extension encodes seconds and nanoseconds since 1970,
%   also called Unix epoch time. Three alternative encodings exist: 4
%   bytes, 8 bytes and 12 bytes.

type_ext_hook(-1, Ext, timestamp(Epoch)) :-
    once(phrase(timestamp(Epoch), Ext)).

timestamp(Epoch) -->
    { var(Epoch)
    },
    int32(Epoch).
timestamp(Epoch) -->
    { var(Epoch)
    },
    uint64(UInt64),
    { NanoSeconds is UInt64 >> 34,
      NanoSeconds < 1 000 000 000,
      Seconds is UInt64 /\ ((1 << 34) - 1),
      tv(Epoch, Seconds, NanoSeconds)
    }.
timestamp(Epoch) -->
    { var(Epoch)
    },
    int32(NanoSeconds),
    int64(Seconds),
    { tv(Epoch, Seconds, NanoSeconds)
    }.
timestamp(Epoch) -->
    { number(Epoch),
      tv(Epoch, Seconds, 0)
    },
    int32(Seconds).
timestamp(Epoch) -->
    { number(Epoch),
      Epoch >= 0,
      tv(Epoch, Seconds, NanoSeconds),
      Seconds < (1 << 34),
      UInt64 is (NanoSeconds << 34) \/ Seconds
    },
    uint64(UInt64).
timestamp(Epoch) -->
    { number(Epoch),
      tv(Epoch, Seconds, NanoSeconds)
    },
    int32(NanoSeconds),
    int64(Seconds).

%!  tv(Epoch, Sec, NSec) is det.
%
%   Uses floor/1 when computing NSec. Time only counts completed
%   nanoseconds and time runs up. Asking for the integer part of a float
%   does *not* give an integer.

tv(Epoch, Sec, NSec), var(Epoch) =>
    abs(NSec) < 1 000 000 000,
    Epoch is Sec + (NSec / 1e9).
tv(Epoch, Sec, NSec), number(Epoch) =>
    Sec is floor(float_integer_part(Epoch)),
    NSec is floor(1e9 * float_fractional_part(Epoch)).

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
fix_format_length(Fix, Format, Length), integer(Format) =>
    fix_min_max(Fix, Min, Max),
    Format >= Min,
    Format =< Max,
    Length is Format - Min.

fix_min_max(Min-Max, Min, Max) => true.
fix_min_max(shift(Bits, Left), Min, Max) =>
    Min is Bits << Left,
    Max is Min \/ ((1 << Left) - 1).
