(** GLOP : GL for OCaml Programs.
 * A thin layer above OpenGL or GLES. *)

open Algen_intf

module type GLOPBASE =
sig
	module K : FIELD
	module M : MATRIX with module K = K (** Of size 4x4 *)
	module V : VECTOR with module K = K	(** Of dimension 2 to 4 *)

	(** Init *)

	val init : ?depth:bool -> ?alpha:bool -> string -> unit
	val exit : unit -> unit

	(** Events *)

	type event = Clic of (int * int)

	val next_event : bool -> event option

	(** Clear *)

	type color = K.t * K.t * K.t * K.t
	val clear : ?color:color -> ?depth:K.t -> unit -> unit

	(** Swap buffers *)

	val swap_buffers : unit -> unit

	(** Geometry arrays *)

	type vertex_array
	(** [vertex_array] is a bigarray of some sort (floats or nativeints), with 2
	 * dimensions, the second one being the same as that of V. *)

	val make_vertex_array : int -> vertex_array
	(** [make_vertex_array len] build an uninitialized vertex array with room
	 * for len vectors *)

	val vertex_array_set : vertex_array -> int -> V.t -> unit

	type render_type = Dot | Line_strip | Line_loop | Lines | Triangle_strip | Triangle_fans | Triangles
	type color_specs = Array of vertex_array | Uniq of color

	val render : render_type -> vertex_array -> color_specs -> unit

	(** Matrices *)

	val set_projection : M.t -> unit
	val set_modelview : M.t -> unit

	val set_depth_range : K.t -> K.t -> unit
end

module type GLOP =
sig
	include GLOPBASE
	val vertex_array_init : int -> (int -> V.t) -> vertex_array
end
