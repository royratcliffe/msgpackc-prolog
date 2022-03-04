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

test(msgpack_objects, [true(A == [nil, false, true])]) :-
    phrase(msgpack_objects(A), [0xc0, 0xc2, 0xc3]).
test(msgpack_objects, [true(A == [0xc0, 0xc2, 0xc3])]) :-
    phrase(msgpack_objects([nil, false, true]), A).

:- end_tests(msgpackc).
