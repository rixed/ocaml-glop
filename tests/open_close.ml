module Glop = Glop_impl.Glop2D
module View = Glop_view.Make (Glop)
open Glop

let randcol () =
    let rand1 () = K.rand K.one in
    [| rand1 (); rand1 (); rand1 (); rand1 () |]

let randc n =
    K.sub (K.rand (K.double n)) n

let main =
    Random.self_init () ;

    let frame nb_vertices =
        let vx = vertex_array_init nb_vertices
            (fun _i -> Array.init 2 (fun _c -> randc K.one)) in
        clear ~color:(randcol ()) () ;
        render Triangle_fans vx (Uniq (randcol ())) ;
        render Line_strip vx (Uniq (randcol ())) ;
        swap_buffers () in

    let on_event = function Clic _ -> View.exit () | _ -> () in
    let paint_frame () =
        let modelview = M.id in
        modelview.(3).(2) <- K.half (K.neg K.one);
        set_modelview modelview ;
        frame 30 in

    View.display ~title:"test" ~on_event:on_event [paint_frame]

