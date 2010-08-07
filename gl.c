#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <GL/gl.h>
#include <GL/glx.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/bigarray.h>

#define sizeof_array(x) (sizeof(x) / sizeof(*x))

static Display *x_display;
static Window x_win;
static GLXContext glx_context;
static int win_width = 800, win_height = 480;

/*
 * Init
 */

static void print_error(void)
{
	GLenum err = glGetError();
	if (err == GL_NO_ERROR) return;

	fprintf(stderr, "GLError: %d\n", err);
}

static int init_glx(char const *title, bool with_depth, bool with_alpha)
{
	fprintf(stderr, "Init GLX for %sdepth and %salpha\n",
		with_depth ? "":"no ",
		with_alpha ? "":"no ");

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

	XSetWindowAttributes swa = {
		.event_mask = ExposureMask | /*KeyPressMask |*/ ButtonPressMask | ResizeRedirectMask,
	};

	x_win = XCreateWindow(x_display, root,
		0, 0, win_width, win_height, 0,
		vinfo->depth, InputOutput,
		vinfo->visual, CWEventMask,
		&swa); 

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

static void resize_window(int width, int height);	// TODO remove this call
static void init(char const *title, bool with_depth, bool with_alpha)
{
	int err = init_glx(title, with_depth, with_alpha);
	assert(! err);
	resize_window(win_width, win_height);
}

CAMLprim void gl_init(value with_depth_, value with_alpha_, value title)
{
	CAMLparam3(with_depth_, with_alpha_, title);

	fprintf(stderr, "Glop init\n");
	assert(Tag_val(title) == String_tag);
	bool with_depth = Is_block(with_depth_) && Val_true == Field(with_depth_, 0);
	bool with_alpha = Is_block(with_alpha_) && Val_true == Field(with_alpha_, 0);
	
	init(String_val(title), with_depth, with_alpha);

	print_error();
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
 * Events
 */

static void resize_window(int width, int height)
{
	fprintf(stderr, "Windows size set to %d x %d\n", width, height);
	win_width = width;
	win_height = height;

	// FIXME: better call a user defined callback
	glViewport(0, 0, width, height);
	glShadeModel(GL_FLAT);
	glDisable(GL_CULL_FACE);
	glDisable(GL_DEPTH_TEST);
}

static value clic_of(int px, int py)
{
	CAMLparam0();
	CAMLlocal4(clic, xd, yd, ret);

	GLdouble const x = (double)(px*2 - win_width) / win_width;
	GLdouble const y = (double)(win_height - py*2) / win_height;
	fprintf(stderr, "Clic at (%d, %d) -> %g, %g\n", px, py, x, y);

	clic = caml_alloc(2, 0);	// Clic (x, y)
	xd = caml_copy_double(x);
	yd = caml_copy_double(y);
	Store_field(clic, 0, xd);
	Store_field(clic, 1, yd);

	ret = caml_alloc(1, 0);	// Some...
	Store_field(ret, 0, clic);

	CAMLreturn(ret);
}

static value next_event(bool wait)
{
	while (wait || XPending(x_display)) {
		XEvent xev;
		(void)XNextEvent(x_display, &xev);

		if (xev.type == MotionNotify) {
			return clic_of(xev.xmotion.x, xev.xmotion.y);
		} else if (xev.type == KeyPress) {
			fprintf(stderr, "Ignoring key press\n");
		} else if (xev.type == ButtonPress) {
			return clic_of(xev.xbutton.x, xev.xbutton.y);
		} else if (xev.type == ResizeRequest) {
			resize_window(xev.xresizerequest.width, xev.xresizerequest.height);
		}
	}

	return Val_int(0);	// None
}

CAMLprim value gl_next_event(value wait)
{
	fprintf(stderr, "Next event...\n");
	return next_event(Bool_val(wait));
}

/*
 * Clear
 */

static GLclampf clear_color[4];
static GLclampf clear_depth;

static void reset_clear_color(value color)
{
	CAMLparam1(color);
	assert(Is_block(color));
	assert(Wosize_val(color) == 4);
	bool changed = false;

	for (unsigned i = 0; i < 4; i++) {
		GLclampf const c = Double_field(color, i);
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

CAMLprim void gl_clear(value color_opt, value depth_opt)
{
	GLbitfield mask = 0;
	CAMLparam2(color_opt, depth_opt);

	if (Is_block(color_opt)) {
		reset_clear_color(Field(color_opt, 0));
		mask |= GL_COLOR_BUFFER_BIT;
	}
	
	if (Is_block(depth_opt)) {
		reset_clear_depth(Field(depth_opt, 0));
		mask |= GL_DEPTH_BUFFER_BIT;
	}

	glClear(mask);

	print_error();
	CAMLreturn0;
}

/*
 * Buffers
 */

CAMLprim void gl_swap_buffers(void)
{
	glXSwapBuffers(x_display, x_win);
	print_error();
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

static void load_matrix(value matrix)
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

	glLoadMatrixd(&m[0][0]);

	print_error();
	CAMLreturn0;
}

CAMLprim void gl_set_projection(value matrix)
{
	CAMLparam1(matrix);

	glMatrixMode(GL_PROJECTION);
	load_matrix(matrix);

	CAMLreturn0;
}

CAMLprim void gl_set_modelview(value matrix)
{
	CAMLparam1(matrix);

	glMatrixMode(GL_MODELVIEW);
	load_matrix(matrix);

	CAMLreturn0;
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

static GLenum glmode_of_render_type(int t)
{
	static GLenum const modes[] = {
		GL_POINTS, GL_LINE_STRIP, GL_LINE_LOOP, GL_LINES,
		GL_TRIANGLE_STRIP, GL_TRIANGLE_FAN, GL_TRIANGLES,
	};
	assert(t >= 0 && t < (int)sizeof_array(modes));
	return modes[t];
}

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
/*	double (*arr)[v_dim] = vertices_arr->data;
	for (int v = 0; v < nb_vertices ; v++) {
		fprintf(stderr, "V[%d] = { %g, %g, %g, %g }\n",
			v, arr[v][0], arr[v][1],
			v_dim > 2 ? arr[v][2] : 0.,
			v_dim > 3 ? arr[v][3] : 0.);
	}*/

	// colors
	if (Tag_val(color_specs) == 0) {	// Array
		colors = Field(color_specs, 0);
		assert(Is_block(colors) && Tag_val(colors) == Custom_tag);
		struct caml_ba_array *colors_arr = Caml_ba_array_val(colors);
		assert(colors_arr->num_dims == 2);
		assert(colors_arr->dim[1] == 4);
		nb_colors = colors_arr->dim[0];
		glColorPointer(colors_arr->dim[1], GL_DOUBLE, 0, colors_arr->data);
		glEnableClientState(GL_COLOR_ARRAY);
	} else {
		assert(Tag_val(color_specs) == 1);
		colors = Field(color_specs, 0);
		assert(Wosize_val(colors) == 4);
		assert(Is_block(Field(colors, 3)));
		assert(Tag_val(Field(colors, 3)) == Double_tag);
		glColor4f(
			Double_val(Field(colors, 0)),
			Double_val(Field(colors, 1)),
			Double_val(Field(colors, 2)),
			Double_val(Field(colors, 3)));
		glDisableClientState(GL_COLOR_ARRAY);
	}

	if (nb_colors > 0) assert(nb_colors == nb_vertices);
	
	fprintf(stderr, "Rendering with %d vertices, type %d\n", nb_vertices, Int_val(render_type));
	GLenum const mode = glmode_of_render_type(Int_val(render_type));
	glDrawArrays(mode, 0, nb_vertices);

	print_error();
	CAMLreturn0;
}

