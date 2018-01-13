#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
#include <sys/select.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/bigarray.h>
#include <caml/fail.h>

#if CAML_VERSION > 31200
#   include <caml/threads.h>
#else
#   include <caml/signals.h>
#   define caml_release_runtime_system caml_enter_blocking_section
#   define caml_acquire_runtime_system caml_leave_blocking_section
#endif

#define sizeof_array(x) (sizeof(x) / sizeof(*x))

// Some constructor tags
#define Clic   0
#define UnClic 1
#define Zoom   2
#define UnZoom 3
#define Move   4
#define Resize 5

static Display *x_display;
static Window x_win;
static int win_width, win_height;
static XSetWindowAttributes win_attr = {
    .event_mask = ExposureMask | ButtonPressMask | ButtonReleaseMask | PointerMotionMask | StructureNotifyMask,
};
static bool double_buffer;  // set in init() and used in specific init* and swap_buffer.
static bool inited = false;

/*
 * Init
 */

static void print_error(void)
{
    GLenum err = glGetError();
    if (err == GL_NO_ERROR) return;

    fprintf(stderr, "GLError: %d\n", err);
}

static bool set_window_size(int width, int height)
{
    if (width == win_width && height == win_height) return false;
    win_width = width;
    win_height = height;
    return true;
}

static int init_x(char const *title, bool with_depth, bool with_alpha, bool with_msaa, int width, int height);

static int init(char const *title, bool with_depth, bool with_alpha, bool with_msaa, int width, int height)
{
    if (0 == XInitThreads()) {
        fprintf(stderr, "Cannot XInitThreads()\n");
    }
    int err = init_x(title, with_depth, with_alpha, with_msaa, width, height);
    if (0 != err) return err;
    glShadeModel(GL_FLAT);
    glEnable(GL_MULTISAMPLE);
    glDisable(GL_CULL_FACE);
    glDisable(GL_DEPTH_TEST);
    (void)set_window_size(win_width, win_height);
    glViewport(0, 0, win_width, win_height);
    print_error();
    inited = true;

    return 0;
}

CAMLprim void gl_init_native(value with_depth_, value with_alpha_, value double_buffer_, value with_msaa_, value title, value width, value height)
{
    CAMLparam5(with_depth_, with_alpha_, double_buffer_, with_msaa_, title);
    CAMLxparam2(width, height);

    assert(Tag_val(title) == String_tag);
    bool with_depth = Is_block(with_depth_) && Val_true == Field(with_depth_, 0);
    bool with_alpha = Is_block(with_alpha_) && Val_true == Field(with_alpha_, 0);
    double_buffer = !(Is_block(double_buffer_) && Val_false == Field(double_buffer_, 0));
    bool with_msaa = Is_block(with_msaa_) && Val_true == Field(with_msaa_, 0);

    if (0 != init(String_val(title), with_depth, with_alpha, with_msaa, Long_val(width), Long_val(height))) {
        caml_failwith("Cannot open window");
    }

    CAMLreturn0;
}

CAMLprim void gl_init_bytecode(value *argv, int argn)
{
  assert(argn == 7);
  return gl_init_native(argv[0], argv[1], argv[2], argv[3],
                        argv[4], argv[5], argv[6]);
}

/*
 * Event
 */

static value _clic_of(int tag, int px, int py, bool shifted)
{
    CAMLparam0();
    CAMLlocal2(clic, ret);

    clic = caml_alloc(5, tag);  // Clic (x, y, w, h, shifted)
    Store_field(clic, 0, Val_int(px));
    Store_field(clic, 1, Val_int(py));
    Store_field(clic, 2, Val_int(win_width));
    Store_field(clic, 3, Val_int(win_height));
    Store_field(clic, 4, Val_bool(shifted));

    ret = caml_alloc(1, 0); // Some...
    Store_field(ret, 0, clic);

    CAMLreturn(ret);
}

static value _unclic_of(int tag, int px, int py)
{
    CAMLparam0();
    CAMLlocal2(clic, ret);

    clic = caml_alloc(4, tag);  // Clic (x, y, w, h)
    Store_field(clic, 0, Val_int(px));
    Store_field(clic, 1, Val_int(py));
    Store_field(clic, 2, Val_int(win_width));
    Store_field(clic, 3, Val_int(win_height));

    ret = caml_alloc(1, 0); // Some...
    Store_field(ret, 0, clic);

    CAMLreturn(ret);
}

static value clic_of(int px, int py, bool shifted)
{
    return _clic_of(Clic, px, py, shifted);
}

static value unclic_of(int px, int py)
{
    return _unclic_of(UnClic, px, py);
}

static value zoom_of(int px, int py, bool shifted)
{
    return _clic_of(Zoom, px, py, shifted);
}

static value unzoom_of(int px, int py)
{
    return _unclic_of(UnZoom, px, py);
}

static value move_of(int px, int py)
{
    return _unclic_of(Move, px, py);
}

static value resize_of(int width, int height)
{
    CAMLparam0();
    CAMLlocal4(resize, w, h, ret);

    resize = caml_alloc(2, Resize); // Resize (w, h)
    w = Val_long(width);
    h = Val_long(height);
    Store_field(resize, 0, w);
    Store_field(resize, 1, h);

    ret = caml_alloc(1, 0); // Some...
    Store_field(ret, 0, resize);

    CAMLreturn(ret);
}

static void wait_event(void)
{
    while (0 == XPending(x_display)) {
        caml_release_runtime_system();
        int fd = XConnectionNumber(x_display);
        fd_set readset;
        FD_ZERO(&readset);
        FD_SET(fd, &readset);
        select(fd+1, &readset, 0, 0, NULL);
        caml_acquire_runtime_system();
    }
}

/* Event compression: for move events, pop as many as are waiting and
 * report only the last one. */
static void compress_events(XEvent *prev_xev, int prev_type)
{
    static int max_n = 0;
    int n = 0;
    XEvent xev;

    while (XPending(x_display) > 0) {
        XPeekEvent(x_display, &xev);
        if (xev.type != prev_type) {
            //printf("%d follows %d\n", xev.type, prev_type);
            if (n > max_n) {
                max_n = n;
                //printf("Compressed %d events\n", max_n);
            }
            return;
        }
        *prev_xev = xev;
        n ++;
        (void)XNextEvent(x_display, &xev);  // remove it
    }
}

static value next_event(bool wait)
{
    // Typically, the init will be performed by another thread.
    // No need to protect inited here since OCaml threads are not running concurrently.
    if (! inited) {
        caml_release_runtime_system();  // yield CPU to other threads
        caml_acquire_runtime_system();
        return Val_int(0);
    }

    while (wait || XPending(x_display) > 0) {
        XEvent xev;

        wait_event();
        (void)XNextEvent(x_display, &xev);

        if (xev.type == MotionNotify) {
            compress_events(&xev, MotionNotify);
            return move_of(xev.xmotion.x, xev.xmotion.y);
        } else if (xev.type == KeyPress) {
        } else if (xev.type == ButtonPress) {
            switch (xev.xbutton.button) {
                case Button1: case Button2: case Button3:
                    return clic_of(xev.xbutton.x, xev.xbutton.y, xev.xbutton.state & ShiftMask);
                case Button4:
                    return zoom_of(xev.xbutton.x, xev.xbutton.y, xev.xbutton.state & ShiftMask);
                case Button5:
                    return unzoom_of(xev.xbutton.x, xev.xbutton.y);
            }
        } else if (xev.type == ButtonRelease) {
            return unclic_of(xev.xbutton.x, xev.xbutton.y);
        } else if (xev.type == Expose) {
            compress_events(&xev, Expose);
            // We have in the event the size of the exposed area only
            (void)set_window_size(win_width, win_height);
            return resize_of(win_width, win_height);
        } else if (xev.type == ConfigureNotify) {
            compress_events(&xev, ConfigureNotify);
            if (set_window_size(xev.xconfigurerequest.width, xev.xconfigurerequest.height)) {
                return resize_of(xev.xconfigurerequest.width, xev.xconfigurerequest.height);
            }
        }
    }

    return Val_int(0);  // None
}

CAMLprim value gl_next_event(value wait)
{
    return next_event(Bool_val(wait));
}

/*
 * Clear
 */

static void reset_clear_color(value color);
static void reset_clear_depth(value depth);

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
 * Matrices
 */

#if 0
static void print_arr(GLfixed *arr_, unsigned vec_len, unsigned nb_vecs)
{
    int (*arr)[vec_len] = (void*)arr_;
    for (unsigned v = 0; v < nb_vecs ; v++) {
        fprintf(stderr, "V[%u] = { %"PRIx", %"PRIx", %"PRIx", %"PRIx" }\n",
            v, PRIX(arr[v][0]), PRIX(arr[v][1]),
            vec_len > 2 ? PRIX(arr[v][2]) : PRIX(0),
            vec_len > 3 ? PRIX(arr[v][3]) : PRIX(0));
    }
}
#endif

static void load_matrix(value matrix);

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

CAMLprim void gl_set_viewport(value x, value y, value width, value height)
{
    CAMLparam4(x, y, width, height);

    glViewport(Long_val(x), Long_val(y), Long_val(width), Long_val(height));
    print_error();

    CAMLreturn0;
}

CAMLprim void gl_set_scissor(value x, value y, value width, value height)
{
    CAMLparam4(x, y, width, height);

    glEnable(GL_SCISSOR_TEST);
    glScissor(Long_val(x), Long_val(y), Long_val(width), Long_val(height));
    print_error();

    CAMLreturn0;
}

CAMLprim void gl_disable_scissor(void)
{
    glDisable(GL_SCISSOR_TEST);
    print_error();
}

CAMLprim value gl_window_size(void)
{
    CAMLparam0();
    CAMLlocal1(ret);

    ret = caml_alloc_tuple(2);
    Store_field(ret, 0, Val_int(win_width));
    Store_field(ret, 1, Val_int(win_height));

    CAMLreturn(ret);
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

