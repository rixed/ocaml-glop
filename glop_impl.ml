open Glop_intf
open Glop_base
open Algen_intf

module Extension (GB : GLOPBASE) =
struct
	module Ke = ExtendedField (GB.K)

	let vertex_array_init len f =
		let arr = GB.make_vertex_array len in
		for c = 0 to len-1 do
			GB.vertex_array_set arr c (f c)
		done ;
		arr

	let set_projection_to_winsize z_near z_far w h =
		let x, y =
			if w > h then
				Ke.div (Ke.of_int w) (Ke.of_int h), Ke.one
			else
				Ke.one, Ke.div (Ke.of_int h) (Ke.of_int w) in
		let mat = GB.M.ortho (Ke.neg x) x (Ke.neg y) y z_near z_far in
		GB.set_projection mat
	
	let next_event_with_resize wait z_near z_far =
		match GB.next_event wait with
		| None -> None
		| Some (GB.Resize (w, h)) as ev ->
			set_projection_to_winsize z_near z_far w h ;
			ev
		| ev -> ev
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


