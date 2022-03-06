/*  File:    memfilesio.pl
    Author:  Roy Ratcliffe
    Created: Feb 26 2022
    Purpose: I/O on Memory Files

Copyright (c) 2022, Roy Ratcliffe, Northumberland, United Kingdom

Permission is hereby granted, free of charge,  to any person obtaining a
copy  of  this  software  and    associated   documentation  files  (the
"Software"), to deal in  the   Software  without  restriction, including
without limitation the rights to  use,   copy,  modify,  merge, publish,
distribute, sublicense, and/or sell  copies  of   the  Software,  and to
permit persons to whom the Software is   furnished  to do so, subject to
the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT  WARRANTY OF ANY KIND, EXPRESS
OR  IMPLIED,  INCLUDING  BUT  NOT   LIMITED    TO   THE   WARRANTIES  OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR   PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS  OR   COPYRIGHT  HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY,  WHETHER   IN  AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM,  OUT  OF   OR  IN  CONNECTION  WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

:- module(memfilesio,
          [ with_output_to_memory_file/3,       % :Goal,+MemoryFile,+Options
            memory_file_bytes/2,                % ?MemoryFile,?Bytes:list
            put_bytes/1                         % +Bytes:list
          ]).
:- meta_predicate
    with_output_to_memory_file(0, +, +).
:- predicate_options(with_output_to_memory_file/3, 3,
                     [ pass_to(open_memory_file/4, 4)
                     ]).

/** <module> I/O on Memory Files

== Bytes and octets

Both terms apply herein. Variable names reflect the subtle
but essential distinction. All octets are bytes but not all bytes are
octets. Byte is merely eight bits, nothing more implied, whereas octet
implies important inter-byte ordering according to some big- or
little-endian convention.

@author Roy Ratcliffe
*/

%!  with_output_to_memory_file(:Goal, +MemoryFile, +Options) is det.
%
%   Opens MemoryFile for writing. Calls Goal using once/1, writing to
%   =current_output= collected in MemoryFile according to the encoding
%   within Options. Defaults to UTF-8 encoding.

with_output_to_memory_file(Goal, MemoryFile, Options) :-
    setup_call_cleanup(
        open_memory_file(MemoryFile, write, Stream, Options),
        with_output_to(Stream, Goal),
        close(Stream)
    ).

%!  memory_file_bytes(?MemoryFile, ?Bytes:list) is det.
%
%   Unifies MemoryFile with Bytes.

memory_file_bytes(MemoryFile, Bytes), var(MemoryFile) =>
    new_memory_file(MemoryFile),
    with_output_to_memory_file(put_bytes(Bytes), MemoryFile,
                               [ encoding(octet)
                               ]).
memory_file_bytes(MemoryFile, Bytes) =>
    memory_file_to_codes(MemoryFile, Bytes, octet).

%!  put_bytes(+Bytes:list) is det.
%
%   Puts zero or more Bytes to current output.
%
%   A good reason exists for _putting bytes_ rather than writing codes.
%   The put_byte/1 predicate throws with permission error when writing
%   to a text stream. Bytes are *not* Unicode text; they have an
%   entirely different ontology.
%
%   @see Character representation manual section
%   at https://www.swi-prolog.org/pldoc/man?section=chars for more
%   details about the difference between codes, characters and bytes.

put_bytes([]) => true.
put_bytes([Byte|Bytes]) => put_byte(Byte), put_bytes(Bytes).

write_to_memory_file(Term, MemoryFile) :-
    new_memory_file(MemoryFile),
    with_output_to_memory_file(write(Term), MemoryFile, [encoding(octet)]).

%!  string_to_bytes(+String, -Bytes) is det.
%
%   String to Bytes via a temporary memory file used for UTF-8 to octet
%   encoding and decoding.

string_to_bytes(String, Bytes) :-
    setup_call_cleanup(
        new_memory_file(MemoryFile),
        (   with_output_to_memory_file(write(String), MemoryFile,
                                       [ encoding(utf8)
                                       ]),
            memory_file_to_codes(MemoryFile, Bytes, octet)
        ),
        free_memory_file(MemoryFile)
    ).
