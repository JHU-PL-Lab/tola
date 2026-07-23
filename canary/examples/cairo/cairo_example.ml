(* Small probe: exercise cairo2's Cairo API. Creates an ARGB32 image
   surface + drawing context, paints it, and finishes the surface.
   Verifies the OCaml binding loads, links to the system libcairo, and a
   few core entry points (surface create, context create, paint, finish)
   round-trip. Uses only decades-stable cairo calls. *)

let () =
  let surface = Cairo.Image.create Cairo.Image.ARGB32 ~w:16 ~h:16 in
  let cr = Cairo.create surface in
  Cairo.set_source_rgb cr 1.0 1.0 1.0;
  Cairo.paint cr;
  Cairo.Surface.finish surface;
  print_endline "cairo ok"
