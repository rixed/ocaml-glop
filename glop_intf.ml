(** GLOP : GL for OCaml Programs.
 * A thin layer above OpenGL or GLES. *)

open Algen_intf

module type GLMATRIX =
sig
	include MATRIX
	val ortho      : K.t -> K.t -> K.t -> K.t -> K.t -> K.t -> t
	val frustum    : K.t -> K.t -> K.t -> K.t -> K.t -> K.t -> t
	val translate  : K.t -> K.t -> K.t -> t
	val scale      : K.t -> K.t -> K.t -> t
	val rotate     : K.t -> K.t -> K.t -> float -> t
	val transverse : t -> t
	(* [transverse m] transpose the rotation part of m and inverse its translation part,
	 * thus inversing m if m is orthonormal. *)
end

module type CORE_GLOP =
sig
	module K : FIELD
	module M : GLMATRIX with module K = K (** Of size 4x4 *)
	module V : VECTOR with module K = K	(** Of dimension 2 to 4 *)
	module C : VECTOR with module K = K	(** Of dimension 3 to 4 *)

	(** Init *)

	val init : ?depth:bool -> ?alpha:bool -> string -> int -> int -> unit
	val exit : unit -> unit

	(** Events *)

	type event = Clic   of int * int * int * int
	           | Unclic of int * int * int * int
	           | Zoom   of int * int * int * int
	           | UnZoom of int * int * int * int
	           | Drag   of int * int * int * int
	           | Resize of int * int
	(* Clic (c, y, width, height), Resize (width, height) *)

	val next_event : bool -> event option

	(** Clear *)

	val clear : ?color:C.t -> ?depth:K.t -> unit -> unit

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

	type color_array
	(** [color_array] is a bigarray of some sort (floats or nativeints), with 2
	 * dimensions, the second one being the same as that of C. *)

	val make_color_array : int -> color_array
	(** [make_color_array len] build an uninitialized color array with room
	 * for len vectors *)

	val color_array_set : color_array -> int -> C.t -> unit

	type render_type = Dot | Line_strip | Line_loop | Lines | Triangle_strip | Triangle_fans | Triangles
	type color_specs = Array of color_array | Uniq of C.t

	val render : render_type -> vertex_array -> color_specs -> unit

	(** Matrices *)

	val set_projection  : M.t -> unit
	val set_modelview   : M.t -> unit
	val set_viewport    : int -> int -> int -> int -> unit
	(** [set_viewport x y w h] sets the lower left corner of the viewport
	 * rectangle to x, y and its size to w, h. *)
	val window_size     : unit -> int * int

	val set_depth_range : K.t -> K.t -> unit
end

module type GLOP =
sig
	include CORE_GLOP

	val white : C.t
	val black : C.t
	val red   : C.t
	val green : C.t
	val blue  : C.t

	val mult_projection : M.t -> unit
	val push_projection : unit -> unit
	val pop_projection  : unit -> unit
	val get_projection  : unit -> M.t
	val mult_modelview  : M.t -> unit
	val push_modelview  : unit -> unit
	val pop_modelview   : unit -> unit
	val get_modelview   : unit -> M.t
	val get_viewport    : unit -> (int * int * int * int)

	val vertex_array_init : int -> (int -> V.t) -> vertex_array
	val color_array_init  : int -> (int -> C.t) -> color_array

	val set_projection_to_winsize : K.t -> K.t -> int -> int -> unit
	(** Helper function to reset the projection matrix to maintain constant aspect ratio of 1
	 * after the window is resized.
	 * [set_projection_to_winsize n f w h] sets the projection matrix so that the smaller
	 * dimension of the window ranges from -1. to +1, while z ranges from [n] to [f],
	 * when the window width is [w] and height is [h]. *)
	
	val next_event_with_resize : bool -> K.t -> K.t -> event option
	(** Same as [next_event] but automatically handle resize event with
	 * [set_projection_to_winsize]. *)
	
	val project : V.t -> M.t -> (int * int * int * int) -> (int * int)
	(** [project some_vector some_matrix (x0, y0, width, height)] returns the
	 * screen position of some_vector once transformed by some_matrix and scaled
	 * to viewport. *)

	val unproject : (int * int * int * int) -> M.t -> int -> int -> V.t
	(** [unproject (x0, y0, width, height) some_matrix x y] returns the
	 * position of a point that would be projected into [(x, y)] after transformation
	 * by some_matrix and normalization to the given view size. If some_matrix is
	 * the projection matrix, then the vector returned is in the camera coordinate
	 * system, while if it's modelview * projection then the vector returned is in
	 * the object space. *)
end
