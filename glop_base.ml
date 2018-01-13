open Glop_intf
open Algen_intf
open Matrix_impl

module type GLOPSPEC =
sig
    module Dim : CONF_INT
    module CDim : CONF_INT
    module K : Algen_intf.FIELD
    module KC : Algen_intf.FIELD
    type vertex_array
    val make_vertex_array : int -> vertex_array
    val vertex_array_set : vertex_array -> int -> K.t array -> unit
    type color_array
    val make_color_array : int -> color_array
    val color_array_set : color_array -> int -> KC.t array -> unit
end

module GlopBase
    (Spec : GLOPSPEC) :
    CORE_GLOP with module V.Dim = Spec.Dim
              and module C.Dim = Spec.CDim
              and module K = Spec.K
              and module KC = Spec.KC
              and type vertex_array = Spec.vertex_array
              and type color_array = Spec.color_array =
struct
    include Spec
    module M = GlMatrix (K)
    module V = Algen_vector.Make (K) (Dim)
    module C = struct
      include Algen_vector.Make (KC) (CDim)

      let white = [| KC.one  ; KC.one  ; KC.one  |]
      let black = [| KC.zero ; KC.zero ; KC.zero |]
      let red   = [| KC.one  ; KC.zero ; KC.zero |]
      let green = [| KC.zero ; KC.one  ; KC.zero |]
      let blue  = [| KC.zero ; KC.zero ; KC.one  |]

      let intensify i c =
        Array.map (fun k ->
          let d =
            if i >= 0.5 then KC.sub KC.one k else k in
          KC.add k (KC.mul d (KC.of_float (2. *. (i -. 0.5))))) c
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

    (* Regardless of K and M that we use for geometry, gl_set_projection/gl_set_modelview
     * expect a float matrix: *)
    external set_projection_ : M.MFloat.t -> unit = "gl_set_projection"
    external set_modelview_  : M.MFloat.t -> unit = "gl_set_modelview"
    let set_projection m = set_projection_ (M.to_float m)
    let set_modelview m = set_modelview_ (M.to_float m)

    external set_viewport    : int -> int -> int -> int -> unit = "gl_set_viewport"
    external set_scissor     : int -> int -> int -> int -> unit = "gl_set_scissor"
    external disable_scissor : unit -> unit = "gl_disable_scissor"
    external set_depth_range : K.t -> K.t -> unit = "gl_set_depth_range"
    external window_size     : unit -> int * int = "gl_window_size"
end
