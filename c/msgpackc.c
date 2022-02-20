#include <SWI-Prolog.h>
#include <SWI-Stream.h>

#include "msgpack.h"

static functor_t float_1_functor;
static functor_t double_1_functor;

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
 * mimics the `write/2` predicate family where the stream comes first in
 * the argument list.
 *
 * What the C implementation calls a message packer is simply
 * encapsulates an opaque callback. It carries no other state. The
 * recursive object pack function encodes the packing mechanisms.
 */
static foreign_t
pack_object_2(term_t Stream, term_t Object)
{ int rc;
  IOSTREAM *s;
  msgpack_packer packer;
  if (!PL_get_stream(Stream, &s, SIO_OUTPUT)) PL_fail;
  if (s->encoding != ENC_OCTET)
  { return PL_release_stream(s)
        && PL_permission_error("msgpack_pack_object", "stream", Stream);
  }
  msgpack_packer_init(&packer, s, stream_write);
  switch (PL_term_type(Object))
  { case PL_ATOM:
      if (PL_unify_bool(Object, FALSE))
        rc = msgpack_pack_false(&packer);
      else
      if (PL_unify_bool(Object, TRUE))
        rc = msgpack_pack_true(&packer);
      else
        rc = PL_type_error("msgpack_pack_object", Object);
      break;
    case PL_INTEGER:
    { int i;
      if ((rc = PL_get_integer_ex(Object, &i)))
      { rc = msgpack_pack_int(&packer, i);
      }
      break;
    }
    case PL_FLOAT:
    case PL_DOUBLE:
    { double f;
      if ((rc = PL_get_float_ex(Object, &f)))
        rc = msgpack_pack_double(&packer, f);
      break;
    }
    case PL_NIL:
      rc = msgpack_pack_nil(&packer);
      break;
    case PL_BOOL:
    { int value;
      rc = PL_get_bool(Object, &value);
      if (!rc) break;
      rc = (value ? msgpack_pack_true : msgpack_pack_false)(&packer);
      break;
    }
    case PL_STRING:
    { const char *s;
      if ((rc = PL_get_chars(Object, &s, CVT_STRING|CVT_EXCEPTION|REP_UTF8)))
        rc = msgpack_pack_str_with_body(&packer, s, strlen(s));
      break;
    }
    case PL_TERM:
    { functor_t Functor;
      if ((rc = PL_get_functor(Object, &Functor)))
      { if (Functor == float_1_functor)
        { term_t Arg1 = PL_new_term_ref();
          if ((rc = PL_get_arg(1, Object, Arg1)))
          { double arg1;
            if ((rc = PL_get_float_ex(Arg1, &arg1)))
            { rc = msgpack_pack_float(&packer, arg1);
              break;
            }
          }
        } else
        if (Functor == double_1_functor)
        { term_t Arg1 = PL_new_term_ref();
          if ((rc = PL_get_arg(1, Object, Arg1)))
          { double arg1;
            if ((rc = PL_get_float_ex(Arg1, &arg1)))
            { rc = msgpack_pack_double(&packer, arg1);
              break;
            }
          }
        }
      }
    }
    default:
      rc = PL_type_error("msgpack_pack_object", Object);
  }
  return PL_release_stream(s) && rc;
}

/*
 * term_type(Term, ?Type:nonneg) is semidet.
 *
 * Useful for debugging the object pack switch above.
 *
 *      ?- msgpackc:term_type(false, A).
 *      A = 2.
 *
 * Type 2 is `PL_ATOM`. Booleans are just atoms that Prolog can
 * successfully interpret as true or false within certain contexts.
 */
static foreign_t
term_type_2(term_t Term, term_t Type)
{ return PL_unify_integer(Type, PL_term_type(Term));
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
{ float_1_functor = PL_new_functor_sz(PL_new_atom("float"), 1);
  double_1_functor = PL_new_functor_sz(PL_new_atom("double"), 1);
  PL_register_foreign("msgpack_pack_object", 2, pack_object_2, 0);
  PL_register_foreign("term_type", 2, term_type_2, 0);
  PL_register_foreign("msgpack_version_string", 1, version_string_1, 0);
  PL_register_foreign("msgpack_version", 1, version_1, 0);
  PL_register_foreign("msgpack_version", 3, version_3, 0);
}

install_t
uninstall_msgpackc()
{ ;
}
