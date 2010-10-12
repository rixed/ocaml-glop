open Glop_impl.Glop2D

let randcol () =
	let rand1 () = K.rand K.one in
	[| rand1 (); rand1 (); rand1 (); rand1 () |]

let randc n =
	K.sub (K.rand (K.double n)) n

let main =
	Random.self_init () ;
	
	let frame nb_vertices =
		let vx = vertex_array_init nb_vertices
			(fun _i -> Array.init 2 (fun _c -> randc K.one)) in
		clear ~color:(randcol ()) () ;
		render Triangle_fans vx (Uniq (randcol ())) ;
		render Line_strip vx (Uniq (randcol ())) ;
		swap_buffers () in
	
	let z_near, z_far = K.of_float 0.5, K.of_float 5. in
	
	let new_size_mutex = Mutex.create () in
	let new_size = ref None in

	let rec event_loop () =
		match next_event true with
		| Some (Clic _) -> ()
		| Some (Resize (w, h)) ->
			Mutex.lock new_size_mutex ;
			new_size := Some (w, h) ;	(* Can't resize from this thread *)
			Mutex.unlock new_size_mutex ;
			event_loop ()
		| _ -> event_loop () in

	let rec frame_loop () =
		Mutex.lock new_size_mutex ;
		(match !new_size with
		| Some (w, h) ->
			set_projection_to_winsize z_near z_far w h ;
			new_size := None
		| _ -> ()) ;
		Mutex.unlock new_size_mutex ;
		frame 30 ;
		Thread.delay 0.2 ;
		frame_loop () in

	let rec gl_thread () =
		(* Only the thread that performs the init must call drawing functions *)
		init "test" 800 480 ;
		let mone = K.neg K.one in
		let modelview = M.id in
		modelview.(3).(2) <- K.half mone ;
		set_modelview modelview ;
		set_projection (M.ortho mone K.one mone K.one K.zero (K.add K.one K.one)) ;
		frame_loop () in

	ignore (Thread.create gl_thread ()) ;
	Thread.join (Thread.create event_loop ()) ;
	exit ()

