open Glop_intf

module Extension (GB : GLOPBASE) =
struct
	let vertex_array_init len f =
		let arr = GB.make_vertex_array len in
		for c = 0 to len-1 do
			GB.vertex_array_set arr c (f c)
		done ;
		arr
end
