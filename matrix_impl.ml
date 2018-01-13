open Algen_intf
open Glop_intf

module GlMatrix (K : FIELD) : GLMATRIX with module K = K =
struct
    module MDim : CONF_INT = struct let v = 4 end
    include Algen_matrix.Make (K) (MDim) (MDim)

    let ortho l r b t n f =
        let two = K.add K.one K.one in [|
            [| K.div two (K.sub r l) ; K.zero ; K.zero ; K.zero |] ;
            [| K.zero ; K.div two (K.sub t b) ; K.zero ; K.zero |] ;
            [| K.zero ; K.zero ; K.neg (K.div two (K.sub f n)) ; K.zero |] ;
            [| K.neg (K.div (K.add r l) (K.sub r l)) ; K.neg (K.div (K.add t b) (K.sub t b)) ;
               K.neg (K.div (K.add f n) (K.sub f n)) ; K.one |]
        |]

    let frustum l r b t n f =
        let twice_n = K.double n in [|
            [| K.div twice_n (K.sub r l) ; K.zero ; K.zero ; K.zero |] ;
            [| K.zero ; K.div twice_n (K.sub t b) ; K.zero ; K.zero |] ;
            [| K.div (K.add r l) (K.sub r l) ; K.div (K.add t b) (K.sub t b) ;
               K.div (K.add f n) (K.sub n f) ; K.neg K.one |] ;
            [| K.zero ; K.zero ; K.div (K.mul twice_n f) (K.sub n f) ; K.zero |] ;
        |]

    let coord c x y z t = match c with 0 -> x | 1 -> y | 2 -> z | _ -> t

    let translate x y z =
        init (fun c r ->
            if c = 3 then coord r x y z K.one
            else (
                if c = r then K.one else K.zero
            ))

    let scale x y z =
        init (fun c r ->
            if c <> r then K.zero else
            coord r x y z K.one)

    let rotate x y z a =
        let c = K.of_float (cos a)
        and s = K.of_float (sin a) in
        let c'= K.sub K.one c in [|
            [| K.add (K.muls [x;x;c']) c ; K.add (K.muls [y;x;c']) (K.mul z s) ; K.sub (K.muls [x;z;c']) (K.mul y s) ; K.zero |] ;
            [| K.sub (K.muls [x;y;c']) (K.mul z s) ; K.add (K.muls [y;y;c']) c ; K.add (K.muls [y;z;c']) (K.mul x s) ; K.zero |] ;
            [| K.add (K.muls [x;z;c']) (K.mul y s) ; K.sub (K.muls [y;z;c']) (K.mul x s) ; K.add (K.muls [z;z;c']) c ; K.zero |] ;
            [| K.zero ; K.zero ; K.zero ; K.one |] ;
        |]

    let transverse pos = [|
        (* Transpose rotation part *)
        [| pos.(0).(0) ; pos.(1).(0) ; pos.(2).(0) ; K.zero |] ;
        [| pos.(0).(1) ; pos.(1).(1) ; pos.(2).(1) ; K.zero |] ;
        [| pos.(0).(2) ; pos.(1).(2) ; pos.(2).(2) ; K.zero |] ;
        (* Compute translation part *)
        [| K.neg (K.adds [ K.mul pos.(0).(0) pos.(3).(0) ;
                           K.mul pos.(0).(1) pos.(3).(1) ;
                           K.mul pos.(0).(2) pos.(3).(2) ]) ;
           K.neg (K.adds [ K.mul pos.(1).(0) pos.(3).(0) ;
                           K.mul pos.(1).(1) pos.(3).(1) ;
                           K.mul pos.(1).(2) pos.(3).(2) ]) ;
           K.neg (K.adds [ K.mul pos.(2).(0) pos.(3).(0) ;
                           K.mul pos.(2).(1) pos.(3).(1) ;
                           K.mul pos.(2).(2) pos.(3).(2) ]) ;
           K.one |]
    |]

  module MFloat = Algen_matrix.Make (Algen_impl.FloatField) (MDim) (MDim)
  let to_float m = Array.map (Array.map K.to_float) m
end
