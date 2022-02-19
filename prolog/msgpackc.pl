/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Jan 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack_version/1,          % ?Version
            msgpack_version/3           % ?Major,?Minor,?Revision
          ]).
:- use_foreign_library(foreign(msgpackc)).

%!  msgpack_version(?Version:atom) is semidet.
%!  msgpack_version(?Major:integer, ?Minor:integer, ?Revision:integer)
%!  is semidet.
%
%   Currently-deployed version of Message Pack C library. Use this both
%   to access the current version atom, more typically, or else
%   semi-deterministically to test against a version prerequisite.

:- begin_tests(msgpack_version).

test(version, [A == '4.0.0']) :- msgpack_version(A).
test(version, [fail]) :- msgpack_version('3.0.0').

:- end_tests(msgpack_version).
