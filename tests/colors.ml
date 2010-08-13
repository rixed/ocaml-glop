(* Display red, green and blue squares in order to test colors (and basic geometry. *)
open Glop_impl.Glop2D

module Me = Algen_intf.ExtendedMatrix (M)
module Ke = Algen_intf.ExtendedField (K)

let mone = Ke.neg Ke.one

let square x =
	let sqp = Ke.half (Ke.half (Ke.half K.one)) in
	let sqm = Ke.neg sqp in
	let sq = [|
		[| sqp ; sqp |] ;
		[| sqm ; sqp |] ;
		[| sqm ; sqm |] ;
		[| sqp ; sqm |]
	|]
	and disp = [| x ; K.zero |] in
	vertex_array_init 4 (fun i -> V.add sq.(i) disp)

let main =
	init "color test" ;
	let black = K.zero, K.zero, K.zero, K.one
	and red   = K.one,  K.zero, K.zero, K.one
	and green = K.zero, K.one,  K.zero, K.one
	and blue  = K.zero, K.zero, K.one,  K.one in
	
	let modelview = Me.id in
	modelview.(3).(2) <- Ke.half mone ;
	set_modelview modelview ;
	set_projection (M.ortho mone K.one mone K.one K.zero (K.add K.one K.one)) ;
	let z_near, z_far = K.of_float 0.5, K.of_float 5. in
	
	let rec frame_loop () =
		clear ~color:black () ;
		let d = Ke.half K.one in
		render Triangle_fans (square (K.neg d)) (Uniq red) ;
		render Triangle_fans (square K.zero) (Uniq green) ;
		render Triangle_fans (square d) (Uniq blue) ;
		swap_buffers () ;
		match next_event_with_resize true z_near z_far with
			| Some (Clic _) -> ()
			| _ -> frame_loop () in
	frame_loop () ;
	exit ()

