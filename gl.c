#include <GL/gl.h>
#include <GL/glx.h>
#include <gl_common.c>

static GLXContext glx_context;

/*
 * Init
 */

static int init_x(char const *title, bool with_depth, bool with_alpha, int width, int height)
{
	x_display = XOpenDisplay(NULL);
	if (! x_display) {
		fprintf(stderr, "Cannot connect to X server\n");
		return -1;
	}

	int attrs[] = {
		GLX_USE_GL, GLX_DOUBLEBUFFER, GLX_RGBA,
		GLX_RED_SIZE, 4, GLX_GREEN_SIZE, 4, GLX_BLUE_SIZE, 4,
		GLX_ALPHA_SIZE, with_alpha ? 4 : 0,
		GLX_DEPTH_SIZE, with_depth ? 4 : 0,
		None
	};

	XVisualInfo *vinfo = glXChooseVisual(x_display, DefaultScreen(x_display), attrs);
	if (! vinfo) {
		fprintf(stderr, "Cannot open window\n");
		return -1;
	}

	Window root = RootWindow(x_display, vinfo->screen);

	x_win = XCreateWindow(x_display, root,
		0, 0, width, height, 0,
		vinfo->depth, InputOutput,
		/*vinfo->visual*/CopyFromParent, CWEventMask,
		&win_attr);

	XMapWindow(x_display, x_win);
	XStoreName(x_display, x_win, title);

	glx_context = glXCreateContext(x_display, vinfo, NULL, True);
	if (! glx_context) {
		fprintf(stderr, "glXCreateContext failed\n");
		return(-1);
	}

	if (! glXMakeCurrent(x_display, x_win, glx_context)) {
		fprintf(stderr, "glXMakeCurrent failed\n");
		return(-1);
	}

	return 0;
}

CAMLprim void gl_init(value with_depth_, value with_alpha_, value title, value width, value height)
{
	CAMLparam5(with_depth_, with_alpha_, title, width, height);

	assert(Tag_val(title) == String_tag);
	bool with_depth = Is_block(with_depth_) && Val_true == Field(with_depth_, 0);
	bool with_alpha = Is_block(with_alpha_) && Val_true == Field(with_alpha_, 0);
	
	init(String_val(title), with_depth, with_alpha, Long_val(width), Long_val(height));

	CAMLreturn0;
}

CAMLprim void gl_exit(void)
{
	CAMLparam0();

	print_error();
	glXDestroyContext(x_display, glx_context);
	XDestroyWindow(x_display, x_win);
	XCloseDisplay(x_display);

	CAMLreturn0;
}

/*
 * Clear
 */

static GLclampf clear_color[4] = { -1., -1., -1., -1. };
static GLclampf clear_depth = -1.;

static void reset_clear_color(value color)
{
	CAMLparam1(color);
	assert(Is_block(color));
	assert(Tag_val(color) == Double_array_tag);
	unsigned const c_dim = Wosize_val(color) / Double_wosize;
	assert(c_dim == 3 || c_dim == 4);
	bool changed = false;

	for (unsigned i = 0; i < 4; i++) {
		GLclampf c;
		if (i < c_dim) c = Double_field(color, i);
		else c = i < 3 ? 0. : 1.;
		if (c != clear_color[i]) {
			changed = true;
			clear_color[i] = c;
		}
	}

	if (changed) {
		glClearColor(clear_color[0], clear_color[1], clear_color[2], clear_color[3]);
	}

	CAMLreturn0;
}

static void reset_clear_depth(value depth)
{
	CAMLparam1(depth);
	assert(Tag_val(depth) == Custom_tag);
	
	GLclampf const d = Double_val(depth);
	if (d != clear_depth) {
		clear_depth = d;
		glClearDepth(clear_depth);
	}

	CAMLreturn0;
}

/*
 * Buffers
 */

CAMLprim void gl_swap_buffers(void)
{
	caml_release_runtime_system();
	glXSwapBuffers(x_display, x_win);
	print_error();
	caml_acquire_runtime_system();
}

/*
 * Matrices
 */

static void load_vector(GLdouble *m, value vector)
{
	CAMLparam1(vector);

	// vector is a float array of length = 4
	assert(Is_block(vector) && Tag_val(vector) == Double_array_tag);
	assert(Wosize_val(vector) == 4 * Double_wosize);

	for (unsigned c = 0; c < 4; c++) {
		m[c] = Double_field(vector, c);
	}

	CAMLreturn0;
}

static void do_with_matrix(value matrix, void (*func)(GLdouble const *m))
{
	CAMLparam1(matrix);

	// matrix is a float array array
	assert(Is_block(matrix) && Tag_val(matrix) == 0);
	assert(Wosize_val(matrix) == 4);
	
	// We are going to extend-store the matrix here :
	GLdouble m[4][4];
	for (unsigned col = 0; col < 4; col++) {
		load_vector(&m[col][0], Field(matrix, col));
	}

	func(&m[0][0]);

	print_error();
	CAMLreturn0;
}

static void load_matrix(value matrix)
{
	do_with_matrix(matrix, glLoadMatrixd);
}

static void mult_matrix(value matrix)
{
	do_with_matrix(matrix, glMultMatrixd);
}

CAMLprim void gl_set_depth_range(value near, value far)
{
	CAMLparam2(near, far);
	assert(Is_block(near));
	assert(Is_block(far));

	glDepthRange(Double_val(near), Double_val(far));

	print_error();
	CAMLreturn0;
}

/*
 * Rendering
 */

CAMLprim void gl_render(value render_type, value vertices, value color_specs)
{
	CAMLparam3(render_type, vertices, color_specs);
	CAMLlocal1(colors);
	assert(Is_long(render_type));
	assert(Is_block(vertices) && Tag_val(vertices) == Custom_tag);
	assert(Is_block(color_specs));
	int nb_vertices = 0, nb_colors = 0;

	// vertices
	struct caml_ba_array *vertices_arr = Caml_ba_array_val(vertices);
	assert(vertices_arr->num_dims == 2);
	unsigned const v_dim = vertices_arr->dim[1];
	assert(v_dim >= 2 && v_dim <= 4);
	nb_vertices = vertices_arr->dim[0];
	glVertexPointer(v_dim, GL_DOUBLE, 0, vertices_arr->data);
	glEnableClientState(GL_VERTEX_ARRAY);

	// colors
	if (Tag_val(color_specs) == 0) {	// Array
		colors = Field(color_specs, 0);
		assert(Is_block(colors) && Tag_val(colors) == Custom_tag);
		struct caml_ba_array *colors_arr = Caml_ba_array_val(colors);
		assert(colors_arr->num_dims == 2);
		unsigned const c_dim = colors_arr->dim[1];
		assert(c_dim == 3 || c_dim == 4);
		nb_colors = colors_arr->dim[0];
		glColorPointer(c_dim, GL_DOUBLE, 0, colors_arr->data);
		glEnableClientState(GL_COLOR_ARRAY);
	} else {
		assert(Tag_val(color_specs) == 1);
		colors = Field(color_specs, 0);
		unsigned const c_dim = Wosize_val(colors) / Double_wosize;
		assert(c_dim == 3 || c_dim == 4);
		assert(Is_block(colors));
		assert(Tag_val(colors) == Double_array_tag);
		if (c_dim == 4) {
			glColor4f(
				Double_field(colors, 0),
				Double_field(colors, 1),
				Double_field(colors, 2),
				Double_field(colors, 3));
		} else {
			glColor3f(
				Double_field(colors, 0),
				Double_field(colors, 1),
				Double_field(colors, 2));
		}
		glDisableClientState(GL_COLOR_ARRAY);
	}

	if (nb_colors > 0) assert(nb_colors == nb_vertices);
	
	GLenum const mode = glmode_of_render_type(Int_val(render_type));
	glDrawArrays(mode, 0, nb_vertices);

	print_error();
	CAMLreturn0;
}

