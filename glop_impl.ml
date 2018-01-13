open Glop_intf
open Glop_base
open Algen_intf

module Extension (GB : CORE_GLOP) =
struct
    let proj_stack = ref [ GB.M.id ]
    let model_stack  = ref [ GB.M.id ]
    let last_viewport   = ref (0, 0, 0, 0)

    (* Set current matrix to the top of the stack *)
    let set_proj ()  = GB.set_projection (List.hd !proj_stack)
    let set_model () = GB.set_modelview  (List.hd !model_stack)

    (* Alter matrix stack and reset current matrix *)
    let set_projection m   = proj_stack  := m :: (List.tl !proj_stack) ; set_proj ()
    let set_modelview m    = model_stack := m :: (List.tl !model_stack) ; set_model ()
    let push_projection () = proj_stack  := (List.hd !proj_stack) :: !proj_stack
    let push_modelview ()  = model_stack := (List.hd !model_stack) :: !model_stack
    let pop_projection ()  = proj_stack  := List.tl !proj_stack ; set_proj ()
    let pop_modelview ()   = model_stack := List.tl !model_stack ; set_model ()
    let mult_projection m  = set_projection (GB.M.mul_mat (List.hd !proj_stack) m)
    let mult_modelview m   = set_modelview  (GB.M.mul_mat (List.hd !model_stack) m)
    let get_projection ()  = List.hd !proj_stack
    let get_modelview ()   = List.hd !model_stack

    (* For viewport we merely store the current value *)
    let set_viewport x y w h =
      last_viewport := (x, y, w, h) ;
      GB.set_viewport x y w h

    let get_viewport () = !last_viewport

    let vertex_array_init len f =
        let arr = GB.make_vertex_array len in
        for c = 0 to len-1 do
            GB.vertex_array_set arr c (f c)
        done ;
        arr

    let color_array_init len f =
        let arr = GB.make_color_array len in
        for c = 0 to len-1 do
            GB.color_array_set arr c (f c)
        done ;
        arr

    let set_projection_to_winsize get_projection w h =
        if w > 0 && h > 0 then (
            let x, y =
                if w > h then
                    GB.K.div (GB.K.of_int w) (GB.K.of_int h), GB.K.one
                else
                    GB.K.one, GB.K.div (GB.K.of_int h) (GB.K.of_int w) in
            get_projection x y |>
            set_projection
        ) ;
        set_viewport 0 0 w h

    let next_event_with_resize get_projection wait =
        match GB.next_event wait with
        | None -> None
        | Some (GB.Resize (w, h)) as ev ->
            set_projection_to_winsize get_projection w h ;
            ev
        | ev -> ev

    let project v transformation (x0, y0, width, height) =
        (* Extend given vector to 4 dimentions *)
        let vo = Array.init 4 (fun i ->
            if i < Array.length v then v.(i)
            else if i = 3 then GB.K.one
            else GB.K.zero) in
        (* mult by transformation to get clip coordinates *)
        let vc = GB.M.mul_vec transformation vo in
        (* perspective division to get device coordinate *)
        let vd = Array.init 3 (fun i -> GB.K.div vc.(i) vc.(3)) in
        (* then center to viewport *)
        let half_w = width / 2
        and half_h = height / 2 in
        x0 + half_w + (GB.K.to_int (GB.K.mul (GB.K.of_int half_w) vd.(0))),
        y0 + half_h + (GB.K.to_int (GB.K.mul (GB.K.of_int half_h) vd.(1)))

    let unproject (x0, y0, width, height) transformation xw yw =
        (* inverse viewport to go from window coordinates to normalized device coordinates *)
        let nd_from_w win_coord win_start win_size =
            let w' = (win_coord - win_start) * 2 in
            GB.K.sub (GB.K.div (GB.K.of_int w') (GB.K.of_int win_size)) GB.K.one in
        let xd = nd_from_w xw x0 width
        and yd = nd_from_w yw y0 height
        and zd = GB.K.one in
        (* inverse perspective division to get clip coordinates *)
        let wc = GB.K.one in
        let xc = GB.K.mul xd wc
        and yc = GB.K.mul yd wc
        and zc = GB.K.mul zd wc in
        (* inverse transformation for eye/object coordinates *)
        let v = GB.M.inv_mul transformation [| xc ; yc ; zc ; wc |] in
        (* truncate to the firsts V.Dim.v coordinates *)
        Array.sub v 0 GB.V.Dim.v
end

module MakeCustom (Spec : GLOPSPEC) :
    GLOP with module V.Dim = Spec.Dim
         and module C.Dim = Spec.CDim
         and module K = Spec.K =
struct
    module GB = GlopBase (Spec)
    include GB
    include Extension (GB)
end

module Make (Dim : CONF_INT) (CDim: CONF_INT) :
    GLOP with module V.Dim = Dim
         and module C.Dim = CDim
         and module K = Glop_spec.K =
    MakeCustom (Glop_spec.Spec (Dim) (CDim))

open Algen_impl
module Glop2D = Make (Dim2) (Dim3)
module Glop3D = Make (Dim3) (Dim3)
module Glop2Dalpha = Make (Dim2) (Dim4)
module Glop3Dalpha = Make (Dim3) (Dim4)
