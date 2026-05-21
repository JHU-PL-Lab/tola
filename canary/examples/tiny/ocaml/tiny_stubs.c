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
