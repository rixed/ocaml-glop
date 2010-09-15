open Glop_intf
open Glop_base
open Algen_intf

module Extension (GB : GLOPBASE) =
struct
	module Ke = ExtendedField (GB.K)
	module Me = ExtendedMatrix (GB.M)

	let last_projection = ref Me.zero
	let last_modelview  = ref Me.zero
	let last_viewport   = ref (0, 0, 0, 0)
	let set_projection m = last_projection := m ; GB.set_projection m
	let set_modelview m = last_modelview := m ; GB.set_modelview m
	let set_viewport x y w h = last_viewport := (x, y, w, h) ; GB.set_viewport x y w h
	let get_projection () = !last_projection
	let get_modelview () = !last_modelview
	let get_viewport () = !last_viewport

	let vertex_array_init len f =
		let arr = GB.make_vertex_array len in
		for c = 0 to len-1 do
			GB.vertex_array_set arr c (f c)
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

module Glop (Dim : CONF_INT) :
	GLOP with module V.Dim = Dim =
struct
	module GB = GlopBase (Glop_spec.Spec (Dim))
	include GB
	include Extension (GB)
end

module Dim2D : CONF_INT = struct let v = 2 end
module Dim3D : CONF_INT = struct let v = 3 end

module Glop2D = Glop (Dim2D)
module Glop3D = Glop (Dim3D)


