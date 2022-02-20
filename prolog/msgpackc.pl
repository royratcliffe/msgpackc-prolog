/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Feb 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack_pack_to_codes/2,    % +Term,-Codes

            % +MemoryFile,+Term
            msgpack_pack_to_memory_file/2,

            msgpack_pack_object/2,      % +Stream,+Term
            msgpack_version_string/1,   % ?Version
            msgpack_version/1,          % ?Version
            msgpack_version/3           % ?Major,?Minor,?Revision
          ]).
:- use_foreign_library(foreign(msgpackc)).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  msgpack_pack_to_codes(+Term, -Codes) is det.
%
%   Packs Term to Codes via a temporary memory file.
%
%   Packs Term as an object but drops the `_object` from the predicate
%   functor for brevity.

msgpack_pack_to_codes(Term, Codes) :-
    setup_call_cleanup(
        new_memory_file(MemoryFile),
        (   msgpack_pack_to_memory_file(MemoryFile, Term),
            memory_file_to_codes(MemoryFile, Codes)
        ),
        free_memory_file(MemoryFile)
    ).

:- begin_tests(msgpack_pack_to_codes).

test(nil, [Codes == [0xc0]]) :- msgpack_pack_to_codes([], Codes).

:- end_tests(msgpack_pack_to_codes).

%!  msgpack_pack_to_memory_file(+MemoryFile, +Term) is det.
%
%   Packs to MemoryFile. Temporarily opens the memory file for octet
%   writing.

msgpack_pack_to_memory_file(MemoryFile, Term) :-
    setup_call_cleanup(
        open_memory_file(MemoryFile, write, Stream, [encoding(octet)]),
        msgpack_pack_object(Stream, Term),
        close(Stream)
    ).

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
