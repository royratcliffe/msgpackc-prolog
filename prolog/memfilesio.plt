:- begin_tests(memfilesio).
:- use_module(memfilesio).

test(with_io_error,
     [ setup(new_memory_file(MemoryFile)),
       error(io_error(write, _),
             context(_, 'Encoding cannot represent character')),
       cleanup(free_memory_file(MemoryFile))
     ]) :-
    string_codes(String, [22909]),
    with_output_to_memory_file(write(String), MemoryFile, [encoding(octet)]).
test(without_io_error,
     [ setup(new_memory_file(MemoryFile)),
       true(Size-Codes == 3-[0xe5, 0xa5, 0xbd]),
       cleanup(free_memory_file(MemoryFile))
     ]) :-
    string_codes(String, [22909]),
    with_output_to_memory_file(write(String), MemoryFile, [encoding(utf8)]),
    size_memory_file(MemoryFile, Size, octet),
    memory_file_to_codes(MemoryFile, Codes, octet).

test(memory_file_bytes, [true(Bytes == [1, 2, 3])]) :-
    memory_file_bytes(MemoryFile, [1, 2, 3]),
    memory_file_bytes(MemoryFile, Bytes).

:- end_tests(memfilesio).
