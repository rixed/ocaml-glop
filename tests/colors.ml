(* Display red, green and blue squares in order to test colors (and basic geometry. *)
open Glop_impl.Glop2D

let mone = K.neg K.one

let square x =
	let sqp = K.half (K.half (K.half K.one)) in
	let sqm = K.neg sqp in
	let sq = [|
		[| sqp ; sqp |] ;
		[| sqm ; sqp |] ;
		[| sqm ; sqm |] ;
		[| sqp ; sqm |]
	|]
	and disp = [| x ; K.zero |] in
	vertex_array_init 4 (fun i -> V.add sq.(i) disp)

let main =
	init "color test" 800 480 ;
	
	let modelview = M.id in
	modelview.(3).(2) <- K.half mone ;
	set_modelview modelview ;
	set_projection (M.ortho mone K.one mone K.one K.zero (K.add K.one K.one)) ;
	let z_near, z_far = K.of_float 0.5, K.of_float 5. in
	
	let rec frame_loop () =
		match next_event_with_resize true z_near z_far with
		| Some (Clic _) -> ()
		| _ ->
			clear ~color:black () ;
			let d = K.half K.one in
			render Triangle_fans (square (K.neg d)) (Uniq red) ;
			render Triangle_fans (square K.zero) (Uniq green) ;
			render Triangle_fans (square d) (Uniq blue) ;
			swap_buffers () ;
			frame_loop () in
	frame_loop () ;
	exit ()

