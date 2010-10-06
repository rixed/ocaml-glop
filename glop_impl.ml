open Glop_intf
open Glop_base
open Algen_intf

module Extension (GB : GLOPBASE) =
struct
	module Ke = ExtendedField (GB.K)
	module Me = ExtendedMatrix (GB.M)
	module MO = MatrixOps (GB.M) (GB.M)

	let proj_stack = ref [ Me.id ]
	let model_stack  = ref [ Me.id ]
	let last_viewport   = ref (0, 0, 0, 0)

	(* Set current matrix to the top of the stack *)
	let set_proj ()  = GB.set_projection (List.hd !proj_stack)
	let set_model () = GB.set_modelview  (List.hd !model_stack)

	(* Alter matrix stack and reset currnet matrix *)
	let set_projection m   = proj_stack  := m :: (List.tl !proj_stack) ; set_proj ()
	let set_modelview m    = model_stack := m :: (List.tl !model_stack) ; set_model ()
	let push_projection () = proj_stack  := (List.hd !proj_stack) :: !proj_stack
	let push_modelview ()  = model_stack := (List.hd !model_stack) :: !model_stack
	let pop_projection ()  = proj_stack  := List.tl !proj_stack ; set_proj ()
	let pop_modelview ()   = model_stack := List.tl !model_stack ; set_model ()
	let mult_projection m  = set_projection (MO.mul (List.hd !proj_stack) m)
	let mult_modelview m   = set_modelview  (MO.mul (List.hd !model_stack) m)
	let get_projection ()  = List.hd !proj_stack
	let get_modelview ()   = List.hd !model_stack
	
	(* For viewport we merely store the current value *)
	let set_viewport x y w h = last_viewport := (x, y, w, h) ; GB.set_viewport x y w h
	let get_viewport ()   = !last_viewport

	let vertex_array_init len f =
		let arr = GB.make_vertex_array len in
		for c = 0 to len-1 do
			GB.vertex_array_set arr c (f c)
		done ;
		arr

	let color_array_init len f =
		let arr = GB.make_color_array len in
		for c = 0 to len-1 do
			GB.color_array_set arr c (f c)
		done ;
		arr

	let set_projection_to_winsize z_near z_far w h =
		if w > 0 && h > 0 then (
			let x, y =
				if w > h then
					Ke.div (Ke.of_int w) (Ke.of_int h), Ke.one
				else
					Ke.one, Ke.div (Ke.of_int h) (Ke.of_int w) in
			let mat = GB.M.ortho (Ke.neg x) x (Ke.neg y) y z_near z_far in
			set_projection mat
		) ;
		set_viewport 0 0 w h
	
	let next_event_with_resize wait z_near z_far =
		match GB.next_event wait with
		| None -> None
		| Some (GB.Resize (w, h)) as ev ->
			set_projection_to_winsize z_near z_far w h ;
			ev
		| ev -> ev

	let project v transformation (x0, y0, width, height) =
		(* Extend given vector to 4 dimentions *)
		let vo = Array.init 4 (fun i ->
			if i < Array.length v then v.(i)
			else if i = 3 then Ke.one
			else Ke.zero) in
		(* mult by transformation to get clip coordinates *)
		let vc = Me.mul_vec transformation vo in
		(* perspective division to get device coordinate *)
		let vd = Array.init 3 (fun i -> Ke.div vc.(i) vc.(3)) in
		(* then center to viewport *)
		let half_w = width / 2
		and half_h = height / 2 in
		x0 + half_w + (Ke.to_int (Ke.mul (Ke.of_int half_w) vd.(0))),
		y0 + half_h + (Ke.to_int (Ke.mul (Ke.of_int half_h) vd.(1)))

	let unproject (x0, y0, width, height) transformation xw yw =
		(* inverse viewport to go from window coordinates to normalized device coordinates *)
		let nd_from_w win_coord win_start win_size =
			let w' = (win_coord - win_start) * 2 in
			Ke.sub (Ke.div (Ke.of_int w') (Ke.of_int win_size)) Ke.one in
		let xd = nd_from_w xw x0 width
		and yd = nd_from_w yw y0 height
		and zd = Ke.one in
		(* inverse perspective division to get clip coordinates *)
		let wc = Ke.one in
		let xc = Ke.mul xd wc
		and yc = Ke.mul yd wc
		and zc = Ke.mul zd wc in
		(* inverse transformation for eye/object coordinates *)
		let v = Me.inv_mul transformation [| xc ; yc ; zc ; wc |] in
		(* truncate to the firsts V.Dim.v coordinates *)
		Array.sub v 0 GB.V.Dim.v

end

module Glop (Dim : CONF_INT) (CDim: CONF_INT) :
	GLOP with module V.Dim = Dim
	     and module C.Dim = CDim =
struct
	module GB = GlopBase (Glop_spec.Spec (Dim) (CDim))
	include GB
	include Extension (GB)
end

module Dim2D : CONF_INT = struct let v = 2 end
module Dim3D : CONF_INT = struct let v = 3 end
module Dim4D : CONF_INT = struct let v = 4 end

module Glop2D = Glop (Dim2D) (Dim3D)
module Glop3D = Glop (Dim3D) (Dim3D)
module Glop2Dalpha = Glop (Dim2D) (Dim4D)
module Glop3Dalpha = Glop (Dim3D) (Dim4D)

