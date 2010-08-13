(** GLOP : GL for OCaml Programs.
 * A thin layer above OpenGL or GLES. *)

open Algen_intf

module type GLMATRIX =
sig
	include MATRIX
	val ortho   : K.t -> K.t -> K.t -> K.t -> K.t -> K.t -> t
	val frustum : K.t -> K.t -> K.t -> K.t -> K.t -> K.t -> t
end

module GlMatrix (K : FIELD) : GLMATRIX with module K = K =
struct
	module Ke = ExtendedField (K)
	module MDim : CONF_INT = struct let v = 4 end
	include ExtendedMatrix (Matrix (K) (MDim) (MDim))
	let ortho l r b t n f =
		Format.printf "Ortho from %a to %a, %a to %a@." K.print l K.print r K.print b K.print t;
		let two = K.add K.one K.one in
		let m = id in
		m.(0).(0) <- Ke.div two (Ke.sub r l) ;
		m.(1).(1) <- Ke.div two (Ke.sub t b) ;
		m.(2).(2) <- K.neg (Ke.div two (Ke.sub f n)) ;
		m.(3).(0) <- K.neg (Ke.div (K.add r l) (Ke.sub r l)) ;
		m.(3).(1) <- K.neg (Ke.div (K.add t b) (Ke.sub t b)) ;
		m.(3).(2) <- K.neg (Ke.div (K.add f n) (Ke.sub f n)) ;
		m
	let frustum l r b t n f =
		let twice_n = Ke.double n in
		let m = id in
		m.(0).(0) <- Ke.div twice_n (Ke.sub r l) ;
		m.(1).(1) <- Ke.div twice_n (Ke.sub t b) ;
		m.(2).(2) <- Ke.div (K.add f n) (Ke.sub n f) ;
		m.(3).(3) <- Ke.zero ;
		m.(2).(3) <- Ke.neg K.one ;
		m.(2).(0) <- Ke.div (K.add r l) (Ke.sub r l) ;
		m.(2).(1) <- Ke.div (K.add t b) (Ke.sub t b) ;
		m.(3).(2) <- Ke.div (Ke.mul twice_n f) (Ke.sub n f) ;
		m
end

module type GLOPBASE =
sig
	module K : FIELD
	module M : GLMATRIX with module K = K (** Of size 4x4 *)
	module V : VECTOR with module K = K	(** Of dimension 2 to 4 *)

	(** Init *)

	val init : ?depth:bool -> ?alpha:bool -> string -> unit
	val exit : unit -> unit

	(** Events *)

	type event = Clic of int * int | Resize of int * int

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

	val set_projection_to_winsize : K.t -> K.t -> int -> int -> unit
	(** Helper function to reset the projection matrix to maintain constant aspect ratio of 1
	 * after the window is resized.
	 * [set_projection_to_winsize n f w h] sets the projection matrix so that the smaller
	 * dimension of the window ranges from -1. to +1, while z ranges from [n] to [f],
	 * when the window width is [w] and height is [h]. *)
	
	val next_event_with_resize : bool -> K.t -> K.t -> event option
	(** Same as [next_event] but automatically handle resize event with
	 * [set_projection_to_winsize]. *)
end
