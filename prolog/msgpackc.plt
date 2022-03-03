:- begin_tests(msgpackc).
:- use_module(msgpackc).

test(msgpack_nil, [true(A == [0xc0])]) :- phrase(msgpack([]), A).
test(msgpack_nil, [true(A == [])]) :- phrase(msgpack(A), [0xc0]).

:- end_tests(msgpackc).
