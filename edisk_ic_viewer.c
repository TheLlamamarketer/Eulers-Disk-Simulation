/*
 * Native OpenGL initial-condition visualizer for the Euler disk model.
 *
 * This does not run the simulation. It reads the geometry, Euler angles, and
 * manual angular velocity components from an init response file, then draws
 * the disk, body axes, rotation arcs, omega component arcs, and the resultant
 * angular velocity vector.
 *
 * Controls:
 *   drag sliders    edit geometry, rotations, and omegas
 *   left drag       orbit camera outside the control panel
 *   mouse wheel     zoom
 *   1/2/3           select omega1/omega2/omega3
 *   +/-             adjust selected omega
 *   [/]/{/}         adjust theta slowly/quickly
 *   a               toggle axes
 *   o               toggle omega arcs/resultant
 *   r               toggle rotation arcs
 *   esc/q           quit
 */

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <GL/freeglut.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct Vec3 {
    double x;
    double y;
    double z;
} Vec3;

typedef struct InitialCondition {
    double radius;
    double height;
    double fillet;
    double psi;
    double theta;
    double phi;
    double omega1;
    double omega2;
    double omega3;
    int manual_omegas;
    char source[512];
} InitialCondition;

typedef enum UiParamId {
    PARAM_RADIUS = 0,
    PARAM_HEIGHT,
    PARAM_PSI,
    PARAM_THETA,
    PARAM_PHI,
    PARAM_OMEGA1,
    PARAM_OMEGA2,
    PARAM_OMEGA3,
    PARAM_COUNT
} UiParamId;

typedef struct UiParam {
    const char *label;
    double min_value;
    double max_value;
    double keyboard_step;
    int decimals;
} UiParam;

static InitialCondition g_ic;
static int g_width = 1120;
static int g_height = 760;
static double g_yaw = -55.0;
static double g_pitch = 24.0;
static double g_distance = 0.42;
static double g_target_x = 0.0;
static double g_target_y = 0.0;
static double g_target_z = 0.0;
static double g_pan_x = 0.0;
static double g_pan_y = 0.0;
static double g_pan_z = 0.0;
static int g_mouse_button = -1;
static int g_mouse_x = 0;
static int g_mouse_y = 0;
static int g_selected_omega = 2;
static int g_show_axes = 1;
static int g_show_omegas = 1;
static int g_show_rotations = 1;
static int g_active_param = -1;

static const UiParam g_ui_params[PARAM_COUNT] = {
    {"Radius [m]",       0.005, 0.200, 0.001, 4},
    {"Height [m]",       0.001, 0.060, 0.001, 4},
    {"psi Z rot [deg]", -180.0, 180.0, 1.0,   1},
    {"theta X tilt",    -89.0,  89.0, 0.5,   1},
    {"phi Y rot [deg]", -180.0, 180.0, 1.0,   1},
    {"Omega1 [rad/s]",  -80.0,  80.0, 1.0,   1},
    {"Omega2 [rad/s]",  -80.0,  80.0, 1.0,   1},
    {"Omega3 [rad/s]",  -80.0,  80.0, 1.0,   1}
};

static Vec3 vec3(double x, double y, double z)
{
    Vec3 v;
    v.x = x;
    v.y = y;
    v.z = z;
    return v;
}

static Vec3 vadd(Vec3 a, Vec3 b)
{
    return vec3(a.x + b.x, a.y + b.y, a.z + b.z);
}

static Vec3 vsub(Vec3 a, Vec3 b)
{
    return vec3(a.x - b.x, a.y - b.y, a.z - b.z);
}

static Vec3 vscale(Vec3 a, double s)
{
    return vec3(a.x*s, a.y*s, a.z*s);
}

static double vdot(Vec3 a, Vec3 b)
{
    return a.x*b.x + a.y*b.y + a.z*b.z;
}

static Vec3 vcross(Vec3 a, Vec3 b)
{
    return vec3(a.y*b.z - a.z*b.y,
                a.z*b.x - a.x*b.z,
                a.x*b.y - a.y*b.x);
}

static double vlen(Vec3 a)
{
    return sqrt(vdot(a, a));
}

static Vec3 vnorm(Vec3 a)
{
    double len = vlen(a);
    if (len <= 1.0e-12) return vec3(0.0, 0.0, 0.0);
    return vscale(a, 1.0/len);
}

static double clamp(double v, double lo, double hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static double *param_value_ptr(int id)
{
    switch (id) {
    case PARAM_RADIUS: return &g_ic.radius;
    case PARAM_HEIGHT: return &g_ic.height;
    case PARAM_PSI: return &g_ic.psi;
    case PARAM_THETA: return &g_ic.theta;
    case PARAM_PHI: return &g_ic.phi;
    case PARAM_OMEGA1: return &g_ic.omega1;
    case PARAM_OMEGA2: return &g_ic.omega2;
    case PARAM_OMEGA3: return &g_ic.omega3;
    default: return NULL;
    }
}

static double param_value(int id)
{
    double *value = param_value_ptr(id);
    return value ? *value : 0.0;
}

static double scene_span(void)
{
    return fmax(2.8*g_ic.radius, 0.18);
}

static void fit_camera_if_needed(void)
{
    double min_distance = 0.04*scene_span();
    if (g_distance < min_distance) {
        g_distance = min_distance;
    }
}

static void set_param_value(int id, double value)
{
    double *target = param_value_ptr(id);
    if (!target || id < 0 || id >= PARAM_COUNT) return;

    value = clamp(value, g_ui_params[id].min_value, g_ui_params[id].max_value);
    *target = value;
    if (id == PARAM_RADIUS) fit_camera_if_needed();
}

static void clamp_all_params(void)
{
    int i;
    for (i = 0; i < PARAM_COUNT; i++) {
        set_param_value(i, param_value(i));
    }
}

static double deg_to_rad(double deg)
{
    return deg*M_PI/180.0;
}

static void mat_identity(double m[3][3])
{
    int r, c;
    for (r = 0; r < 3; r++) {
        for (c = 0; c < 3; c++) {
            m[r][c] = r == c ? 1.0 : 0.0;
        }
    }
}

static void mat_mul(double a[3][3], double b[3][3], double out[3][3])
{
    double tmp[3][3];
    int r, c;
    for (r = 0; r < 3; r++) {
        for (c = 0; c < 3; c++) {
            tmp[r][c] = a[r][0]*b[0][c] + a[r][1]*b[1][c] + a[r][2]*b[2][c];
        }
    }
    memcpy(out, tmp, sizeof(tmp));
}

static Vec3 mat_vec(double m[3][3], Vec3 v)
{
    return vec3(m[0][0]*v.x + m[0][1]*v.y + m[0][2]*v.z,
                m[1][0]*v.x + m[1][1]*v.y + m[1][2]*v.z,
                m[2][0]*v.x + m[2][1]*v.y + m[2][2]*v.z);
}

static void mat_rot_x(double a, double m[3][3])
{
    double c = cos(a);
    double s = sin(a);
    mat_identity(m);
    m[1][1] = c;
    m[1][2] = -s;
    m[2][1] = s;
    m[2][2] = c;
}

static void mat_rot_y(double a, double m[3][3])
{
    double c = cos(a);
    double s = sin(a);
    mat_identity(m);
    m[0][0] = c;
    m[0][2] = s;
    m[2][0] = -s;
    m[2][2] = c;
}

static void mat_rot_z(double a, double m[3][3])
{
    double c = cos(a);
    double s = sin(a);
    mat_identity(m);
    m[0][0] = c;
    m[0][1] = -s;
    m[1][0] = s;
    m[1][1] = c;
}

static void orientation_mats(double rz[3][3], double rzrx[3][3], double rall[3][3])
{
    double rx[3][3];
    double ry[3][3];

    mat_rot_z(deg_to_rad(g_ic.psi), rz);
    mat_rot_x(deg_to_rad(g_ic.theta), rx);
    mat_rot_y(deg_to_rad(g_ic.phi), ry);
    mat_mul(rz, rx, rzrx);
    mat_mul(rzrx, ry, rall);
}

static void apply_orientation(double r[3][3])
{
    GLdouble m[16] = {
        r[0][0], r[1][0], r[2][0], 0.0,
        r[0][1], r[1][1], r[2][1], 0.0,
        r[0][2], r[1][2], r[2][2], 0.0,
        0.0,     0.0,     0.0,     1.0
    };
    glMultMatrixd(m);
}

static char *trim_left(char *s)
{
    while (*s && isspace((unsigned char)*s)) s++;
    return s;
}

static int parse_responses(const char *path, InitialCondition *ic)
{
    FILE *fp = fopen(path, "r");
    double values[128];
    int n = 0;
    char line[768];

    if (!fp) {
        fprintf(stderr, "Could not open %s\n", path);
        return 0;
    }

    while (fgets(line, sizeof(line), fp) && n < (int)(sizeof(values)/sizeof(values[0]))) {
        char *hash = strchr(line, '#');
        char *p;
        char *endp;
        double value;

        if (hash) *hash = '\0';
        p = trim_left(line);
        if (*p == '\0') continue;
        value = strtod(p, &endp);
        if (endp != p) {
            values[n++] = value;
        }
    }
    fclose(fp);

    if (n < 8) {
        fprintf(stderr, "%s does not contain enough response values\n", path);
        return 0;
    }

    ic->radius = values[0];
    ic->height = values[1];
    ic->fillet = values[2];
    ic->psi = values[4];
    ic->theta = values[5];
    ic->phi = values[6];
    ic->omega1 = 0.0;
    ic->omega2 = 0.0;
    ic->omega3 = 0.0;
    ic->manual_omegas = 0;
    snprintf(ic->source, sizeof(ic->source), "%s", path);

    if ((int)values[7] == 0 && n >= 13) {
        ic->omega1 = values[8];
        ic->omega2 = values[9];
        ic->omega3 = values[10];
        ic->manual_omegas = 1;
    }

    if (ic->radius <= 0.0) ic->radius = 0.08;
    if (ic->height <= 0.0) ic->height = 0.0128;
    if (ic->fillet < 0.0) ic->fillet = 0.0;
    return 1;
}

static void default_initial_condition(InitialCondition *ic)
{
    memset(ic, 0, sizeof(*ic));
    ic->radius = 0.08;
    ic->height = 0.0128;
    ic->fillet = 0.003;
    ic->psi = 0.0;
    ic->theta = 6.0;
    ic->phi = 0.0;
    ic->omega1 = 0.0;
    ic->omega2 = 0.0;
    ic->omega3 = -15.0;
    ic->manual_omegas = 1;
    snprintf(ic->source, sizeof(ic->source), "built-in manual baseline");
}

static void set_color(double r, double g, double b)
{
    glColor3d(r, g, b);
}

static int text_width_2d(const char *text)
{
    int width = 0;
    const char *c;

    for (c = text; *c; c++) {
        width += glutBitmapWidth(GLUT_BITMAP_8_BY_13, *c);
    }
    return width;
}

static void draw_text_2d(int x, int y, const char *text)
{
    const char *c;
    glRasterPos2i(x, y);
    for (c = text; *c; c++) {
        glutBitmapCharacter(GLUT_BITMAP_8_BY_13, *c);
    }
}

static void draw_rect_2d(double x, double y, double w, double h,
                         double r, double g, double b, double a)
{
    glColor4d(r, g, b, a);
    glBegin(GL_QUADS);
    glVertex2d(x, y);
    glVertex2d(x + w, y);
    glVertex2d(x + w, y + h);
    glVertex2d(x, y + h);
    glEnd();
}

static int project_to_screen(Vec3 p, double *sx, double *sy, double *sz)
{
    GLdouble model[16];
    GLdouble proj[16];
    GLint viewport[4];
    GLdouble wx;
    GLdouble wy;
    GLdouble wz;

    glGetDoublev(GL_MODELVIEW_MATRIX, model);
    glGetDoublev(GL_PROJECTION_MATRIX, proj);
    glGetIntegerv(GL_VIEWPORT, viewport);
    if (!gluProject(p.x, p.y, p.z, model, proj, viewport, &wx, &wy, &wz)) {
        return 0;
    }

    *sx = wx;
    *sy = wy;
    *sz = wz;
    return 1;
}

static void begin_2d_overlay(GLboolean *lighting, GLboolean *depth, GLboolean *blend, GLint *matrix_mode)
{
    *lighting = glIsEnabled(GL_LIGHTING);
    *depth = glIsEnabled(GL_DEPTH_TEST);
    *blend = glIsEnabled(GL_BLEND);
    glGetIntegerv(GL_MATRIX_MODE, matrix_mode);

    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    gluOrtho2D(0.0, (double)g_width, 0.0, (double)g_height);
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();

    glDisable(GL_LIGHTING);
    glDisable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

static void end_2d_overlay(GLboolean lighting, GLboolean depth, GLboolean blend, GLint matrix_mode)
{
    if (depth) glEnable(GL_DEPTH_TEST); else glDisable(GL_DEPTH_TEST);
    if (lighting) glEnable(GL_LIGHTING); else glDisable(GL_LIGHTING);
    if (blend) glEnable(GL_BLEND); else glDisable(GL_BLEND);

    glPopMatrix();
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(matrix_mode);
}

static void draw_text_3d(Vec3 p, const char *text)
{
    double sx, sy, sz;
    int width;
    GLboolean lighting;
    GLboolean depth;
    GLboolean blend;
    GLint matrix_mode;

    if (!text || !*text || !project_to_screen(p, &sx, &sy, &sz)) return;

    width = text_width_2d(text);
    begin_2d_overlay(&lighting, &depth, &blend, &matrix_mode);
    draw_rect_2d(sx + 7.0, sy - 8.0, width + 12.0, 20.0, 1.0, 1.0, 1.0, 0.86);
    glColor3d(0.05, 0.07, 0.09);
    draw_text_2d((int)(sx + 13.0), (int)(sy - 1.0), text);
    end_2d_overlay(lighting, depth, blend, matrix_mode);
}

static void draw_arrow_head_2d(Vec3 from, Vec3 to, double cr, double cg, double cb, double size)
{
    double sx0, sy0, sz0;
    double sx1, sy1, sz1;
    double dx, dy, len;
    double ux, uy, px, py;
    GLboolean lighting;
    GLboolean depth;
    GLboolean blend;
    GLint matrix_mode;

    if (!project_to_screen(from, &sx0, &sy0, &sz0) ||
        !project_to_screen(to, &sx1, &sy1, &sz1)) {
        return;
    }

    dx = sx1 - sx0;
    dy = sy1 - sy0;
    len = sqrt(dx*dx + dy*dy);
    if (len <= 1.0e-6) return;
    ux = dx/len;
    uy = dy/len;
    px = -uy;
    py = ux;

    begin_2d_overlay(&lighting, &depth, &blend, &matrix_mode);
    glColor4d(cr, cg, cb, 0.96);
    glBegin(GL_TRIANGLES);
    glVertex2d(sx1, sy1);
    glVertex2d(sx1 - ux*size + px*size*0.46, sy1 - uy*size + py*size*0.46);
    glVertex2d(sx1 - ux*size - px*size*0.46, sy1 - uy*size - py*size*0.46);
    glEnd();
    end_2d_overlay(lighting, depth, blend, matrix_mode);
}

static void draw_circle_2d(double x, double y, double radius,
                           double r, double g, double b, double a)
{
    int i;
    glColor4d(r, g, b, a);
    glBegin(GL_TRIANGLE_FAN);
    glVertex2d(x, y);
    for (i = 0; i <= 28; i++) {
        double t = 2.0*M_PI*(double)i/28.0;
        glVertex2d(x + radius*cos(t), y + radius*sin(t));
    }
    glEnd();
}

static void ui_panel_bounds(int *x, int *y, int *w, int *h)
{
    *w = 320;
    *h = 68 + PARAM_COUNT*48 + 34;
    *x = g_width - *w - 14;
    *y = g_height - *h - 14;
    if (*x < 14) *x = 14;
    if (*y < 46) *y = 46;
}

static void ui_param_track(int id, int *x, int *y, int *w)
{
    int panel_x, panel_y, panel_w, panel_h;
    int row_top;

    ui_panel_bounds(&panel_x, &panel_y, &panel_w, &panel_h);
    row_top = panel_y + panel_h - 82 - id*48;
    *x = panel_x + 18;
    *y = row_top - 22;
    *w = panel_w - 36;
}

static int ui_param_at_mouse(int mouse_x, int mouse_y_top)
{
    int id;
    int mouse_y = g_height - mouse_y_top;
    int panel_x, panel_y, panel_w, panel_h;

    ui_panel_bounds(&panel_x, &panel_y, &panel_w, &panel_h);
    if (mouse_x < panel_x || mouse_x > panel_x + panel_w ||
        mouse_y < panel_y || mouse_y > panel_y + panel_h) {
        return -1;
    }

    for (id = 0; id < PARAM_COUNT; id++) {
        int track_x, track_y, track_w;
        ui_param_track(id, &track_x, &track_y, &track_w);
        if (mouse_y >= track_y - 15 && mouse_y <= track_y + 24) {
            return id;
        }
    }

    return -1;
}

static int ui_panel_contains_mouse(int mouse_x, int mouse_y_top)
{
    int mouse_y = g_height - mouse_y_top;
    int panel_x, panel_y, panel_w, panel_h;

    ui_panel_bounds(&panel_x, &panel_y, &panel_w, &panel_h);
    return mouse_x >= panel_x && mouse_x <= panel_x + panel_w &&
           mouse_y >= panel_y && mouse_y <= panel_y + panel_h;
}

static void update_param_from_mouse(int id, int mouse_x)
{
    int track_x, track_y, track_w;
    double u;
    double value;

    if (id < 0 || id >= PARAM_COUNT) return;
    ui_param_track(id, &track_x, &track_y, &track_w);
    u = ((double)mouse_x - (double)track_x)/(double)track_w;
    u = clamp(u, 0.0, 1.0);
    value = g_ui_params[id].min_value +
            u*(g_ui_params[id].max_value - g_ui_params[id].min_value);
    set_param_value(id, value);
}

static void draw_control_panel(void)
{
    int panel_x, panel_y, panel_w, panel_h;
    int id;
    char text[160];

    ui_panel_bounds(&panel_x, &panel_y, &panel_w, &panel_h);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    draw_rect_2d(panel_x, panel_y, panel_w, panel_h, 1.0, 1.0, 1.0, 0.88);
    draw_rect_2d(panel_x, panel_y + panel_h - 40, panel_w, 40, 0.94, 0.96, 0.98, 0.96);

    glColor3d(0.05, 0.07, 0.09);
    draw_text_2d(panel_x + 16, panel_y + panel_h - 25, "Interactive initial values");
    glColor3d(0.33, 0.39, 0.46);
    draw_text_2d(panel_x + 16, panel_y + panel_h - 48, "Drag sliders. The simulation is not running.");

    for (id = 0; id < PARAM_COUNT; id++) {
        int track_x, track_y, track_w;
        double value = param_value(id);
        double u = (value - g_ui_params[id].min_value) /
                   (g_ui_params[id].max_value - g_ui_params[id].min_value);
        double knob_x;
        int row_y;
        int selected = (id == g_active_param) ||
                       (id >= PARAM_OMEGA1 && id == PARAM_OMEGA1 + g_selected_omega);

        ui_param_track(id, &track_x, &track_y, &track_w);
        row_y = track_y - 10;
        u = clamp(u, 0.0, 1.0);
        knob_x = track_x + u*track_w;

        if (selected) {
            draw_rect_2d(panel_x + 8, row_y - 4, panel_w - 16, 42, 0.88, 0.94, 0.96, 0.72);
        }

        snprintf(text, sizeof(text), "%s", g_ui_params[id].label);
        glColor3d(0.12, 0.16, 0.21);
        draw_text_2d(track_x, track_y + 24, text);
        snprintf(text, sizeof(text), "%.*f", g_ui_params[id].decimals, value);
        glColor3d(0.06, 0.09, 0.13);
        draw_text_2d(track_x + track_w - 56, track_y + 24, text);

        draw_rect_2d(track_x, track_y, track_w, 6, 0.78, 0.82, 0.87, 0.95);
        draw_rect_2d(track_x, track_y, knob_x - track_x, 6, 0.06, 0.46, 0.43, 0.95);
        draw_circle_2d(knob_x, track_y + 3, 8, 0.04, 0.34, 0.32, 1.0);
        draw_circle_2d(knob_x - 2, track_y + 5, 2.2, 1.0, 1.0, 1.0, 0.88);
    }

    glColor3d(0.33, 0.39, 0.46);
    draw_text_2d(panel_x + 16, panel_y + 14, "1/2/3 select omega   +/- nudge   wheel zoom");
    glDisable(GL_BLEND);
}

static void draw_arrow(Vec3 from, Vec3 to, double cr, double cg, double cb, const char *label)
{
    Vec3 dir = vsub(to, from);
    double len = vlen(dir);
    Vec3 unit;

    if (len <= 1.0e-9) return;
    unit = vnorm(dir);

    glDisable(GL_LIGHTING);
    glLineWidth(2.8f);
    set_color(cr, cg, cb);
    glBegin(GL_LINES);
    glVertex3d(from.x, from.y, from.z);
    glVertex3d(to.x, to.y, to.z);
    glEnd();
    glLineWidth(1.0f);
    glEnable(GL_LIGHTING);

    draw_arrow_head_2d(vadd(to, vscale(unit, -0.16*len)), to, cr, cg, cb, 12.0);

    if (label && *label) {
        Vec3 lp = vadd(to, vscale(unit, 0.022));
        draw_text_3d(lp, label);
    }
}

static Vec3 rodrigues(Vec3 v, Vec3 axis, double angle)
{
    Vec3 k = vnorm(axis);
    double c = cos(angle);
    double s = sin(angle);
    return vadd(vadd(vscale(v, c), vscale(vcross(k, v), s)),
                vscale(k, vdot(k, v)*(1.0 - c)));
}

static void draw_arc(Vec3 center, Vec3 axis, Vec3 start, double angle,
                     double radius, double cr, double cg, double cb,
                     const char *label, double line_width)
{
    int i;
    const int steps = 96;
    double visible_angle = angle;
    Vec3 previous;
    Vec3 last;
    Vec3 before_last;
    Vec3 tangent;

    if (fabs(visible_angle) < 0.08) {
        visible_angle = visible_angle < 0.0 ? -0.08 : 0.08;
    }

    start = vscale(vnorm(start), radius);
    previous = vadd(center, start);
    before_last = previous;
    last = previous;

    glDisable(GL_LIGHTING);
    glLineWidth((float)line_width);
    set_color(cr, cg, cb);
    glBegin(GL_LINE_STRIP);
    for (i = 0; i <= steps; i++) {
        double t = visible_angle*(double)i/(double)steps;
        Vec3 p = vadd(center, rodrigues(start, axis, t));
        glVertex3d(p.x, p.y, p.z);
        before_last = last;
        last = p;
    }
    glEnd();
    glLineWidth(1.0f);
    glEnable(GL_LIGHTING);

    tangent = vsub(last, before_last);
    draw_arrow_head_2d(vsub(last, vscale(vnorm(tangent), radius*0.08)), last, cr, cg, cb, 11.0);
    if (label && *label) {
        Vec3 label_p = vadd(center, rodrigues(start, axis, 0.58*visible_angle));
        draw_text_3d(label_p, label);
    }
}

static void draw_disk_body(void)
{
    int i;
    const int n = 96;
    double r = g_ic.radius;
    double h = g_ic.height;
    double half = 0.5*h;

    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, (GLfloat[]){0.78f, 0.82f, 0.86f, 1.0f});
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, (GLfloat[]){0.35f, 0.38f, 0.42f, 1.0f});
    glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 36.0f);

    glBegin(GL_QUAD_STRIP);
    for (i = 0; i <= n; i++) {
        double a = 2.0*M_PI*(double)i/(double)n;
        double x = r*cos(a);
        double z = r*sin(a);
        glNormal3d(cos(a), 0.0, sin(a));
        glVertex3d(x, -half, z);
        glVertex3d(x, half, z);
    }
    glEnd();

    glBegin(GL_TRIANGLE_FAN);
    glNormal3d(0.0, 1.0, 0.0);
    glVertex3d(0.0, half, 0.0);
    for (i = 0; i <= n; i++) {
        double a = 2.0*M_PI*(double)i/(double)n;
        glVertex3d(r*cos(a), half, r*sin(a));
    }
    glEnd();

    glBegin(GL_TRIANGLE_FAN);
    glNormal3d(0.0, -1.0, 0.0);
    glVertex3d(0.0, -half, 0.0);
    for (i = n; i >= 0; i--) {
        double a = 2.0*M_PI*(double)i/(double)n;
        glVertex3d(r*cos(a), -half, r*sin(a));
    }
    glEnd();

    draw_arrow(vec3(-0.18*r, half + 0.002*r, 0.0),
               vec3(0.78*r, half + 0.002*r, 0.0),
               0.05, 0.18, 0.75, "");
    draw_arrow(vec3(0.0, half + 0.002*r, -0.18*r),
               vec3(0.0, half + 0.002*r, 0.78*r),
               0.78, 0.09, 0.08, "");
}

static void draw_grid(void)
{
    int i;
    double extent = 0.32;
    double z = -g_ic.radius;
    int lines = 12;

    glDisable(GL_LIGHTING);
    glLineWidth(1.0f);
    glColor4d(0.42, 0.50, 0.58, 0.42);
    glBegin(GL_LINES);
    for (i = -lines; i <= lines; i++) {
        double v = extent*(double)i/(double)lines;
        glVertex3d(-extent, v, z);
        glVertex3d(extent, v, z);
        glVertex3d(v, -extent, z);
        glVertex3d(v, extent, z);
    }
    glEnd();
    glEnable(GL_LIGHTING);
}

static void draw_world_axes(void)
{
    double len = fmax(1.45*g_ic.radius, 0.11);
    double z = -g_ic.radius;
    draw_arrow(vec3(0.0, 0.0, z), vec3(len, 0.0, z), 0.80, 0.10, 0.12, "world X");
    draw_arrow(vec3(0.0, 0.0, z), vec3(0.0, len, z), 0.10, 0.55, 0.20, "world Y");
    draw_arrow(vec3(0.0, 0.0, z), vec3(0.0, 0.0, z + len), 0.13, 0.32, 0.86, "world Z");
}

static double omega_arc_span(double omega)
{
    double mag = fabs(omega);
    if (mag < 1.0e-9) return 0.0;
    return (omega < 0.0 ? -1.0 : 1.0)*(1.18*M_PI + fmin(mag, 80.0)/80.0*0.55*M_PI);
}

static double omega_line_width(double omega)
{
    return 2.0 + fmin(fabs(omega), 80.0)/80.0*5.0;
}

static void draw_scene(void)
{
    double rz[3][3], rzrx[3][3], rall[3][3];
    Vec3 e1, e2, e3;
    Vec3 xpsi, ypsi, ytilt, xtilt;
    char label[128];
    double r = g_ic.radius;
    double omega_mag;
    Vec3 omega_vec;

    orientation_mats(rz, rzrx, rall);
    e1 = vnorm(mat_vec(rall, vec3(1.0, 0.0, 0.0)));
    e2 = vnorm(mat_vec(rall, vec3(0.0, 1.0, 0.0)));
    e3 = vnorm(mat_vec(rall, vec3(0.0, 0.0, 1.0)));
    xpsi = vnorm(mat_vec(rz, vec3(1.0, 0.0, 0.0)));
    ypsi = vnorm(mat_vec(rz, vec3(0.0, 1.0, 0.0)));
    ytilt = vnorm(mat_vec(rzrx, vec3(0.0, 1.0, 0.0)));
    xtilt = vnorm(mat_vec(rzrx, vec3(1.0, 0.0, 0.0)));

    draw_grid();
    draw_world_axes();

    glPushMatrix();
    apply_orientation(rall);
    draw_disk_body();
    glPopMatrix();

    if (g_show_rotations) {
        snprintf(label, sizeof(label), "psi %.1f deg", g_ic.psi);
        draw_arc(vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(1.0, 0.0, 0.0),
                 deg_to_rad(g_ic.psi), 2.12*r, 0.72, 0.32, 0.04, label, 2.4);
        snprintf(label, sizeof(label), "theta %.1f deg", g_ic.theta);
        draw_arc(vec3(0.0, 0.0, 0.0), xpsi, ypsi,
                 deg_to_rad(g_ic.theta), 1.82*r, 0.02, 0.46, 0.42, label, 2.4);
        snprintf(label, sizeof(label), "phi %.1f deg", g_ic.phi);
        draw_arc(vec3(0.0, 0.0, 0.0), ytilt, xtilt,
                 deg_to_rad(g_ic.phi), 1.52*r, 0.48, 0.23, 0.82, label, 2.4);
    }

    if (g_show_axes) {
        draw_arrow(vec3(0.0, 0.0, 0.0), vscale(e1, 1.35*r), 0.80, 0.10, 0.12, "axis 1");
        draw_arrow(vec3(0.0, 0.0, 0.0), vscale(e2, 1.35*r), 0.10, 0.55, 0.20, "axis 2 spin");
        draw_arrow(vec3(0.0, 0.0, 0.0), vscale(e3, 1.35*r), 0.13, 0.32, 0.86, "axis 3");
    }

    if (g_show_omegas) {
        snprintf(label, sizeof(label), "omega1 %.1f", g_ic.omega1);
        draw_arc(vec3(0.0, 0.0, 0.0), e1, e2, omega_arc_span(g_ic.omega1),
                 0.58*r, 0.78, 0.40, 0.07, label, omega_line_width(g_ic.omega1));
        snprintf(label, sizeof(label), "omega2 %.1f", g_ic.omega2);
        draw_arc(vec3(0.0, 0.0, 0.0), e2, e3, omega_arc_span(g_ic.omega2),
                 0.70*r, 0.52, 0.24, 0.70, label, omega_line_width(g_ic.omega2));
        snprintf(label, sizeof(label), "omega3 %.1f", g_ic.omega3);
        draw_arc(vec3(0.0, 0.0, 0.0), e3, e1, omega_arc_span(g_ic.omega3),
                 0.82*r, 0.04, 0.45, 0.57, label, omega_line_width(g_ic.omega3));

        omega_vec = vadd(vadd(vscale(e1, g_ic.omega1), vscale(e2, g_ic.omega2)),
                         vscale(e3, g_ic.omega3));
        omega_mag = vlen(omega_vec);
        if (omega_mag > 1.0e-9) {
            draw_arrow(vec3(0.0, 0.0, 0.0), vscale(vnorm(omega_vec), 1.62*r),
                       0.04, 0.05, 0.06, "|omega| resultant");
        }
    }
}

static void draw_overlay(void)
{
    double theta = deg_to_rad(g_ic.theta);
    double cos_theta = cos(theta);
    double psi_dot = fabs(cos_theta) > 1.0e-10 ? g_ic.omega3/cos_theta : 0.0;
    double phi_dot = g_ic.omega2 - tan(theta)*g_ic.omega3;
    double omega_y = g_ic.omega2*cos(theta) - g_ic.omega3*sin(theta);
    double omega_z = g_ic.omega2*sin(theta) + g_ic.omega3*cos(theta);
    double omega_mag = sqrt(g_ic.omega1*g_ic.omega1 + g_ic.omega2*g_ic.omega2 + g_ic.omega3*g_ic.omega3);
    char line[768];

    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    gluOrtho2D(0.0, (double)g_width, 0.0, (double)g_height);
    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();

    glDisable(GL_LIGHTING);
    glDisable(GL_DEPTH_TEST);
    glColor3d(0.05, 0.07, 0.09);

    snprintf(line, sizeof(line), "Initial condition: %s", g_ic.source);
    draw_text_2d(12, g_height - 24, line);
    snprintf(line, sizeof(line), "psi %.2f deg   theta %.2f deg   phi %.2f deg",
             g_ic.psi, g_ic.theta, g_ic.phi);
    draw_text_2d(12, g_height - 44, line);
    snprintf(line, sizeof(line), "omega1 %.3f   omega2 %.3f   omega3 %.3f rad/s   |omega| %.3f",
             g_ic.omega1, g_ic.omega2, g_ic.omega3, omega_mag);
    draw_text_2d(12, g_height - 64, line);
    snprintf(line, sizeof(line), "psi_dot %.3f   phi_dot %.3f   contact omega_y %.3f   contact omega_z %.3f",
             psi_dot, phi_dot, omega_y, omega_z);
    draw_text_2d(12, g_height - 84, line);
    if (!g_ic.manual_omegas) {
        draw_text_2d(12, g_height - 104, "Strike response: geometry/angles loaded, omegas left at zero because no solver/strike impulse was run.");
    }
    draw_control_panel();
    snprintf(line, sizeof(line), "drag sliders/edit   left drag orbit   middle/right pan   wheel zoom   1/2/3 select omega%d   +/- adjust   a/o/r toggles   esc quit",
             g_selected_omega + 1);
    draw_text_2d(12, 18, line);

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_LIGHTING);
    glPopMatrix();
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
}

static void apply_camera(void)
{
    double yaw = deg_to_rad(g_yaw);
    double pitch = deg_to_rad(g_pitch);
    double cp = cos(pitch);
    double eye_x = g_target_x + g_pan_x + g_distance*cp*cos(yaw);
    double eye_y = g_target_y + g_pan_y + g_distance*cp*sin(yaw);
    double eye_z = g_target_z + g_pan_z + g_distance*sin(pitch);

    gluLookAt(eye_x, eye_y, eye_z,
              g_target_x + g_pan_x, g_target_y + g_pan_y, g_target_z + g_pan_z,
              0.0, 0.0, 1.0);
}

static void display(void)
{
    GLfloat light_pos[4] = {0.6f, -1.0f, 1.6f, 0.0f};
    GLfloat diffuse[4] = {0.94f, 0.93f, 0.90f, 1.0f};
    GLfloat ambient[4] = {0.30f, 0.32f, 0.36f, 1.0f};

    glViewport(0, 0, g_width, g_height);
    glClearColor(0.92f, 0.95f, 0.97f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(42.0, (double)g_width/(double)(g_height > 0 ? g_height : 1), 0.001, 20.0);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    apply_camera();

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_NORMALIZE);
    glEnable(GL_LINE_SMOOTH);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glLightfv(GL_LIGHT0, GL_POSITION, light_pos);
    glLightfv(GL_LIGHT0, GL_DIFFUSE, diffuse);
    glLightfv(GL_LIGHT0, GL_SPECULAR, diffuse);
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient);
    glShadeModel(GL_SMOOTH);
    glDisable(GL_CULL_FACE);

    draw_scene();
    draw_overlay();
    glutSwapBuffers();
}

static void reshape(int width, int height)
{
    g_width = width > 1 ? width : 1;
    g_height = height > 1 ? height : 1;
    glutPostRedisplay();
}

static void mouse_button(int button, int state, int x, int y)
{
    if (button == 3 && state == GLUT_DOWN) {
        g_distance *= 0.88;
        if (g_distance < 0.04*scene_span()) g_distance = 0.04*scene_span();
        glutPostRedisplay();
        return;
    }
    if (button == 4 && state == GLUT_DOWN) {
        g_distance *= 1.13;
        glutPostRedisplay();
        return;
    }

    if (state == GLUT_DOWN) {
        if (button == GLUT_LEFT_BUTTON) {
            int id = ui_param_at_mouse(x, y);
            if (id >= 0) {
                g_active_param = id;
                update_param_from_mouse(g_active_param, x);
                if (id >= PARAM_OMEGA1 && id <= PARAM_OMEGA3) {
                    g_selected_omega = id - PARAM_OMEGA1;
                }
                g_mouse_button = -1;
                glutPostRedisplay();
                return;
            }
        }
        if (ui_panel_contains_mouse(x, y)) {
            g_mouse_button = -1;
            return;
        }
        g_mouse_button = button;
        g_mouse_x = x;
        g_mouse_y = y;
    } else {
        g_mouse_button = -1;
        g_active_param = -1;
    }
}

static void mouse_motion(int x, int y)
{
    int dx = x - g_mouse_x;
    int dy = y - g_mouse_y;

    if (g_active_param >= 0) {
        update_param_from_mouse(g_active_param, x);
        glutPostRedisplay();
        return;
    }

    if (g_mouse_button == GLUT_LEFT_BUTTON) {
        g_yaw -= 0.35*(double)dx;
        g_pitch += 0.35*(double)dy;
        g_pitch = clamp(g_pitch, -89.0, 89.0);
    } else if (g_mouse_button == GLUT_MIDDLE_BUTTON || g_mouse_button == GLUT_RIGHT_BUTTON) {
        double s = 0.0018*g_distance;
        double yaw = deg_to_rad(g_yaw);
        double pitch = deg_to_rad(g_pitch);
        double right_x = -sin(yaw);
        double right_y = cos(yaw);
        double up_x = -sin(pitch)*cos(yaw);
        double up_y = -sin(pitch)*sin(yaw);
        double up_z = cos(pitch);

        g_pan_x -= dx*s*right_x;
        g_pan_y -= dx*s*right_y;
        g_pan_x += dy*s*up_x;
        g_pan_y += dy*s*up_y;
        g_pan_z += dy*s*up_z;
    }

    g_mouse_x = x;
    g_mouse_y = y;
    glutPostRedisplay();
}

static void adjust_selected_omega(double delta)
{
    int id = PARAM_OMEGA1 + g_selected_omega;
    set_param_value(id, param_value(id) + delta);
    glutPostRedisplay();
}

static void keyboard(unsigned char key, int x, int y)
{
    (void)x;
    (void)y;

    switch (key) {
    case 27:
    case 'q':
    case 'Q':
        exit(0);
        break;
    case '1':
        g_selected_omega = 0;
        break;
    case '2':
        g_selected_omega = 1;
        break;
    case '3':
        g_selected_omega = 2;
        break;
    case '+':
    case '=':
        adjust_selected_omega(1.0);
        break;
    case '-':
    case '_':
        adjust_selected_omega(-1.0);
        break;
    case '[':
        set_param_value(PARAM_THETA, g_ic.theta - 0.5);
        break;
    case ']':
        set_param_value(PARAM_THETA, g_ic.theta + 0.5);
        break;
    case '{':
        set_param_value(PARAM_THETA, g_ic.theta - 5.0);
        break;
    case '}':
        set_param_value(PARAM_THETA, g_ic.theta + 5.0);
        break;
    case 'a':
    case 'A':
        g_show_axes = !g_show_axes;
        break;
    case 'o':
    case 'O':
        g_show_omegas = !g_show_omegas;
        break;
    case 'r':
    case 'R':
        g_show_rotations = !g_show_rotations;
        break;
    default:
        break;
    }

    glutPostRedisplay();
}

int main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : NULL;

    default_initial_condition(&g_ic);
    if (path && !parse_responses(path, &g_ic)) {
        fprintf(stderr, "Using built-in defaults instead.\n");
    }
    clamp_all_params();

    g_yaw = -55.0;
    g_pitch = 24.0;
    g_distance = 2.9*scene_span();

    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB | GLUT_DEPTH);
    glutInitWindowSize(g_width, g_height);
    glutCreateWindow("Euler Disk Initial Conditions");
    glutDisplayFunc(display);
    glutReshapeFunc(reshape);
    glutMouseFunc(mouse_button);
    glutMotionFunc(mouse_motion);
    glutKeyboardFunc(keyboard);
    glutMainLoop();
    return 0;
}
