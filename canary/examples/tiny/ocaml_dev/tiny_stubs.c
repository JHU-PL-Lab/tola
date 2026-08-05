#include <caml/mlvalues.h>
#include <caml/alloc.h>
#include <caml/memory.h>
#include "tiny.h"

CAMLprim value caml_tiny_sum(value a, value b) {
    CAMLparam2(a, b);
    CAMLreturn(Val_int(tiny_sum(Int_val(a), Int_val(b))));
}

CAMLprim value caml_tiny_diff(value a, value b) {
    CAMLparam2(a, b);
    CAMLreturn(Val_int(tiny_diff(Int_val(a), Int_val(b))));
}

CAMLprim value caml_tiny_get_offset(value unit) {
    CAMLparam1(unit);
    CAMLreturn(Val_int(tiny_offset));
}

/* DEV variant: consumer of the dev-only tiny_scale. The prototype is declared
   here rather than taken from tiny.h — this stub was "compiled against dev
   headers", so it still compiles when the assembled tree carries the stable
   header; the mismatch then manifests purely at LINK/DEPLOY time (undefined
   tiny_scale over a stable libtiny — c1's prediction). */
extern int tiny_scale(int a, int k);

CAMLprim value caml_tiny_scale(value a, value k) {
    CAMLparam2(a, k);
    CAMLreturn(Val_int(tiny_scale(Int_val(a), Int_val(k))));
}
