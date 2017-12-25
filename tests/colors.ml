(* Display red, green and blue squares in order to test colors (and basic geometry. *)
module Glop = Glop_impl.Glop2D
module View = Glop_view.Make (Glop)
open Glop

let square x =
    let sqp = K.half (K.half (K.half K.one)) in
    let sqm = K.neg sqp in
    let sq = [|
        [| sqp ; sqp |] ;
        [| sqm ; sqp |] ;
        [| sqm ; sqm |] ;
        [| sqp ; sqm |]
    |]
    and disp = [| x ; K.zero |] in
    vertex_array_init 4 (fun i -> V.add sq.(i) disp)

let main =
    let on_event = function Clic _ -> View.exit () | _ -> () in
    let paint_colors () =
        let modelview = M.id in
        modelview.(3).(2) <- K.half (K.neg K.one) ;
        set_modelview modelview ;
        clear ~color:C.black () ;
        let d = K.half K.one in
        render Triangle_fans (square (K.neg d)) (Uniq C.red) ;
        render Triangle_fans (square K.zero) (Uniq C.green) ;
        render Triangle_fans (square d) (Uniq C.blue) in
    View.display ~title:"colors" ~on_event:on_event [paint_colors]

