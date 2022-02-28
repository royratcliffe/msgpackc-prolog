:- use_module(library(prolog_pack), []).
:- use_module(library(dcg/basics)).
:- use_module(library(clpfd), [transpose/2]).

pack_info(BaseDir, Term) :-
  once(prolog_pack:pack_info_term(BaseDir, Term)).

%!  load_pack_modules(+Pack, -Modules) is semidet.
%
%   Finds and loads all Prolog module sources  for Pack. Also loads test
%   files having once  loaded  the  pack.   Modules  becomes  a  list of
%   successfully-loaded pack modules.

load_pack_modules(Pack, Modules) :-
  pack_property(Pack, directory(Directory)),
  findall(Module, load_prolog_module(Directory, Module), Modules),
  load_test_files([]).

%!  load_prolog_module(+Directory, -Module) is nondet.
%
%   Loads Prolog source recursively at Directory  for Module. Does *not*
%   load non-module sources, e.g.  scripts   without  a module. Operates
%   non-deterministically for Module. Finds and   loads  all the modules
%   within  a  given  directory;  typically  amounts   to  a  pack  root
%   directory. You can find the File from  which the module loaded using
%   module properties, i.e. `module_property(Module, file(File))`.

load_prolog_module(Directory, Module) :-
  directory_member(Directory, File, [file_type(prolog), recursive(true)]),
  catch(load_files(File, [must_be_module(true)]), _, fail),
  module_property(Module, file(File)).

:- initialization(cov).

cov :-
    module_coverages(ModuleCoverages),
    print_module_coverages(ModuleCoverages),
    aggregate_all(
        all(sum(Clauses), sum(Cov), sum(Fail), count),
        member(_-coverage{
                     clauses:Clauses,
                     cov:Cov,
                     fail:Fail
                 }, ModuleCoverages),
        all(AllClauses, AllCov, AllFail, AllModule)),
    AvgCov is AllCov / AllModule,
    AvgFail is AllFail / AllModule,
    format('Modules:~t~d~40|~n', [AllModule]),
    format('Clauses:~t~d~40|~n', [AllClauses]),
    format('Cov:~t~f~40|%~n', [AvgCov]),
    format('Fail:~t~f~40|%~n', [AvgFail]),
    (   getenv('CANNY_COV_GIST_ID', GistID)
    ->  shield_files([cov-AvgCov, fail-AvgFail], Files),
        ghapi_update_gist(GistID, json(json([files=Files])), _, [])
    ;   true
    ).

module_coverages(ModuleCoverages) :-
    pack_info(., name(Pack)),
    load_pack_modules(Pack, Modules),
    findall(
        Module-Coverage,
        coverage_for_modules(run_tests, Modules, Module, Coverage),
        ModuleCoverages).

print_module_coverages(ModuleCoverages) :-
    predsort(compare_cov_fail, ModuleCoverages, SortedModuleCoverages),
    print_table(
        member(
            Module-coverage{
                       clauses:Clauses,
                       cov:Cov,
                       fail:Fail
                   }, SortedModuleCoverages), [Module, Clauses, Cov, Fail]).

compare_cov_fail(Order, _-Coverage1, _-Coverage2) :-
    compare(Order0, Coverage1.cov, Coverage2.cov),
    compare_fail(Order, Order0, Coverage1.fail, Coverage2.fail),
    !.
compare_cov_fail(>, _, _).

compare_fail(<, <, _, _) :- !.
compare_fail(<, =, Fail1, Fail2) :- compare(>, Fail1, Fail2), !.
compare_fail(>, _, _, _).

shield_files(Pairs, json(Files)) :-
    maplist([Label-Percent, File=json([content=Content])]>>
            (   atom_concat(Label, '.json', File),
                format(atom(Message), '~1f%', [Percent]),
                shield_color(Percent, Color),
                atom_json_term(Content, json([ schemaVersion=1,
                                               label=Label,
                                               message=Message,
                                               color=Color
                                             ]), []),
                format('raw/~s~n', [File])
            ), Pairs, Files).

shield_color(Percent, red) :- Percent < 20, !.
shield_color(Percent, orange) :- Percent < 40, !.
shield_color(Percent, yellow) :- Percent < 60, !.
shield_color(Percent, yellowgreen) :- Percent < 80, !.
shield_color(_, green).

%!  coverages_by_module(:Goal, -Coverages:dict) is det.
%
%   Calls Goal within show_coverage/1  while   capturing  the  resulting
%   lines of output; Goal  is  typically   run_tests/0  for  running all
%   loaded tests. Parses the lines for   coverage  statistics by module.
%   Ignores lines that do not represent coverage, and also ignores lines
%   that cover non-module files.  Automatically matches prefix-truncated
%   coverage paths as well as full paths.
%
%   @arg Coverages is a  module-keyed   dictionary  of  sub-dictionaries
%   carrying three keys: clauses, cov and fail.

coverages_by_module(Goal, Coverages) :-
    with_output_to(string(String), show_coverage(Goal)),
    string_lines(String, Lines),
    convlist([Line, Module=coverage{
                               clauses:Clauses,
                               cov:Cov,
                               fail:Fail
                           }]>>
             (   string_codes(Line, Codes),
                 phrase(cover_line(Module, Clauses, Cov, Fail), Codes)
             ), Lines, Data),
    dict_create(Coverages, coverages, Data).

cover_line(Module, Clauses, Cov, Fail) -->
    cover_file(Module),
    whites,
    integer(Clauses),
    whites,
    number(Cov),
    whites,
    number(Fail).

cover_file(Module) -->
    "...",
    !,
    { module_property(Module, file(File)),
      sub_atom(File, _, _, 0, Suffix),
      atom_codes(Suffix, Codes)
    },
    string(Codes).
cover_file(Module) -->
    { module_property(Module, file(File)),
      atom_codes(File, Codes)
    },
    string(Codes).

%!  coverage_for_modules(:Goal, +Modules, -Module, -Coverage) is nondet.
%
%   Non-deterministically finds Coverage dictionaries   for all Modules.
%   Bypasses those modules excluded from   the  required list, typically
%   the list of modules belonging to a particular pack and excluding all
%   system and other supporting modules.

coverage_for_modules(Goal, Modules, Module, Coverage) :-
    coverages_by_module(Goal, Coverages),
    Coverage = Coverages.Module,
    memberchk(Module, Modules).

%!  print_table(:Goal) is det.
%!  print_table(:Goal, +Variables:list) is det.
%
%   Prints all the variables  within   the  given non-deterministic Goal
%   term  formatted  as   a   table    of   centre-padded   columns   to
%   =current_output=. One Goal  solution  becomes   one  line  of  text.
%   Solutions to free variables become printed cells.
%
%   Makes an important  assumption:  that   codes  equate  to  character
%   columns; one code, one column. This will  be true for most languages
%   on a teletype like terminal. Ignores any exceptions by design.
%
%       ?- print_table(user:prolog_file_type(_, _)).
%       +------+----------+
%       |  pl  |  prolog  |
%       |prolog|  prolog  |
%       | qlf  |  prolog  |
%       | qlf  |   qlf    |
%       | dll  |executable|
%       +------+----------+

print_table(Goal) :-
    term_variables(Goal, Variables),
    print_table(Goal, Variables).

print_table(Goal, Variables) :-
    findall(Variables, Goal, Rows0),
    maplist(
        maplist(
            [Column, Codes]>>
            with_output_to_codes(
                print(Column), Codes)), Rows0, Rows),
    transpose(Rows, Columns),
    maplist(maplist(length), Columns, Lengths),
    maplist(max_list, Lengths, Widths),
    print_border(Widths),
    forall(member(Row, Rows), print_row(Widths, Row)),
    print_border(Widths).

print_row(Widths, Row) :-
    zip(Widths, Row, Columns),
    forall(member(Column, Columns), print_column(Column)),
    put_code(0'|),
    nl.

print_column([Width, Column]) :-
    format('|~|~t~s~t~*+', [Column, Width]).

print_border(Widths) :-
    forall(member(Width, Widths), format('+~|~`-t~*+', [Width])),
    put_code(0'+),
    nl.

%!  zip(?List1:list, ?List2:list, ?ListOfLists:list(list)) is semidet.
%
%   Zips two lists, List1 and List2, where   each element from the first
%   list pairs with the same element from the second list. Alternatively
%   unzips one list of lists into two lists.
%
%   Only succeeds if the lists and sub-lists have matching lengths.

zip([], [], []).
zip([H1|T1], [H2|T2], [[H1, H2]|T]) :- zip(T1, T2, T).
