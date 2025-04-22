# Change Log

Uses [Semantic Versioning](https://semver.org/). Always [keep a change
log](https://keepachangelog.com/en/1.0.0/).

## [0.2.2] - 2025-04-21
### Fixed
- The predicate `msgpack_dict` will fail if the argument provided is not a
  dictionary.
- Latest SWI Prolog does not like `[0xcb|Bytes]`.

## [0.2.1] - 2022-05-21
### Changed
- Comment out misleading fail coverage
- Message Pack to MessagePack
- Clarify `msgpack_object//1` usage

## [0.2.0] - 2022-03-19
### Removed
- `memfilesio` module

## [0.1.1] - 2022-03-13
### Added
- More testing
- MIT license
### Fixed
- Floating-point from bytes

## [0.1.0] - 2022-03-06
### Added
- `msgpackc` module
- `memfilesio` module
