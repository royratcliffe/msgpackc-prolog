/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Feb 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack_pack_object/2,      % +Stream,+Term
            msgpack_version_string/1,   % ?Version
            msgpack_version/1,          % ?Version
            msgpack_version/3           % ?Major,?Minor,?Revision
          ]).
:- use_foreign_library(foreign(msgpackc)).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_pack_object(+Stream, +Term) is det.
%
%   Throws a permission error if Stream does *not* have octet encoding.
%   Hence packing to `current_output` or `user_output` fails since its
%   encoding is typically something else, e.g. `wchar_t` on Windows or
%   `utf8` on Linux flavours and macOS.
%
%       catch(msgpack_pack_object(user_output, []), error(A, B), true).
%
%   @throws permission_error

:- begin_tests(msgpack_pack).

test(permission_error, [error(permission_error(_, _, _))]) :-
    msgpack_pack_object(current_output, []).

:- end_tests(msgpack_pack).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_version_string(?Version:string) is semidet.
%
%   Currently-deployed version of Message Pack C library. Use this both
%   to access the current version atom, more typically, or else
%   semi-deterministically to test against a version prerequisite.

:- begin_tests(msgpack_version_string).

test(version_string, [A == "4.0.0"]) :- msgpack_version_string(A).
test(version_string, [fail]) :- msgpack_version_string("3.0.0").

:- end_tests(msgpack_version_string).

%!  msgpack_version(?Version) is semidet.
%!  msgpack_version(?Major:integer, ?Minor:integer, ?Revision:integer)
%!  is semidet.

:- begin_tests(msgpack_version).

test(version, [A:B:C == 4:0:0]) :- msgpack_version(A:B:C).
test(version, [A-B-C == 4-0-0]) :- msgpack_version(A, B, C).

:- end_tests(msgpack_version).
