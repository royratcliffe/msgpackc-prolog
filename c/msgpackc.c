#include <SWI-Prolog.h>
#include <SWI-Stream.h>

#include "msgpack.h"

foreign_t version1(term_t Version)
{ return PL_unify_atom_chars(Version, msgpack_version());
}

/*
 * C performs early-out evaluation. In a series of logical
 * sub-expressions with logical AND operators, the first failure returns
 * its result. Failure here in the world of C means integer 0; any other
 * unification result indicates success.
 */
foreign_t version3(term_t Major, term_t Minor, term_t Revision)
{ return PL_unify_integer(Major, msgpack_version_major())
      && PL_unify_integer(Minor, msgpack_version_minor())
      && PL_unify_integer(Revision, msgpack_version_revision());
}

install_t install_msgpackc()
{ PL_register_foreign("msgpack_version", 1, version1, 0);
  PL_register_foreign("msgpack_version", 3, version3, 0);
}

install_t uninstall_msgpackc()
{ ;
}
