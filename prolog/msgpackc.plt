:- begin_tests(msgpackc).
:- use_module(msgpackc).

test(msgpack_object_nil, [true(A == [0xc0])]) :-
    phrase(msgpack_object(nil), A).
test(msgpack_object_nil, [true(A == nil)]) :-
    phrase(msgpack_object(A), [0xc0]).

test(msgpack_object_fixint, [true(A == [0xff])]) :-
    phrase(msgpack_object(-1), A).
test(msgpack_object_fixint, [true(A == [0x7f])]) :-
    phrase(msgpack_object(127), A).

test(bin, [true(A == [0xc4, 0])]) :-
    phrase(msgpackc:msgpack_bin([]), A).
test(bin, [true(A == [0xc4, 3, 1, 2, 3])]) :-
    phrase(msgpackc:msgpack_bin([1, 2, 3]), A).
test(bin, [true(A == [])]) :-
    phrase(msgpackc:msgpack_bin(A), [0xc4, 0]).
test(bin, [true(A == [1, 2, 3])]) :-
    phrase(msgpackc:msgpack_bin(A), [0xc4, 3, 1, 2, 3]).

test(msgpack_objects, [true(A == [nil, false, true]), nondet]) :-
    phrase(msgpack_objects(A), [0xc0, 0xc2, 0xc3]).
test(msgpack_objects, [true(A == [0xc0, 0xc2, 0xc3])]) :-
    phrase(msgpack_objects([nil, false, true]), A).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
C implements the float32//1 and float64//1 predicates.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

test(float32, [true(A-B == [0, 0, 0, 0|B]-B)]) :-
    msgpackc:float32(0, A, B).
test(float32, [true(A == [63, 128, 0, 0])]) :-
    phrase(msgpackc:float32(1.0), A).
test(float32, [true(A-B == [127, 128, 0, 0]- 1.0Inf)]) :-
    phrase(msgpackc:float32(1.0Inf), A),
    phrase(msgpackc:float32(B), A).
test(float32, [true(A == [127, 192, 0, 0])]) :-
    NaN is nan,
    phrase(msgpackc:float32(NaN), A).
test(float32, [true(A == 1.5NaN)]) :-
    phrase(msgpackc:float32(A), [0x7f, 0xff, 0xff, 0xff]).

test(uint, all(A-B == [ 8-[0],
                        16-[0,0],
                        32-[0,0,0,0],
                        64-[0,0,0,0,0,0,0,0]
                      ])) :-
    phrase(msgpackc:uint(A, 0), B).

test(int, all(A-B == [ 8-[0xff],
                       16-[0xff,0xff],
                       32-[0xff,0xff,0xff,0xff],
                       64-[0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff]
                     ])) :-
    phrase(msgpackc:int(A, -1), B).

test(msgpack_fixstr, true(A == "")) :-
    phrase(msgpack_fixstr(A), [0b101 00000]).
test(msgpack_fixstr, true(A == "hello")) :-
    phrase(msgpack_fixstr(A), [0b101 00101|`hello`]).
test(msgpack_fixstr, true(B == "hello")) :-
    phrase(msgpack_fixstr("hello"), A),
    phrase(msgpack_fixstr(B), A).
test(msgpack_fixstr, true(B == [163, 229, 165, 189])) :-
    string_codes(A, [22909]), phrase(msgpack_fixstr(A), B).

:- end_tests(msgpackc).
