open Glop_intf
open Algen_intf
open Matrix_impl

module type GLOPSPEC =
sig
	module Dim : CONF_INT
	module CDim : CONF_INT
	module K : Algen_intf.FIELD
	type vertex_array
	val make_vertex_array : int -> vertex_array
	val vertex_array_set : vertex_array -> int -> K.t array -> unit
	type color_array
	val make_color_array : int -> color_array
	val color_array_set : color_array -> int -> K.t array -> unit
end

module GlopBase
	(Spec: GLOPSPEC) :
	GLOPBASE with module V.Dim = Spec.Dim
	         and module C.Dim = Spec.CDim
	         and module K = Spec.K
	         and type vertex_array = Spec.vertex_array
	         and type color_array = Spec.color_array =
struct
	include Spec
	module M = GlMatrix (K)
	module V = ExtendedVector (Vector (K) (Dim))
	module C = ExtendedVector (Vector (K) (CDim))

	type event = Clic   of int * int * int * int
	           | Unclic of int * int * int * int
	           | Drag   of int * int * int * int
	           | Resize of int * int
	type render_type = Dot | Line_strip | Line_loop | Lines | Triangle_strip | Triangle_fans | Triangles
	type color_specs = Array of color_array | Uniq of C.t

	external init            : ?depth:bool -> ?alpha:bool -> string -> int -> int -> unit = "gl_init"
	external exit            : unit -> unit = "gl_exit"
	external next_event      : bool -> event option = "gl_next_event"
	external clear           : ?color:C.t -> ?depth:K.t -> unit -> unit = "gl_clear"
	external swap_buffers    : unit -> unit = "gl_swap_buffers"
	external render          : render_type -> vertex_array -> color_specs -> unit = "gl_render"
	external set_projection  : M.t -> unit = "gl_set_projection"
	external set_modelview   : M.t -> unit = "gl_set_modelview"
	external set_viewport    : int -> int -> int -> int -> unit = "gl_set_viewport"
	external set_depth_range : K.t -> K.t -> unit = "gl_set_depth_range"
	external window_size     : unit -> int * int = "gl_window_size"
end

