opam-version: "2.0"
maintainer: "weng@cs.jhu.edu"
authors: "MSR"
homepage: "https://github.com/Z3prover/z3"
bug-reports: "https://github.com/Z3prover/z3/issues"
license: "MIT"
dev-repo: "git+https://github.com/Z3prover/z3.git"
patches: [
  "gccstd-2a.patch" { (os-family = "opensuse" | os-family = "suse") | (os-distribution = "ubuntu" & os-version <= "20.04") }
]
build: [
  [
    "sh" "-ec"
    "B=${CANARY_BUILD_DIR:-build} && S=${CANARY_SRC_DIR:-.} && \
  if [ -f \"$B/src/api/ml/z3ml.cmxa\" ]; then \
    echo \"z3 OCaml bindings already built in $B, skipping cmake+ninja\"; \
  else \
    SCCACHE=$(command -v sccache 2>/dev/null || true); \
    SCCACHE_FLAGS=\"\"; [ -n \"$SCCACHE\" ] && SCCACHE_FLAGS=\"-DCMAKE_C_COMPILER_LAUNCHER=$SCCACHE -DCMAKE_CXX_COMPILER_LAUNCHER=$SCCACHE\" || true; \
    MOLD=$(command -v mold 2>/dev/null || true); \
    MOLD_FLAGS=\"\"; [ -n \"$MOLD\" ] && MOLD_FLAGS=\"-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=mold -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=mold\" || true; \
    cmake -S $S -B $B %%Z3_CMAKE_BUILD_FLAGS%% \
      -DZ3_BUILD_OCAML_BINDINGS=ON \
      $SCCACHE_FLAGS $MOLD_FLAGS && \
    ninja -C $B build_z3_ocaml_bindings; \
  fi"
  ]
]

install: [
  [ "sh" "-c" "B=${CANARY_BUILD_DIR:-build} && ocamlfind install z3 \
    $B/src/api/ml/*.mli \
    $B/src/api/ml/*.cm* \
    $B/src/api/ml/*.o \
    $B/src/api/ml/*.a \
    $B/src/api/ml/META \
    -dll $B/libz3.* \
    $B/src/api/ml/dllz3ml.so"
     ]
  ["install_name_tool" "-id" "%{lib}%/stublibs/libz3.dylib" "%{lib}%/stublibs/libz3.dylib"] {os = "macos"}
  [ "sh" "-c"
    "
    LIBZ3_KEY=$(otool -L '%{lib}%/stublibs/dllz3ml.so' | awk '/libz3.*dylib/ { print $1 }')
    install_name_tool -change \"$LIBZ3_KEY\" \"%{lib}%/stublibs/libz3.dylib\" \"%{lib}%/stublibs/dllz3ml.so\"
    "
  ] {os = "macos"}
]

remove: ["ocamlfind" "remove" "z3"]

depends: [
  "ocaml" {>= "4.08.0"}
  "ocamlfind" {build}
  "zarith"
  "conf-cmake" {build}
  "conf-ninja" {build}
  "conf-python-3" {build}
  "conf-c++" {build}
  "conf-gmp" {build}
]
conflicts: [
  "ocaml-option-bytecode-only"
]
synopsis: "Z3 solver (development version)"
url {
  src: "%{CANARY_Z3_SRC}%"
}
extra-source "gccstd-2a.patch" {
  src:
    "https://raw.githubusercontent.com/ocaml/opam-source-archives/main/patches/z3/gccstd-2a.patch"
  checksum:
    "sha256=ae4088ff14739bcc2cadc90bc428f08277e898b832f6b859a46e23c584d513c8"
}
