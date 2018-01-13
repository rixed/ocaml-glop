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
    (Spec : GLOPSPEC) :
    CORE_GLOP with module V.Dim = Spec.Dim
              and module C.Dim = Spec.CDim
              and module K = Spec.K
              and type vertex_array = Spec.vertex_array
              and type color_array = Spec.color_array =
struct
    include Spec
    module M = GlMatrix (K)
    module V = Algen_vector.Make (K) (Dim)
    module C = struct
      include Algen_vector.Make (K) (CDim)

      let white = [| K.one  ; K.one  ; K.one  |]
      let black = [| K.zero ; K.zero ; K.zero |]
      let red   = [| K.one  ; K.zero ; K.zero |]
      let green = [| K.zero ; K.one  ; K.zero |]
      let blue  = [| K.zero ; K.zero ; K.one  |]

      let intensify i c =
        Array.map (fun k ->
          let d =
            if i >= 0.5 then K.sub K.one k else k in
          K.add k (K.mul d (K.of_float (2. *. (i -. 0.5))))) c
    end

    type event = Clic   of int * int * int * int * bool
               | UnClic of int * int * int * int
               | Zoom   of int * int * int * int * bool
               | UnZoom of int * int * int * int
               | Move   of int * int * int * int
               | Resize of int * int
    type render_type = Dot | Line_strip | Line_loop | Lines | Triangle_strip | Triangle_fans | Triangles
    type color_specs = Array of color_array | Uniq of C.t

    external init            : ?depth:bool -> ?alpha:bool -> ?double_buffer:bool -> ?msaa:bool -> string -> int -> int -> unit = "gl_init_bytecode" "gl_init_native"
    external exit            : unit -> unit = "gl_exit"
    external next_event      : bool -> event option = "gl_next_event"
    external clear           : ?color:C.t -> ?depth:K.t -> unit -> unit = "gl_clear"
    external swap_buffers    : unit -> unit = "gl_swap_buffers"
    external render          : render_type -> vertex_array -> color_specs -> unit = "gl_render"
    external set_projection  : M.t -> unit = "gl_set_projection"
    external set_modelview   : M.t -> unit = "gl_set_modelview"
    external set_viewport    : int -> int -> int -> int -> unit = "gl_set_viewport"
    external set_scissor     : int -> int -> int -> int -> unit = "gl_set_scissor"
    external disable_scissor : unit -> unit = "gl_disable_scissor"
    external set_depth_range : K.t -> K.t -> unit = "gl_set_depth_range"
    external window_size     : unit -> int * int = "gl_window_size"
end
