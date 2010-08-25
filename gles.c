#include <EGL/egl.h>
#include <GLES/gl.h>
#include <gl_common.c>

#define PRIx "f"
#define PRIX(v) ((float)v / 65536.)

/*
 * Init
 */

EGLDisplay egl_display;
EGLSurface egl_surface;
EGLContext egl_context;

static int init_egl(bool with_depth, bool with_alpha)
{
	egl_display = eglGetDisplay((EGLNativeDisplayType)x_display);
	if (egl_display == EGL_NO_DISPLAY) {
		fprintf(stderr, "Got no EGL display.\n");
		return -1;
	}

	if (! eglInitialize(egl_display, NULL, NULL)) {
		fprintf(stderr, "Unable to initialize EGL\n");
		return -1;
	}

	EGLint attr[] = {
		EGL_BUFFER_SIZE, 16,
		EGL_DEPTH_SIZE, with_depth ? 8:0,
		EGL_ALPHA_SIZE, with_alpha ? 2:0,
		EGL_NONE
	};

	EGLConfig ecfg;
	EGLint    num_config;
	if (! eglChooseConfig(egl_display, attr, &ecfg, 1, &num_config)) {
		fprintf(stderr, "Failed to choose config (eglError: %d)\n", eglGetError());
		return -1;
	}

	if (num_config != 1) {
		fprintf(stderr, "Didn't get exactly one config, but %d\n", (int)num_config);
		return -1;
	}

	egl_surface = eglCreateWindowSurface(egl_display, ecfg, (void*)x_win, NULL);
	if (egl_surface == EGL_NO_SURFACE) {
		fprintf(stderr, "Unable to create EGL surface (eglError: %d)\n", eglGetError());
		return -1;
	}

	EGLint ctxattr[] = {
		EGL_NONE
	};
	egl_context = eglCreateContext(egl_display, ecfg, EGL_NO_CONTEXT, ctxattr);
	if (egl_context == EGL_NO_CONTEXT) {
		fprintf(stderr, "Unable to create EGL context (eglError: %d)\n", eglGetError());
		return -1;
	}

	if (EGL_TRUE != eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context)) {
		fprintf(stderr, "Unable to associate context and surface (eglError: %d)\n", eglGetError());
		return -1;
	}

	return 0;
}

static int init_x(char const *title, bool with_depth, bool with_alpha, int width, int height)
{
	x_display = XOpenDisplay(NULL);
	if (! x_display) {
		fprintf(stderr, "Cannot connect to X server\n");
		return -1;
	}

	win_width = width;
	win_height = height;

	Window root = DefaultRootWindow(x_display);

	x_win = XCreateWindow(x_display, root,
		0, 0, win_width, win_height,   0,
		CopyFromParent, InputOutput,
		CopyFromParent, CWEventMask,
		&win_attr);

	XSetWindowAttributes xattr;
	Atom atom;
	static int const one = 1;

	xattr.override_redirect = False;
	XChangeWindowAttributes(x_display, x_win, CWOverrideRedirect, &xattr);

	atom = XInternAtom (x_display, "_NET_WM_STATE_FULLSCREEN", True);
	XChangeProperty(x_display, x_win,
		XInternAtom(x_display, "_NET_WM_STATE", True),
		XA_ATOM, 32, PropModeReplace,
		(unsigned char *)&atom, 1);

	XChangeProperty(x_display, x_win,
		XInternAtom(x_display, "_HILDON_NON_COMPOSITED_WINDOW", True),
		XA_INTEGER, 32, PropModeReplace,
		(unsigned char *)&one,  1);

	XMapWindow(x_display, x_win);
	XStoreName(x_display, x_win, title);

	//// get identifiers for the provided atom name strings
	Atom wm_state   = XInternAtom(x_display, "_NET_WM_STATE", False);
	Atom fullscreen = XInternAtom(x_display, "_NET_WM_STATE_FULLSCREEN", False);

	XEvent xev;
	memset ( &xev, 0, sizeof(xev) );

	xev.type                 = ClientMessage;
	xev.xclient.window       = x_win;
	xev.xclient.message_type = wm_state;
	xev.xclient.format       = 32;
	xev.xclient.data.l[0]    = 1;
	xev.xclient.data.l[1]    = fullscreen;
	XSendEvent(x_display, DefaultRootWindow(x_display), False, SubstructureNotifyMask, &xev);

	return init_egl(with_depth, with_alpha);
}

CAMLprim void gl_init(value with_depth_, value with_alpha_, value title, value width, value height)
{
	CAMLparam5(with_depth_, with_alpha_, title, width, height);

	assert(Tag_val(title) == String_tag);
	bool with_depth = Is_block(with_depth_) && Val_true == Field(with_depth_, 0);
	bool with_alpha = Is_block(with_alpha_) && Val_true == Field(with_alpha_, 0);
	
	init(String_val(title), with_depth, with_alpha, Long_val(width), Long_val(height));

	print_error();
	CAMLreturn0;
}

CAMLprim void gl_exit(void)
{
	CAMLparam0();

	print_error();
	eglDestroyContext(egl_display, egl_context);
	eglDestroySurface(egl_display, egl_surface);
	eglTerminate(egl_display);
	XDestroyWindow(x_display, x_win);
	XCloseDisplay(x_display);

	CAMLreturn0;
}

/*
 * Clear
 */

static GLclampx clear_color[4];
static GLclampx clear_depth;

static void reset_clear_color(value color)
{
	CAMLparam1(color);
	assert(Is_block(color));
	assert(Wosize_val(color) == 4);
	bool changed = false;

	for (unsigned i = 0; i < 4; i++) {
		GLclampx const c = Nativeint_val(Field(color, i));
		if (c != clear_color[i]) {
			changed = true;
			clear_color[i] = c;
		}
	}

	if (changed) {
		glClearColorx(clear_color[0], clear_color[1], clear_color[2], clear_color[3]);
	}

	CAMLreturn0;
}

static void reset_clear_depth(value depth)
{
	CAMLparam1(depth);
	assert(Tag_val(depth) == Custom_tag);
	
	GLclampx const d = Nativeint_val(depth);
	if (d != clear_depth) {
		clear_depth = d;
		glClearDepthx(clear_depth);
	}

	CAMLreturn0;
}

/*
 * Buffers
 */

CAMLprim void gl_swap_buffers(void)
{
	int res = eglSwapBuffers(egl_display, egl_surface);
	assert(res == EGL_TRUE);
	print_error();
}

/*
 * Matrices
 */

static void load_vector(GLfixed *m, value vector)
{
	CAMLparam1(vector);
	CAMLlocal1(natint);

	// vector is a nativeint array of length = 4
	assert(Is_block(vector) && Tag_val(vector) == 0);
	assert(Wosize_val(vector) == 4);

	for (unsigned c = 0; c < 4; c++) {
		natint = Field(vector, c);
		assert(Is_block(natint) && Tag_val(natint) == Custom_tag);
		m[c] = Nativeint_val(natint);
	}

	CAMLreturn0;
}

static void load_matrix(value matrix)
{
	CAMLparam1(matrix);

	// matrix is a nativeint array array
	assert(Is_block(matrix) && Tag_val(matrix) == 0);
	assert(Wosize_val(matrix) == 4);
	
	// We are going to extend-store the matrix here :
	GLfixed m[4][4];
	for (unsigned col = 0; col < 4; col++) {
		load_vector(&m[col][0], Field(matrix, col));
	}

	glLoadMatrixx(&m[0][0]);

	print_error();
	CAMLreturn0;
}

CAMLprim void gl_set_depth_range(value near, value far)
{
	CAMLparam2(near, far);
	assert(Is_long(near));	// FIXME: seams bogus, should be nativeints
	assert(Is_long(far));

	glDepthRangex(Long_val(near), Long_val(far));

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
	assert(vertices_arr->dim[1] >= 2 && vertices_arr->dim[1] <= 4);
	nb_vertices = vertices_arr->dim[0];
	glVertexPointer(vertices_arr->dim[1], GL_FIXED, 0, vertices_arr->data);
	glEnableClientState(GL_VERTEX_ARRAY);

	// colors
	if (Tag_val(color_specs) == 0) {	// Array
		colors = Field(color_specs, 0);
		assert(Is_block(colors) && Tag_val(colors) == Custom_tag);
		struct caml_ba_array *colors_arr = Caml_ba_array_val(colors);
		assert(colors_arr->num_dims == 2);
		assert(colors_arr->dim[1] == 4);
		nb_colors = colors_arr->dim[0];
		glColorPointer(colors_arr->dim[1], GL_FIXED, 0, colors_arr->data);
		glEnableClientState(GL_COLOR_ARRAY);
	} else {
		assert(Tag_val(color_specs) == 1);
		colors = Field(color_specs, 0);
		assert(Wosize_val(colors) == 4);
		assert(Tag_val(Field(colors, 3)) == Custom_tag);
		glColor4x(
			Nativeint_val(Field(colors, 0)),
			Nativeint_val(Field(colors, 1)),
			Nativeint_val(Field(colors, 2)),
			Nativeint_val(Field(colors, 3)));
		glDisableClientState(GL_COLOR_ARRAY);
	}

	if (nb_colors > 0) assert(nb_colors == nb_vertices);
	
	GLenum const mode = glmode_of_render_type(Int_val(render_type));
	glDrawArrays(mode, 0, nb_vertices);

	print_error();
	CAMLreturn0;
}

