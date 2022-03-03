:- begin_tests(msgpackc).
:- use_module(msgpackc).

test(msgpack_object_nil, [true(A == [0xc0])]) :-
    phrase(msgpack_object(nil), A).
test(msgpack_object_nil, [true(A == nil)]) :-
    phrase(msgpack_object(A), [0xc0]).

:- end_tests(msgpackc).
