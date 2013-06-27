open Glop_intf
open Bricabrac

module Make (Glop : GLOP) =
struct
	type painter = unit -> unit

	(* A positionner gives the position of a view into its parent.
	 * It's thus the transformation from the view to its parent coord system. *)
	type transfo_dir = View_to_parent | Parent_to_view
	type positioner = transfo_dir -> Glop.M.t
	type viewable = {
		name             : string ;
		painter          : painter ;
		positioner       : positioner ;
		mutable parent   : viewable option ;
		mutable children : viewable list
	}

	let rec viewable_set_parent ?parent view =
		match parent with
		| None ->
			(match view.parent with
			| None -> ()
			| Some prev_parent ->
				view.parent <- None ;
				prev_parent.children <-
					List.filter (( != ) view) prev_parent.children)
		| Some new_parent ->
			(match view.parent with
			| None ->
				view.parent <- parent ;
				new_parent.children <- (view::new_parent.children)
			| Some _ ->
				viewable_set_parent view ;
				viewable_set_parent ~parent:new_parent view)

	let make_viewable ?parent name painter positioner = 
		let viewable =
			{ name = name ;
			  painter = painter ;
			  positioner = positioner ;	(* matrix transforming coords from this viewable to parent *)
			  parent = None ;
			  children = [] } in
		viewable_set_parent ?parent viewable ;
		viewable

	(* Sets the modelview to transform from root to dst, and returns root *)
	let root_to_viewable dst =
		let rec to_root pos = match pos.parent with
			| None -> pos
			| Some parent ->
				Glop.mult_modelview (pos.positioner Parent_to_view) ;
				to_root parent in
		to_root dst

	let viewable_to_root src =
		let rec prepend_next_view root2src view = match view.parent with
			| None -> root2src
			| Some parent -> prepend_next_view (view::root2src) parent in
		let root2src = prepend_next_view [] src in
		List.iter (fun view -> Glop.mult_modelview (view.positioner View_to_parent)) root2src

	(* Returns the matrix that transform point coordinates in src to coordinates in dst *)
	let get_transform ?src ?dst () =
		Glop.push_modelview () ;
		Glop.set_modelview Glop.M.id ;
		(* start from current transfo = identity matrix
		 * then mult current transfo by all transverse positions from dst to root -> gives
		 * the transfo from root to dst *)
		may dst (compose ignore root_to_viewable);
		(* then mult this by transfo from root to src, ie all positioners from root to src *)
		may src viewable_to_root ;
		(* modelview is then :
		 * (VN->dst) o ... o (root->V1) o (vN->root) o ... o (v1->v2) o (src->v1)
		 * then read modelview with : 
		 * glGetFloatv (GL_MODELVIEW_MATRIX, matrix);
		 *)
		let m = Glop.get_modelview () in
		Glop.pop_modelview () ;
		m

	let draw_viewable camera =
		let rec aux pos =
			Glop.push_modelview () ;
			Glop.mult_modelview (pos.positioner View_to_parent) ;
			pos.painter () ;
			List.iter aux pos.children ;
			Glop.pop_modelview () in
		Glop.set_modelview Glop.M.id ;
		aux (root_to_viewable camera)

    (* Once in a drawer we may want to clip some objects.
     * This function returns the screen corner coordinates according to
     * current modelview/projection transformations *)
    let clip_coordinates () =
        let m = Glop.M.mul_mat (Glop.get_projection ()) (Glop.get_modelview ()) in
        let _,_,w,h as viewport = Glop.get_viewport () in
        let p00 = Glop.unproject viewport m 0 0
        and p10 = Glop.unproject viewport m w 0
        and p11 = Glop.unproject viewport m w h
        and p01 = Glop.unproject viewport m 0 h in
        p00, p10, p11, p01

	(* Some simple positioners : *)

	let identity _ = Glop.M.id

	let translator get_pos dir =
		let x, y, z = get_pos () in
		let m = Glop.M.translate x y z in
		if dir = View_to_parent then m else Glop.M.transverse m

	let scaler get_scale dir =
		let x, y, z = get_scale () in
		match dir with
		| View_to_parent -> Glop.M.scale x y z
		| Parent_to_view -> Glop.M.scale (Glop.K.inv x) (Glop.K.inv y) (Glop.K.inv z)

	let orientor get_orient dir =
		let c, s = get_orient () in
		let m =
			[| [| c ; s ; Glop.K.zero ; Glop.K.zero |] ;
			   [| Glop.K.neg s ; c ; Glop.K.zero ; Glop.K.zero |] ;
			   [| Glop.K.zero ; Glop.K.zero ; Glop.K.one ; Glop.K.zero |] ;
			   [| Glop.K.zero ; Glop.K.zero ; Glop.K.zero ; Glop.K.one |] |] in
		if dir = View_to_parent then m else Glop.M.transverse m

	let trans_orientor get_pos get_orient dir =
		let x, y, z = get_pos () in
		let c, s = get_orient () in
		let m =
			[| [| c ; s ; Glop.K.zero ; Glop.K.zero |] ;
			   [| Glop.K.neg s ; c ; Glop.K.zero ; Glop.K.zero |] ;
			   [| Glop.K.zero ; Glop.K.zero ; Glop.K.one ; Glop.K.zero |] ;
			   [| x ; y ; z ; Glop.K.one |] |] in
		if dir = View_to_parent then m else Glop.M.transverse m

	let rotator get_angle dir =
		let a = get_angle () in
		let c = Glop.K.of_float (cos a) in
		let s = Glop.K.of_float (sin a) in
		orientor (fun () -> c, s) dir

	let trans_rotator get_pos get_angle dir =
		let a = get_angle () in
		let c = Glop.K.of_float (cos a) in
		let s = Glop.K.of_float (sin a) in
		trans_orientor get_pos (fun () -> c, s) dir

	let display ?(title="View") ?(on_event=ignore) ?(width=800) ?(height=480) painters =
		let z_near = Glop.K.of_float 0.2 in	(* FIXME *)
		let z_far  = Glop.K.of_float 1.2 in
		let new_size_mutex = Mutex.create () in
		let new_size = ref None in
		let handle_event () =
			let ev = Glop.next_event true in
			(match ev with
				| Some Glop.Resize (w, h) ->
					with_mutex new_size_mutex (fun x -> new_size := x) (Some (w, h))
				| _ -> ()) ;
			may ev on_event in
		let event_thread () =
			forever handle_event () in
		let next_frame () =
			with_mutex new_size_mutex (fun () ->
				match !new_size with
					| Some (w, h) ->
						Glop.set_projection_to_winsize z_near z_far w h ;
						new_size := None
					| _ -> ()) () ;
			List.iter (apply ()) painters ;
			Glop.swap_buffers () in
		Glop.init title width height ;
		Glop.set_projection (Glop.M.ortho
							(Glop.K.neg Glop.K.one) Glop.K.one
							(Glop.K.neg Glop.K.one) Glop.K.one
							(Glop.K.neg Glop.K.one) Glop.K.one) ;
		ignore (Thread.create event_thread ()) ;
		forever next_frame ()
end

