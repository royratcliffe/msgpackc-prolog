:- begin_tests(msgpackc).
:- use_module(msgpackc).

test(msgpack_object_nil, [true(A == [0xc0])]) :-
    phrase(msgpack_object(nil), A).
test(msgpack_object_nil, [true(A == nil)]) :-
    phrase(msgpack_object(A), [0xc0]).

test(msgpack_objects, [true(A == [nil, false, true])]) :-
    phrase(msgpack_objects(A), [0xc0, 0xc2, 0xc3]).
test(msgpack_objects, [true(A == [0xc0, 0xc2, 0xc3])]) :-
    phrase(msgpack_objects([nil, false, true]), A).

:- end_tests(msgpackc).
