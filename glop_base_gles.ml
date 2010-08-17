open Glop_intf
open Algen_intf

module GlopBase (Dim : CONF_INT) :
	GLOPBASE with module V.Dim = Dim =
struct
	module K = Algen_impl.NatIntField (struct let v = 16 end)
	module M = GlMatrix (K)
	module V = ExtendedVector (Vector (K) (Dim))

    type event = Clic of int * int * int * int | Resize of int * int
    type color = K.t * K.t * K.t * K.t
    type vertex_array = (nativeint, Bigarray.nativeint_elt, Bigarray.c_layout) Bigarray.Array2.t
    type render_type = Dot | Line_strip | Line_loop | Lines | Triangle_strip | Triangle_fans | Triangles
    type color_specs = Array of vertex_array | Uniq of color

    external init : ?depth:bool -> ?alpha:bool -> string -> int -> int -> unit = "gles_init"
    external exit : unit -> unit = "gles_exit"
    external next_event : bool -> event option = "gles_next_event"
    external clear : ?color:color -> ?depth:K.t -> unit -> unit = "gles_clear"
    external swap_buffers : unit -> unit = "gles_swap_buffers"
    external render : render_type -> vertex_array -> color_specs -> unit = "gles_render"
    let make_vertex_array nbv =
		Bigarray.Array2.create Bigarray.nativeint Bigarray.c_layout nbv (Dim.v)
	let vertex_array_set arr i vec =
		Array.iteri (fun c v -> Bigarray.Array2.set arr i c v) vec
    external set_projection : M.t -> unit = "gles_set_projection"
    external set_modelview : M.t -> unit = "gles_set_modelview"
    external set_depth_range : K.t -> K.t -> unit = "gles_set_depth_range"
end

