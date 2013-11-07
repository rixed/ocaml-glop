module Glop = Glop_impl.Glop2D
module View = Glop_view.Make (Glop)

let main =
    let painter () = () in
    View.showroom ~title:"showroom" [painter]

