/*  File:    msgpackc.pl
    Author:  Roy Ratcliffe
    Created: Jan 19 2022
    Purpose: C-Based Message Pack for SWI-Prolog
*/

:- module(msgpackc,
          [ msgpack//1
          ]).
:- use_foreign_library(foreign(msgpackc)).

%!  msgpack(?Term)// is semidet.

msgpack([]) --> [0xc0].
