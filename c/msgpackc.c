#include <SWI-Prolog.h>
#include <SWI-Stream.h>

#include "msgpack.h"

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

/*
 * Writes octets to a Prolog output stream.
 *
 * Answers `TRUE` if the number of octets written matches the number
 * available; `FALSE` otherwise.
 */
static int
stream_write(void *data, const char *buf, size_t len)
{ return Sfwrite(buf, sizeof(*buf), len, data) == len;
}

/*
 * Argument order of stream-object rather than the other way around
 * mimics the write/2 predicate family where the stream comes first in
 * the argument list.
 *
 * What the C implementation calls a message packer is simply
 * encapsulates an opaque callback. It carries no other state. The
 * recursive object pack function encodes the packing mechanisms.
 */
static foreign_t
pack_object_2(term_t Stream, term_t Object)
{ IOSTREAM *s;
  msgpack_packer pk;
  if (!PL_get_stream(Stream, &s, SIO_OUTPUT)) PL_fail;
  if (s->encoding != ENC_OCTET)
  { return PL_release_stream(s)
        && PL_permission_error("msgpack_pack_object", "stream", Stream);
  }
  msgpack_packer_init(&pk, s, stream_write);
  switch (PL_term_type(Object))
  { case PL_NIL:
      msgpack_pack_nil(&pk);
      break;
  }
  return PL_release_stream(s);
}

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
                            _
        __   _____ _ __ ___(_) ___  _ __
        \ \ / / _ \ '__/ __| |/ _ \| '_ \
         \ V /  __/ |  \__ \ | (_) | | | |
          \_/ \___|_|  |___/_|\___/|_| |_|

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

static foreign_t
version_string_1(term_t Version)
{ return PL_unify_string_chars(Version, msgpack_version());
}

/*
 * msgpack_version(?Version:term) is semidet.
 *
 * The Version term is a compound, or more specifically, a nested binary
 * compound where the first argument unifies with the version Major and
 * the sub-compound unifies with `:(Minor, Revision)` in Prolog.
 *
 *    A:B:C =.. [:, A, B:C].
 */
static foreign_t
version_1(term_t Version)
{ return PL_unify_term(Version,
    PL_FUNCTOR_CHARS, ":", 2,
      PL_INT, msgpack_version_major(),
      PL_FUNCTOR_CHARS, ":", 2,
        PL_INT, msgpack_version_minor(),
        PL_INT, msgpack_version_revision());
}

/*
 * C performs early-out evaluation. In a series of logical
 * sub-expressions with logical AND operators, the first failure returns
 * its result. Failure here in the world of C means integer 0; any other
 * unification result indicates success.
 */
static foreign_t
version_3(term_t Major, term_t Minor, term_t Revision)
{ return PL_unify_integer(Major, msgpack_version_major())
      && PL_unify_integer(Minor, msgpack_version_minor())
      && PL_unify_integer(Revision, msgpack_version_revision());
}

install_t
install_msgpackc()
{ PL_register_foreign("msgpack_pack_object", 2, pack_object_2, 0);
  PL_register_foreign("msgpack_version_string", 1, version_string_1, 0);
  PL_register_foreign("msgpack_version", 1, version_1, 0);
  PL_register_foreign("msgpack_version", 3, version_3, 0);
}

install_t
uninstall_msgpackc()
{ ;
}
