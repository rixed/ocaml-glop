(* Build a GL wrapper with vector for 2D drawing *)
open Glop_impl.Glop2D

module Me = Algen_intf.ExtendedMatrix (M)
module Ke = Algen_intf.ExtendedField (K)

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
	set_projection (M.ortho mone K.one mone K.one K.zero (K.add K.one K.one)) ;

	let frame nb_vertices =
		let vx = vertex_array_init nb_vertices
			(fun _i -> Array.init 2 (fun _c -> randc Ke.one)) in
		clear ~color:(randcol ()) () ;
		render Triangle_fans vx (Uniq (randcol ())) ;
		render Line_strip vx (Uniq (randcol ())) ;
		swap_buffers () ;
		ignore (next_event false) in
	
	let z_near, z_far = K.of_float 0.5, K.of_float 5. in
	
	let rec frame_loop () =
		frame 30 ;
		match next_event_with_resize true z_near z_far with
			| Some (Clic _) -> ()
			| _ -> frame_loop () in
	frame_loop () ;

	exit ()

