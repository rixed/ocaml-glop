open Glop_intf

module Make (Glop : GLOP) =
struct
    open Glop
    type painter = unit -> unit

    (* A positioner gives the position of a view into its parent.
     * It's thus the transformation from the view to its parent coord system. *)
    type transfo_dir = View_to_parent | Parent_to_view
    type positioner = transfo_dir -> M.t
    type viewable = {
        name             : string ;
        painter          : painter ;
        positioner       : positioner ;
        mutable parent   : viewable option ;
        mutable children : viewable list
    }

    let rec viewable_set_parent ?parent view =
        match parent with
        | None ->
            (match view.parent with
            | None -> ()
            | Some prev_parent ->
                view.parent <- None ;
                prev_parent.children <-
                    List.filter (( != ) view) prev_parent.children)
        | Some new_parent ->
            (match view.parent with
            | None ->
                view.parent <- parent ;
                new_parent.children <- (view::new_parent.children)
            | Some _ ->
                viewable_set_parent view ;
                viewable_set_parent ~parent:new_parent view)

    let make_viewable ?parent name painter positioner =
        let viewable =
            { name = name ;
              painter = painter ;
              positioner = positioner ; (* matrix transforming coords from this viewable to parent *)
              parent = None ;
              children = [] } in
        viewable_set_parent ?parent viewable ;
        viewable

    (* Sets the modelview to transform from root to dst, and returns root *)
    let root_to_viewable mult_mat dst =
        let rec to_root pos = match pos.parent with
            | None -> pos
            | Some parent ->
                mult_mat (pos.positioner Parent_to_view) ;
                to_root parent in
        to_root dst

    let viewable_to_root mult_mat src =
        let rec prepend_next_view root2src view = match view.parent with
            | None -> root2src
            | Some parent -> prepend_next_view (view::root2src) parent in
        let root2src = prepend_next_view [] src in
        List.iter (fun view -> mult_mat (view.positioner View_to_parent)) root2src

    (* Returns the matrix that transform point coordinates in src to coordinates in dst *)
    let get_transform ?src ?dst () =
        let m = ref M.id in
        let mult_mat m' = m := M.mul_mat !m m' in
        (* start from current transfo = identity matrix
         * then mult current transfo by all transverse positions from dst to root -> gives
         * the transfo from root to dst *)
        (match dst with Some d -> root_to_viewable mult_mat d |> ignore | None -> ()) ;
        (* then mult this by transfo from root to src, ie all positioners from root to src *)
        (match src with Some s -> viewable_to_root mult_mat s | None -> ()) ;
        (* m is then :
         * (VN->dst) o ... o (root->V1) o (vN->root) o ... o (v1->v2) o (src->v1)
         *)
        !m

    let draw_viewable camera =
        let rec aux pos =
            push_modelview () ;
            mult_modelview (pos.positioner View_to_parent) ;
            pos.painter () ;
            List.iter aux pos.children ;
            pop_modelview () in
        set_modelview M.id ;
        aux (root_to_viewable mult_modelview camera)

    (* Once in a drawer we may want to clip some objects.
     * This function returns the screen corner coordinates according to
     * current modelview/projection transformations *)
    let clip_coordinates () =
        let m = M.mul_mat (get_projection ()) (get_modelview ()) in
        let _,_,w,h as viewport = get_viewport () in
        if w = 0 || h = 0 then
          V.zero, V.zero, V.zero, V.zero
        else
          let p00 = unproject viewport m 0 0
          and p10 = unproject viewport m w 0
          and p11 = unproject viewport m w h
          and p01 = unproject viewport m 0 h in
          p00, p10, p11, p01

    (* Some simple positioners : *)

    let identity _ = M.id

    let translator get_pos dir =
        let x, y, z = get_pos () in
        let m = M.translate x y z in
        if dir = View_to_parent then m else M.transverse m

    let scaler get_scale dir =
        let x, y, z = get_scale () in
        match dir with
        | View_to_parent -> M.scale x y z
        | Parent_to_view -> M.scale (K.inv x) (K.inv y) (K.inv z)

    let orientor get_orient dir =
        let c, s = get_orient () in
        let m =
            [| [| c ; s ; K.zero ; K.zero |] ;
               [| K.neg s ; c ; K.zero ; K.zero |] ;
               [| K.zero ; K.zero ; K.one ; K.zero |] ;
               [| K.zero ; K.zero ; K.zero ; K.one |] |] in
        if dir = View_to_parent then m else M.transverse m

    let trans_orientor get_pos get_orient dir =
        let x, y, z = get_pos () in
        let c, s = get_orient () in
        let m =
            [| [| c ; s ; K.zero ; K.zero |] ;
               [| K.neg s ; c ; K.zero ; K.zero |] ;
               [| K.zero ; K.zero ; K.one ; K.zero |] ;
               [| x ; y ; z ; K.one |] |] in
        if dir = View_to_parent then m else M.transverse m

    let rotator get_angle dir =
        let a = get_angle () in
        let c = K.of_float (cos a) in
        let s = K.of_float (sin a) in
        orientor (fun () -> c, s) dir

    let trans_rotator get_pos get_angle dir =
        let a = get_angle () in
        let c = K.of_float (cos a) in
        let s = K.of_float (sin a) in
        trans_orientor get_pos (fun () -> c, s) dir

    let get_projection_default l u =
        let z_near = K.neg K.one and z_far = K.one in
        M.ortho (K.neg l) l
                (K.neg u) u
                z_near z_far

    let want_exit = ref false
    let exit () = want_exit := true

    (* Some GL libs have a different GL context per threads, so you
     * must not call any GL functions in the on_event callback. *)
    let display ?depth ?alpha ?double_buffer
                ?(title="View") ?(on_event=ignore)
                ?(width=800) ?(height=480)
                ?(get_projection=get_projection_default) painters =
        let new_size_mutex = Mutex.create () in
        let new_size = ref None in
        let synchronize l f x =
            try Mutex.lock l ;
                let r = f x in
                Mutex.unlock l ;
                r
            with e ->
                Mutex.unlock l ;
                raise e in
        let handle_event () =
            let ev = next_event true in
            (match ev with
                | Some Resize (w, h) ->
                    synchronize new_size_mutex (fun x -> new_size := x) (Some (w, h))
                | _ -> ()) ;
            (match ev with Some e -> on_event e | None -> ()) in
        let forever f x =
            ignore (while true do f x done) in
        let event_thread () =
            forever handle_event () in
        let next_frame () =
            synchronize new_size_mutex (fun () ->
                match !new_size with
                    | Some (w, h) ->
                        set_projection_to_winsize get_projection w h ;
                        new_size := None
                    | _ -> ()) () ;
            List.iter ((|>) ()) painters ;
            swap_buffers () in
        init ?depth ?alpha ?double_buffer title width height ;
        set_projection (get_projection K.one K.one) ;
        ignore (Thread.create event_thread ()) ;
        while not !want_exit do next_frame () done ;
        Glop.exit ()

    (* Simple function to display some geometry in a separate window.
     * The user can rotate/zoom the camera with the mouse and use keyboard
     * to close the window. *)
    let showroom ?title ?width ?height painters =
        let z_near = K.of_float 0.2 and z_far = K.of_float 10.2 in
        let cam_pos = (* pos of camera in root *)
            M.translate K.zero K.zero (K.double z_near) in
        let cam_positioner = function
            | View_to_parent -> cam_pos
            | Parent_to_view -> M.transverse cam_pos in
        let root =
            make_viewable "root"
                (fun () ->
                    clear ~color:C.black () ;
                    let o = K.zero and i = K.one
                    and j = K.neg K.one and a = K.of_float 0.1 (* arrow head size *) in
                    let to_vertex_array arr =
                        vertex_array_init (Array.length arr) (Array.get arr) in
                    (* draw grey background *)
                    let arr = [| [|i;i|] ; [|j;i|] ;
                                 [|j;j|] ; [|i;j|] |] |> to_vertex_array in
                    let grid_bg_color = Array.map K.of_float [|0.5; 0.5; 0.5; 0.3|] in
                    render Triangle_fans arr (Uniq grid_bg_color) ;
                    (* axis *)
                    let axis_color = Array.map K.of_float [|1.; 1.; 1.; 0.6|] in
                    let arr = [| [|o;K.neg i|] ; [|o;K.sub i a|] ;
                                 [|K.neg i;o|] ; [|K.sub i a;o|] |] |> to_vertex_array in
                    render Lines arr (Uniq axis_color) ;
                    let arr = [| [|i;o|] ; [|K.sub i a; a|] ; [|K.sub i a; K.neg a|] ;
                                 [|o;i|] ; [|K.neg a; K.sub i a|] ; [|a; K.sub i a|] |] |>
                              to_vertex_array in
                    render Triangles arr (Uniq axis_color) ;
                    (* user things *)
                    List.iter ((|>) ()) painters)
                identity in
        let camera =
            let nop () = () in
            make_viewable ~parent:root "camera" nop cam_positioner in
        let painter () = draw_viewable camera in
        let on_event = function
            | Zoom _ ->
                cam_pos.(3).(2) <- K.sub cam_pos.(3).(2) (K.of_float 0.02) ;
                Printf.printf "camera height is now %s.\n%!" (K.to_string cam_pos.(3).(2))
            | UnZoom _ ->
                cam_pos.(3).(2) <- K.add cam_pos.(3).(2) (K.of_float 0.02) ;
                Printf.printf "camera height is now %s.\n%!" (K.to_string cam_pos.(3).(2))
            | Clic _ (* start drag n drop *)
            | UnClic _ (* stop drag n drop or selection *)
            | Move _ (* actual drag *)
            | Resize _ -> (* resize *)
                () in
        let get_projection r u =
            M.frustum (K.neg r) r (K.neg u) u z_near z_far in
        display ~depth:true ~alpha:true ?title ~on_event ?width ?height ~get_projection [painter]
end
