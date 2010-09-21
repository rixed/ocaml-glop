open Algen_intf
open Glop_base

module Spec
	(Dim : CONF_INT) :
	GLOPSPEC with module Dim = Dim
	         and type vertex_array = (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t =
struct
	module Dim = Dim
	module K = Algen_impl.FloatField
	type vertex_array = (float, Bigarray.float64_elt, Bigarray.c_layout) Bigarray.Array2.t
	let make_vertex_array nbv =
		Bigarray.Array2.create Bigarray.float64 Bigarray.c_layout nbv (Dim.v)
	let vertex_array_set arr i vec =
		Array.iteri (fun c v -> Bigarray.Array2.set arr i c v) vec
end

