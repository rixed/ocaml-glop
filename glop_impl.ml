open Glop_intf
open Glop_base
open Algen_intf

module Extension (GB : GLOPBASE) =
struct
	let vertex_array_init len f =
		let arr = GB.make_vertex_array len in
		for c = 0 to len-1 do
			GB.vertex_array_set arr c (f c)
		done ;
		arr
end

module Glop (Dim : CONF_INT) :
	GLOP with module V.Dim = Dim =
struct
	module GB = GlopBase (Dim)
	include GB
	include Extension (GB)
end

module Dim2D : CONF_INT = struct let v = 2 end
module Dim3D : CONF_INT = struct let v = 3 end

module Glop2D = Glop (Dim2D)
module Glop3D = Glop (Dim3D)

