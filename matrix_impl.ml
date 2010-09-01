open Algen_intf
open Glop_intf

module GlMatrix (K : FIELD) : GLMATRIX with module K = K =
struct
	module Ke = ExtendedField (K)
	module MDim : CONF_INT = struct let v = 4 end
	include ExtendedMatrix (Matrix (K) (MDim) (MDim))

	let ortho l r b t n f =
		let two = K.add K.one K.one in [|
			[| Ke.div two (Ke.sub r l) ; Ke.zero ; Ke.zero ; Ke.zero |] ;
			[| Ke.zero ; Ke.div two (Ke.sub t b) ; Ke.zero ; Ke.zero |] ;
			[| Ke.zero ; Ke.zero ; K.neg (Ke.div two (Ke.sub f n)) ; Ke.zero |] ;
			[| K.neg (Ke.div (K.add r l) (Ke.sub r l)) ; K.neg (Ke.div (K.add t b) (Ke.sub t b)) ;
			   K.neg (Ke.div (K.add f n) (Ke.sub f n)) ; Ke.one |]
		|]

	let frustum l r b t n f =
		let twice_n = Ke.double n in [|
			[| Ke.div twice_n (Ke.sub r l) ; Ke.zero ; Ke.zero ; Ke.zero |] ;
			[| Ke.zero ; Ke.div twice_n (Ke.sub t b) ; Ke.zero ; Ke.zero |] ;
			[| Ke.div (K.add r l) (Ke.sub r l) ; Ke.div (K.add t b) (Ke.sub t b) ;
			   Ke.div (K.add f n) (Ke.sub n f) ; Ke.neg K.one |] ;
			[| Ke.zero ; Ke.zero ; Ke.div (Ke.mul twice_n f) (Ke.sub n f) ; Ke.zero |] ;
		|]

	let coord c x y z t = match c with 0 -> x | 1 -> y | 2 -> z | _ -> t

	let translate x y z =
		init (fun c r ->
			if c = 3 then coord r x y z K.one
			else (
				if c = r then Ke.one else Ke.zero
			))

	let scale x y z =
		init (fun c r ->
			if c <> r then Ke.zero else
			coord r x y z K.one)
	
	let rotate x y z a =
		let c = K.of_float (cos a)
		and s = K.of_float (sin a) in
		let c'= Ke.sub K.one c in [|
			[| Ke.add (Ke.muls [x;x;c']) c ; Ke.add (Ke.muls [y;x;c']) (K.mul z s) ; Ke.sub (Ke.muls [x;z;c']) (K.mul y s) ; K.zero |] ;
			[| Ke.sub (Ke.muls [x;y;c']) (K.mul z s) ; Ke.add (Ke.muls [y;y;c']) c ; Ke.add (Ke.muls [y;z;c']) (K.mul x s) ; K.zero |] ;
			[| Ke.add (Ke.muls [x;z;c']) (K.mul y s) ; Ke.sub (Ke.muls [y;z;c']) (K.mul x s) ; Ke.add (Ke.muls [z;z;c']) c ; K.zero |] ;
			[| K.zero ; K.zero ; K.zero ; K.one |] ;
		|]
end

