(* Build a GL wrapper with vector for 2D drawing *)
module Glop = Glop_impl.Glop2D
open Glop

module Me = Algen_intf.ExtendedMatrix (M)
module Ke = Algen_intf.ExtendedField (M.V.K)

let randcol () =
	let rand1 () = Ke.rand Ke.one in
	rand1 (), rand1 (), rand1 (), rand1 ()

let randc n =
	Ke.sub (Ke.rand (Ke.double n)) n

let main =
	Random.self_init () ;
	init "test" ;

	let mone = Ke.neg Ke.one in
	let modelview = Me.id in
	modelview.(3).(2) <- Ke.half mone ;
	set_modelview modelview ;
	let projection = Me.id in
	projection.(2).(2) <- mone ;
	projection.(2).(3) <- mone ;
	projection.(3).(3) <- Ke.zero ;
	set_projection projection ;

	let frame nb_vertices =
		let vx = vertex_array_init nb_vertices
			(fun _i -> Array.init 2 (fun _c -> randc Ke.one)) in
		clear ~color:(randcol ()) () ;
		render Triangle_fans vx (Uniq (randcol ())) ;
		render Line_strip vx (Uniq (randcol ())) ;
		swap_buffers () ;
		ignore (next_event false) in
	
	for i = 0 to 4 do
		frame 10 ;
		ignore (next_event true) ;
	done ;

	exit ()

