open Batteries
open Glop_intf

module Make (Glop : GLOP) =
struct
    open Glop
    type painter = unit -> unit

    (* A positionner gives the position of a view into its parent.
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
    let root_to_viewable dst =
        let rec to_root pos = match pos.parent with
            | None -> pos
            | Some parent ->
                mult_modelview (pos.positioner Parent_to_view) ;
                to_root parent in
        to_root dst

    let viewable_to_root src =
        let rec prepend_next_view root2src view = match view.parent with
            | None -> root2src
            | Some parent -> prepend_next_view (view::root2src) parent in
        let root2src = prepend_next_view [] src in
        List.iter (fun view -> mult_modelview (view.positioner View_to_parent)) root2src

    (* Returns the matrix that transform point coordinates in src to coordinates in dst *)
    let get_transform ?src ?dst () =
        push_modelview () ;
        set_modelview M.id ;
        (* start from current transfo = identity matrix
         * then mult current transfo by all transverse positions from dst to root -> gives
         * the transfo from root to dst *)
        Option.may (ignore % root_to_viewable) dst ;
        (* then mult this by transfo from root to src, ie all positioners from root to src *)
        Option.may viewable_to_root src ;
        (* modelview is then :
         * (VN->dst) o ... o (root->V1) o (vN->root) o ... o (v1->v2) o (src->v1)
         * then read modelview with :
         * glGetFloatv (GL_MODELVIEW_MATRIX, matrix);
         *)
        let m = get_modelview () in
        pop_modelview () ;
        m

    let draw_viewable camera =
        let rec aux pos =
            push_modelview () ;
            mult_modelview (pos.positioner View_to_parent) ;
            pos.painter () ;
            List.iter aux pos.children ;
            pop_modelview () in
        set_modelview M.id ;
        aux (root_to_viewable camera)

    (* Once in a drawer we may want to clip some objects.
     * This function returns the screen corner coordinates according to
     * current modelview/projection transformations *)
    let clip_coordinates () =
        let m = M.mul_mat (get_projection ()) (get_modelview ()) in
        let _,_,w,h as viewport = get_viewport () in
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

    let display ?(title="View") ?(on_event=ignore) ?(width=800) ?(height=480) painters =
        let z_near = K.of_float 0.2 in (* FIXME *)
        let z_far  = K.of_float 1.2 in
        let new_size_mutex = Mutex.create () in
        let new_size = ref None in
        let handle_event () =
            let ev = next_event true in
            (match ev with
                | Some Resize (w, h) ->
                    BatMutex.synchronize ~lock:new_size_mutex (fun x -> new_size := x) (Some (w, h))
                | _ -> ()) ;
            Option.may on_event ev in
        let event_thread () =
            forever handle_event () in
        let next_frame () =
            BatMutex.synchronize ~lock:new_size_mutex (fun () ->
                match !new_size with
                    | Some (w, h) ->
                        set_projection_to_winsize z_near z_far w h ;
                        new_size := None
                    | _ -> ()) () ;
            List.iter ((|>) ()) painters ;
            swap_buffers () in
        init title width height ;
        set_projection (M.ortho
                            (K.neg K.one) K.one
                            (K.neg K.one) K.one
                            (K.neg K.one) K.one) ;
        ignore (Thread.create event_thread ()) ;
        forever next_frame ()
end

