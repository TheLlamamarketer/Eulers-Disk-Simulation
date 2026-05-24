/*
 * Native OpenGL viewer for the Euler disk animation data.
 *
 * Reads the same animat.txt format used by the original Fortran/GLUT app:
 *   radius
 *   height
 *   fillet_radius
 *   frame_count
 *   t psi theta phi xc yc zc xp yp
 * Also reads report.txt from the same folder when available so pendulum-strike
 * runs can show the strike point or two strike points on the disk.
 *
 * Controls:
 *   left drag       orbit camera
 *   middle/right    pan camera
 *   mouse wheel     zoom
 *   space           play / pause
 *   r               restart
 *   +/-             speed up / slow down
 *   g               toggle grid
 *   p               toggle contact path
 *   t               toggle time overlay
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

typedef struct Frame {
    double t;
    double psi;
    double theta;
    double phi;
    double q[4];
    double xc;
    double yc;
    double zc;
    double xp;
    double yp;
} Frame;

typedef struct AnimData {
    double r;
    double h;
    double rho;
    int n;
    int strike_mode;
    int strike_point_count;
    int strike_direction_known[2];
    double strike_point[2][3];
    double strike_direction[2];
    Frame *frames;
    double min_x;
    double max_x;
    double min_y;
    double max_y;
    double min_z;
    double max_z;
} AnimData;

static AnimData g_data;
static int g_frame = 0;
static double g_time = 0.0;
static int g_playing = 1;
static double g_speed = 1.0;

static int g_width = 1100;
static int g_height = 760;
static double g_yaw = -55.0;
static double g_pitch = 24.0;
static double g_distance = 1.0;
static double g_target_x = 0.0;
static double g_target_y = 0.0;
static double g_target_z = 0.0;
static double g_pan_x = 0.0;
static double g_pan_y = 0.0;
static double g_pan_z = 0.0;

static int g_last_ms = 0;
static int g_mouse_button = -1;
static int g_mouse_x = 0;
static int g_mouse_y = 0;

static int g_show_grid = 1;
static int g_show_path = 1;
static int g_show_time = 1;

static void quat_from_axis_angle(double q[4], double angle, double x, double y, double z)
{
    double half = 0.5 * angle;
    double s = sin(half);

    q[0] = cos(half);
    q[1] = s * x;
    q[2] = s * y;
    q[3] = s * z;
}

static void quat_mul(const double a[4], const double b[4], double out[4])
{
    double q[4];

    q[0] = a[0]*b[0] - a[1]*b[1] - a[2]*b[2] - a[3]*b[3];
    q[1] = a[0]*b[1] + a[1]*b[0] + a[2]*b[3] - a[3]*b[2];
    q[2] = a[0]*b[2] - a[1]*b[3] + a[2]*b[0] + a[3]*b[1];
    q[3] = a[0]*b[3] + a[1]*b[2] - a[2]*b[1] + a[3]*b[0];

    out[0] = q[0];
    out[1] = q[1];
    out[2] = q[2];
    out[3] = q[3];
}

static void quat_normalize(double q[4])
{
    double len = sqrt(q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3]);

    if (len <= 0.0) {
        q[0] = 1.0;
        q[1] = q[2] = q[3] = 0.0;
        return;
    }

    q[0] /= len;
    q[1] /= len;
    q[2] /= len;
    q[3] /= len;
}

static double quat_dot(const double a[4], const double b[4])
{
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3];
}

static void frame_update_quat(Frame *f)
{
    double qz[4];
    double qx[4];
    double qy[4];
    double qmesh[4];
    double tmp[4];
    double tmp2[4];

    quat_from_axis_angle(qz, f->psi, 0.0, 0.0, 1.0);
    quat_from_axis_angle(qx, f->theta, 1.0, 0.0, 0.0);
    quat_from_axis_angle(qy, f->phi, 0.0, 1.0, 0.0);
    quat_from_axis_angle(qmesh, 0.5 * M_PI, 1.0, 0.0, 0.0);

    quat_mul(qz, qx, tmp);
    quat_mul(tmp, qy, tmp2);
    quat_mul(tmp2, qmesh, f->q);
    quat_normalize(f->q);
}

static void quat_slerp(const double a[4], const double b_in[4], double u, double out[4])
{
    double b[4] = {b_in[0], b_in[1], b_in[2], b_in[3]};
    double dot = quat_dot(a, b);
    double scale_a;
    double scale_b;
    int i;

    if (dot < 0.0) {
        dot = -dot;
        b[0] = -b[0];
        b[1] = -b[1];
        b[2] = -b[2];
        b[3] = -b[3];
    }
    if (dot > 1.0) {
        dot = 1.0;
    }

    if (dot > 0.9995) {
        for (i = 0; i < 4; i++) {
            out[i] = a[i] + u*(b[i] - a[i]);
        }
        quat_normalize(out);
        return;
    }

    {
        double theta0 = acos(dot);
        double theta = theta0 * u;
        double sin_theta = sin(theta);
        double sin_theta0 = sin(theta0);

        scale_a = cos(theta) - dot * sin_theta / sin_theta0;
        scale_b = sin_theta / sin_theta0;
    }

    for (i = 0; i < 4; i++) {
        out[i] = scale_a*a[i] + scale_b*b[i];
    }
    quat_normalize(out);
}

static void apply_quat_rotation(const double q[4])
{
    double w = q[0];
    double x = q[1];
    double y = q[2];
    double z = q[3];
    GLdouble m[16];

    m[0]  = 1.0 - 2.0*y*y - 2.0*z*z;
    m[1]  = 2.0*x*y + 2.0*z*w;
    m[2]  = 2.0*x*z - 2.0*y*w;
    m[3]  = 0.0;

    m[4]  = 2.0*x*y - 2.0*z*w;
    m[5]  = 1.0 - 2.0*x*x - 2.0*z*z;
    m[6]  = 2.0*y*z + 2.0*x*w;
    m[7]  = 0.0;

    m[8]  = 2.0*x*z + 2.0*y*w;
    m[9]  = 2.0*y*z - 2.0*x*w;
    m[10] = 1.0 - 2.0*x*x - 2.0*y*y;
    m[11] = 0.0;

    m[12] = 0.0;
    m[13] = 0.0;
    m[14] = 0.0;
    m[15] = 1.0;

    glMultMatrixd(m);
}

static void quat_inverse_rotate_vec(const double q[4], const double v[3], double out[3])
{
    double w = q[0];
    double x = q[1];
    double y = q[2];
    double z = q[3];
    double m00 = 1.0 - 2.0*y*y - 2.0*z*z;
    double m01 = 2.0*x*y - 2.0*z*w;
    double m02 = 2.0*x*z + 2.0*y*w;
    double m10 = 2.0*x*y + 2.0*z*w;
    double m11 = 1.0 - 2.0*x*x - 2.0*z*z;
    double m12 = 2.0*y*z - 2.0*x*w;
    double m20 = 2.0*x*z - 2.0*y*w;
    double m21 = 2.0*y*z + 2.0*x*w;
    double m22 = 1.0 - 2.0*x*x - 2.0*y*y;

    out[0] = m00*v[0] + m10*v[1] + m20*v[2];
    out[1] = m01*v[0] + m11*v[1] + m21*v[2];
    out[2] = m02*v[0] + m12*v[1] + m22*v[2];
}

static int contact_point_reliable(const Frame *f)
{
    const double near_flat_margin = 0.035;
    return fabs(fabs(f->theta) - 0.5 * M_PI) > near_flat_margin;
}

static void die(const char *message)
{
    fprintf(stderr, "%s\n", message);
    exit(1);
}

static char *trim_left(char *s)
{
    while (*s && isspace((unsigned char)*s)) {
        s++;
    }
    return s;
}

static void report_path_for_anim_path(const char *anim_path, char *report_path, size_t size)
{
    const char *slash = strrchr(anim_path, '/');
    const char *backslash = strrchr(anim_path, '\\');
    const char *sep = slash;

    if (backslash && (!sep || backslash > sep)) {
        sep = backslash;
    }

    if (sep) {
        size_t prefix_len = (size_t)(sep - anim_path + 1);
        if (prefix_len >= size) {
            prefix_len = size > 0 ? size - 1 : 0;
        }
        if (prefix_len > 0) {
            memcpy(report_path, anim_path, prefix_len);
        }
        if (prefix_len < size) {
            snprintf(report_path + prefix_len, size - prefix_len, "report.txt");
        }
    } else {
        snprintf(report_path, size, "report.txt");
    }
}

static int read_report(const char *anim_path, AnimData *data)
{
    char report_path[512];
    FILE *fp;
    char line[512];

    data->strike_mode = 0;
    data->strike_point_count = 0;
    data->strike_direction_known[0] = 0;
    data->strike_direction_known[1] = 0;
    data->strike_point[0][0] = 0.0;
    data->strike_point[0][1] = 0.0;
    data->strike_point[0][2] = 0.0;
    data->strike_point[1][0] = 0.0;
    data->strike_point[1][1] = 0.0;
    data->strike_point[1][2] = 0.0;
    data->strike_direction[0] = 0.0;
    data->strike_direction[1] = 0.0;

    report_path_for_anim_path(anim_path, report_path, sizeof(report_path));
    fp = fopen(report_path, "r");
    if (!fp) {
        return 1;
    }

    while (fgets(line, sizeof(line), fp)) {
        char *p = trim_left(line);

        if (strstr(p, "Initial condition mode: double pendulum strike") != NULL) {
            data->strike_mode = 2;
            continue;
        }

        if (strstr(p, "Initial condition mode: pendulum strike") != NULL) {
            data->strike_mode = 1;
            continue;
        }

        if (strstr(p, "Strike 2 direction") != NULL) {
            double direction;

            if (sscanf(p, "Strike 2 direction [rad] %lf", &direction) == 1) {
                data->strike_direction[1] = direction;
                data->strike_direction_known[1] = 1;
            }
            continue;
        }

        if (strstr(p, "Strike direction") != NULL) {
            double direction;

            if (sscanf(p, "Strike direction [rad] %lf", &direction) == 1) {
                data->strike_direction[0] = direction;
                data->strike_direction_known[0] = 1;
            }
            continue;
        }

        if (strstr(p, "Strike point 2 body") != NULL) {
            double x;
            double y;
            double z;

            if (sscanf(p, "Strike point 2 body [m] %lf %lf %lf", &x, &y, &z) == 3) {
                data->strike_point[1][0] = x;
                data->strike_point[1][1] = y;
                data->strike_point[1][2] = z;
                if (data->strike_point_count < 2) {
                    data->strike_point_count = 2;
                }
            }
            continue;
        }

        if (strstr(p, "Strike point body") != NULL) {
            double x;
            double y;
            double z;

            if (sscanf(p, "Strike point body [m] %lf %lf %lf", &x, &y, &z) == 3) {
                data->strike_point[0][0] = x;
                data->strike_point[0][1] = y;
                data->strike_point[0][2] = z;
                if (data->strike_point_count < 1) {
                    data->strike_point_count = 1;
                }
            }
        }
    }

    fclose(fp);
    return 1;
}

static int read_data(const char *path, AnimData *data)
{
    FILE *fp = fopen(path, "r");
    char line[512];
    int i;

    memset(data, 0, sizeof(*data));
    data->min_x = data->min_y = data->min_z = 1.0e300;
    data->max_x = data->max_y = data->max_z = -1.0e300;

    if (!fp) {
        fprintf(stderr, "Could not open %s\n", path);
        return 0;
    }

    if (!fgets(line, sizeof(line), fp) || sscanf(line, "%lf", &data->r) != 1) {
        fclose(fp);
        return 0;
    }
    if (!fgets(line, sizeof(line), fp) || sscanf(line, "%lf", &data->h) != 1) {
        fclose(fp);
        return 0;
    }
    if (!fgets(line, sizeof(line), fp) || sscanf(line, "%lf", &data->rho) != 1) {
        fclose(fp);
        return 0;
    }
    if (!fgets(line, sizeof(line), fp) || sscanf(line, "%d", &data->n) != 1 || data->n <= 0) {
        fclose(fp);
        return 0;
    }

    data->frames = (Frame *)calloc((size_t)data->n, sizeof(Frame));
    if (!data->frames) {
        fclose(fp);
        return 0;
    }

    for (i = 0; i < data->n; i++) {
        Frame *f = &data->frames[i];
        char *p;

        if (!fgets(line, sizeof(line), fp)) {
            data->n = i;
            break;
        }

        p = trim_left(line);
        if (*p == '\0') {
            i--;
            continue;
        }

        if (sscanf(p, "%lf %lf %lf %lf %lf %lf %lf %lf %lf",
                   &f->t, &f->psi, &f->theta, &f->phi,
                   &f->xc, &f->yc, &f->zc, &f->xp, &f->yp) != 9) {
            data->n = i;
            break;
        }
        frame_update_quat(f);
        if (i > 0 && quat_dot(data->frames[i - 1].q, f->q) < 0.0) {
            f->q[0] = -f->q[0];
            f->q[1] = -f->q[1];
            f->q[2] = -f->q[2];
            f->q[3] = -f->q[3];
        }

        if (f->xc < data->min_x) data->min_x = f->xc;
        if (f->xp < data->min_x) data->min_x = f->xp;
        if (f->xc > data->max_x) data->max_x = f->xc;
        if (f->xp > data->max_x) data->max_x = f->xp;

        if (f->yc < data->min_y) data->min_y = f->yc;
        if (f->yp < data->min_y) data->min_y = f->yp;
        if (f->yc > data->max_y) data->max_y = f->yc;
        if (f->yp > data->max_y) data->max_y = f->yp;

        if (f->zc - data->r < data->min_z) data->min_z = f->zc - data->r;
        if (f->zc + data->r > data->max_z) data->max_z = f->zc + data->r;
        if (0.0 < data->min_z) data->min_z = 0.0;
        if (0.0 > data->max_z) data->max_z = 0.0;
    }

    fclose(fp);

    if (data->n <= 0) {
        free(data->frames);
        data->frames = NULL;
        return 0;
    }

    read_report(path, data);

    return 1;
}

static double data_span(void)
{
    double sx = g_data.max_x - g_data.min_x;
    double sy = g_data.max_y - g_data.min_y;
    double sz = g_data.max_z - g_data.min_z;
    double span = sx;
    if (sy > span) span = sy;
    if (sz > span) span = sz;
    if (4.0 * g_data.r > span) span = 4.0 * g_data.r;
    if (span <= 0.0) span = 1.0;
    return span;
}

static void reset_camera(void)
{
    double span = data_span();
    g_target_x = 0.5 * (g_data.min_x + g_data.max_x);
    g_target_y = 0.5 * (g_data.min_y + g_data.max_y);
    g_target_z = 0.5 * (g_data.min_z + g_data.max_z);
    g_pan_x = 0.0;
    g_pan_y = 0.0;
    g_pan_z = 0.0;
    g_yaw = -55.0;
    g_pitch = 24.0;
    g_distance = 2.9 * span;
}

static int frame_for_time(double t)
{
    int lo = 0;
    int hi = g_data.n - 1;

    if (t <= g_data.frames[0].t) return 0;
    if (t >= g_data.frames[hi].t) return hi;

    while (hi - lo > 1) {
        int mid = lo + (hi - lo) / 2;
        if (g_data.frames[mid].t <= t) {
            lo = mid;
        } else {
            hi = mid;
        }
    }

    return lo;
}

static Frame sample_frame(double t, int *base_index)
{
    int i = frame_for_time(t);
    Frame out = g_data.frames[i];

    if (base_index) {
        *base_index = i;
    }
    if (i >= g_data.n - 1) {
        return out;
    }
    if (g_data.frames[i + 1].t > g_data.frames[i].t) {
        double u = (t - g_data.frames[i].t)/(g_data.frames[i + 1].t - g_data.frames[i].t);
        Frame *a = &g_data.frames[i];
        Frame *b = &g_data.frames[i + 1];

        if (u < 0.0) u = 0.0;
        if (u > 1.0) u = 1.0;
        out.t     = a->t     + u*(b->t     - a->t);
        out.psi   = a->psi   + u*(b->psi   - a->psi);
        out.theta = a->theta + u*(b->theta - a->theta);
        out.phi   = a->phi   + u*(b->phi   - a->phi);
        out.xc    = a->xc    + u*(b->xc    - a->xc);
        out.yc    = a->yc    + u*(b->yc    - a->yc);
        out.zc    = a->zc    + u*(b->zc    - a->zc);
        out.xp    = a->xp    + u*(b->xp    - a->xp);
        out.yp    = a->yp    + u*(b->yp    - a->yp);
        quat_slerp(a->q, b->q, u, out.q);
    }

    return out;
}

static void set_material(double r, double g, double b, double shininess)
{
    GLfloat ambient[4] = {(GLfloat)(0.25 * r), (GLfloat)(0.25 * g), (GLfloat)(0.25 * b), 1.0f};
    GLfloat diffuse[4] = {(GLfloat)r, (GLfloat)g, (GLfloat)b, 1.0f};
    GLfloat specular[4] = {0.34f, 0.28f, 0.20f, 1.0f};
    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT, ambient);
    glMaterialfv(GL_FRONT_AND_BACK, GL_DIFFUSE, diffuse);
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, specular);
    glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, (GLfloat)shininess);
}

static void draw_disk_mesh(double r, double h, double rho)
{
    const int slices = 256;
    const int rings = 32;
    int i, j;
    double h2 = 0.5 * h;
    double rr = rho;

    if (rr < 0.0) rr = 0.0;
    if (rr > h2) rr = h2;
    if (rr > 0.45 * r) rr = 0.45 * r;

    set_material(0.78, 0.43, 0.18, 52.0);

    if (rr <= 1.0e-9 || h <= 2.0 * rr) {
        glBegin(GL_QUAD_STRIP);
        for (i = 0; i <= slices; i++) {
            double a = 2.0 * M_PI * (double)i / (double)slices;
            double ca = cos(a);
            double sa = sin(a);
            glNormal3d(ca, sa, 0.0);
            glVertex3d(r * ca, r * sa, -h2);
            glVertex3d(r * ca, r * sa, h2);
        }
        glEnd();
    } else {
        double r1 = r - rr;
        double zside = h2 - rr;

        glBegin(GL_QUAD_STRIP);
        for (i = 0; i <= slices; i++) {
            double a = 2.0 * M_PI * (double)i / (double)slices;
            double ca = cos(a);
            double sa = sin(a);
            glNormal3d(ca, sa, 0.0);
            glVertex3d(r * ca, r * sa, -zside);
            glVertex3d(r * ca, r * sa, zside);
        }
        glEnd();

        for (j = 0; j < rings; j++) {
            double s0 = 0.5 * M_PI * (double)j / (double)rings;
            double s1 = 0.5 * M_PI * (double)(j + 1) / (double)rings;

            glBegin(GL_QUAD_STRIP);
            for (i = 0; i <= slices; i++) {
                double a = 2.0 * M_PI * (double)i / (double)slices;
                double ca = cos(a);
                double sa = sin(a);
                double cr0 = cos(s0);
                double sr0 = sin(s0);
                double cr1 = cos(s1);
                double sr1 = sin(s1);

                glNormal3d(cr0 * ca, cr0 * sa, sr0);
                glVertex3d((r1 + rr * cr0) * ca, (r1 + rr * cr0) * sa, zside + rr * sr0);

                glNormal3d(cr1 * ca, cr1 * sa, sr1);
                glVertex3d((r1 + rr * cr1) * ca, (r1 + rr * cr1) * sa, zside + rr * sr1);
            }
            glEnd();

            glBegin(GL_QUAD_STRIP);
            for (i = 0; i <= slices; i++) {
                double a = 2.0 * M_PI * (double)i / (double)slices;
                double ca = cos(a);
                double sa = sin(a);
                double cr0 = cos(s0);
                double sr0 = sin(s0);
                double cr1 = cos(s1);
                double sr1 = sin(s1);

                glNormal3d(cr1 * ca, cr1 * sa, -sr1);
                glVertex3d((r1 + rr * cr1) * ca, (r1 + rr * cr1) * sa, -zside - rr * sr1);

                glNormal3d(cr0 * ca, cr0 * sa, -sr0);
                glVertex3d((r1 + rr * cr0) * ca, (r1 + rr * cr0) * sa, -zside - rr * sr0);
            }
            glEnd();
        }
    }

    {
        double face_r = r - rr;
        if (face_r < 0.0) face_r = r;

        glNormal3d(0.0, 0.0, 1.0);
        glBegin(GL_TRIANGLE_FAN);
        glVertex3d(0.0, 0.0, h2);
        for (i = 0; i <= slices; i++) {
            double a = 2.0 * M_PI * (double)i / (double)slices;
            glVertex3d(face_r * cos(a), face_r * sin(a), h2);
        }
        glEnd();

        glNormal3d(0.0, 0.0, -1.0);
        glBegin(GL_TRIANGLE_FAN);
        glVertex3d(0.0, 0.0, -h2);
        for (i = slices; i >= 0; i--) {
            double a = 2.0 * M_PI * (double)i / (double)slices;
            glVertex3d(face_r * cos(a), face_r * sin(a), -h2);
        }
        glEnd();
    }
}

static void draw_axes(double size)
{
    glDisable(GL_LIGHTING);
    glLineWidth(2.0f);
    glBegin(GL_LINES);
    glColor3f(0.80f, 0.15f, 0.10f);
    glVertex3d(0.0, 0.0, 0.0);
    glVertex3d(size, 0.0, 0.0);
    glColor3f(0.10f, 0.55f, 0.18f);
    glVertex3d(0.0, 0.0, 0.0);
    glVertex3d(0.0, size, 0.0);
    glColor3f(0.16f, 0.32f, 0.86f);
    glVertex3d(0.0, 0.0, 0.0);
    glVertex3d(0.0, 0.0, size);
    glEnd();
    glLineWidth(1.0f);
    glEnable(GL_LIGHTING);
}

static void draw_grid(void)
{
    double span = data_span();
    double cx = 0.5 * (g_data.min_x + g_data.max_x);
    double cy = 0.5 * (g_data.min_y + g_data.max_y);
    double extent = 0.65 * span + 2.0 * g_data.r;
    int lines = 18;
    int i;

    glDisable(GL_LIGHTING);
    glColor4f(0.48f, 0.58f, 0.66f, 0.55f);
    glLineWidth(1.0f);
    glBegin(GL_LINES);
    for (i = -lines; i <= lines; i++) {
        double v = extent * (double)i / (double)lines;
        glVertex3d(cx - extent, cy + v, 0.0);
        glVertex3d(cx + extent, cy + v, 0.0);
        glVertex3d(cx + v, cy - extent, 0.0);
        glVertex3d(cx + v, cy + extent, 0.0);
    }
    glEnd();
    glEnable(GL_LIGHTING);
}

static void draw_path(void)
{
    int i;
    int stride = g_frame / 120000 + 1;
    int in_strip = 0;
    double z = -0.015 * g_data.r;

    glDisable(GL_LIGHTING);
    glColor3f(0.05f, 0.45f, 0.28f);
    glLineWidth(2.0f);
    for (i = 0; i <= g_frame; i += stride) {
        if (!contact_point_reliable(&g_data.frames[i])) {
            if (in_strip) {
                glEnd();
                in_strip = 0;
            }
            continue;
        }
        if (!in_strip) {
            glBegin(GL_LINE_STRIP);
            in_strip = 1;
        }
        glVertex3d(g_data.frames[i].xp, g_data.frames[i].yp, z);
    }
    if (in_strip) {
        glEnd();
    }
    glLineWidth(1.0f);
    glEnable(GL_LIGHTING);
}

static void draw_face_arrow(double z, double radius, double angle, float red, float green, float blue)
{
    double ca = cos(angle);
    double sa = sin(angle);
    double px = -sa;
    double py = ca;
    double start = 0.16 * radius;
    double end = 0.78 * radius;
    double head = 0.17 * radius;
    double half_width = 0.07 * radius;

    glColor3f(red, green, blue);
    glLineWidth(4.0f);
    glBegin(GL_LINES);
    glVertex3d(start * ca, start * sa, z);
    glVertex3d(end * ca, end * sa, z);
    glEnd();

    glBegin(GL_TRIANGLES);
    glVertex3d(end * ca, end * sa, z);
    glVertex3d((end - head) * ca + half_width * px, (end - head) * sa + half_width * py, z);
    glVertex3d((end - head) * ca - half_width * px, (end - head) * sa - half_width * py, z);
    glEnd();
    glLineWidth(1.0f);
}

static void draw_disk_arrows(void)
{
    double eps = 0.012 * g_data.r;
    double top = 0.5 * g_data.h + eps;
    double bottom = -0.5 * g_data.h - eps;

    glDisable(GL_LIGHTING);
    glDepthMask(GL_FALSE);

    draw_face_arrow(top, g_data.r, 0.0, 0.05f, 0.16f, 0.82f);
    draw_face_arrow(top, g_data.r, 0.5 * M_PI, 0.82f, 0.10f, 0.08f);

    draw_face_arrow(bottom, g_data.r, 0.0, 0.05f, 0.16f, 0.82f);
    draw_face_arrow(bottom, g_data.r, 0.5 * M_PI, 0.82f, 0.10f, 0.08f);

    glDepthMask(GL_TRUE);
    glEnable(GL_LIGHTING);
}

static void draw_arrow_geometry(double x, double y, double z,
                                const double dir[3],
                                double length,
                                double head_length,
                                double head_width)
{
    double tip[3];
    double base[3];
    double ref[3] = {0.0, 0.0, 1.0};
    double side[3];
    double side2[3];
    double side_len;
    double side2_len;

    if (fabs(dir[2]) > 0.88) {
        ref[0] = 0.0;
        ref[1] = 1.0;
        ref[2] = 0.0;
    }

    side[0] = dir[1]*ref[2] - dir[2]*ref[1];
    side[1] = dir[2]*ref[0] - dir[0]*ref[2];
    side[2] = dir[0]*ref[1] - dir[1]*ref[0];
    side_len = sqrt(side[0]*side[0] + side[1]*side[1] + side[2]*side[2]);
    if (side_len <= 1.0e-12) {
        return;
    }
    side[0] /= side_len;
    side[1] /= side_len;
    side[2] /= side_len;

    side2[0] = dir[1]*side[2] - dir[2]*side[1];
    side2[1] = dir[2]*side[0] - dir[0]*side[2];
    side2[2] = dir[0]*side[1] - dir[1]*side[0];
    side2_len = sqrt(side2[0]*side2[0] + side2[1]*side2[1] + side2[2]*side2[2]);
    if (side2_len <= 1.0e-12) {
        return;
    }
    side2[0] /= side2_len;
    side2[1] /= side2_len;
    side2[2] /= side2_len;

    tip[0] = x + length*dir[0];
    tip[1] = y + length*dir[1];
    tip[2] = z + length*dir[2];

    base[0] = tip[0] - head_length*dir[0];
    base[1] = tip[1] - head_length*dir[1];
    base[2] = tip[2] - head_length*dir[2];

    glBegin(GL_LINES);
    glVertex3d(x, y, z);
    glVertex3d(tip[0], tip[1], tip[2]);
    glEnd();

    glBegin(GL_TRIANGLES);
    glVertex3d(tip[0], tip[1], tip[2]);
    glVertex3d(base[0] + head_width*side[0], base[1] + head_width*side[1], base[2] + head_width*side[2]);
    glVertex3d(base[0] - head_width*side[0], base[1] - head_width*side[1], base[2] - head_width*side[2]);

    glVertex3d(tip[0], tip[1], tip[2]);
    glVertex3d(base[0] + head_width*side2[0], base[1] + head_width*side2[1], base[2] + head_width*side2[2]);
    glVertex3d(base[0] - head_width*side2[0], base[1] - head_width*side2[1], base[2] - head_width*side2[2]);
    glEnd();
}

static void draw_strike_direction_arrow(const Frame *f,
                                        double x,
                                        double y,
                                        double z,
                                        double direction,
                                        float red,
                                        float green,
                                        float blue)
{
    double world_dir[3] = {cos(direction), sin(direction), 0.0};
    double local_dir[3];
    double dir_len;
    double length = 0.70 * g_data.r;
    double head_length = 0.18 * g_data.r;
    double head_width = 0.075 * g_data.r;

    quat_inverse_rotate_vec(f->q, world_dir, local_dir);
    dir_len = sqrt(local_dir[0]*local_dir[0] + local_dir[1]*local_dir[1] + local_dir[2]*local_dir[2]);
    if (dir_len <= 1.0e-12) {
        return;
    }
    local_dir[0] /= dir_len;
    local_dir[1] /= dir_len;
    local_dir[2] /= dir_len;

    glColor3f(0.03f, 0.03f, 0.03f);
    glLineWidth(7.0f);
    draw_arrow_geometry(x, y, z, local_dir, length, head_length, 1.45 * head_width);

    glColor3f(red, green, blue);
    glLineWidth(4.0f);
    draw_arrow_geometry(x, y, z, local_dir, length, head_length, head_width);
}

static void draw_strike_marker(const Frame *f)
{
    double x;
    double y;
    double z;
    int i;

    if (!(g_data.strike_mode && g_data.strike_point_count > 0 && g_frame == 0)) {
        return;
    }

    glDisable(GL_LIGHTING);
    glDisable(GL_DEPTH_TEST);

    for (i = 0; i < g_data.strike_point_count && i < 2; i++) {
        x = g_data.strike_point[i][0];
        y = g_data.strike_point[i][2];
        z = -g_data.strike_point[i][1];

        if (g_data.strike_direction_known[i]) {
            if (i == 0) {
                draw_strike_direction_arrow(f, x, y, z, g_data.strike_direction[i],
                                            1.0f, 0.54f, 0.05f);
            } else {
                draw_strike_direction_arrow(f, x, y, z, g_data.strike_direction[i],
                                            0.02f, 0.62f, 1.0f);
            }
        }

        glPointSize(14.0f);
        glBegin(GL_POINTS);
        glColor3f(0.04f, 0.04f, 0.04f);
        glVertex3d(x, y, z);
        glEnd();

        glPointSize(8.0f);
        glBegin(GL_POINTS);
        if (i == 0) {
            glColor3f(0.98f, 0.72f, 0.12f);
        } else {
            glColor3f(0.10f, 0.78f, 0.92f);
        }
        glVertex3d(x, y, z);
        glEnd();
    }

    glPointSize(1.0f);
    glLineWidth(1.0f);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_LIGHTING);
}

static void draw_current_disk(const Frame *f)
{
    double contact_z = -0.015 * g_data.r;

    glPushMatrix();
    glTranslated(f->xc, f->yc, f->zc);
    apply_quat_rotation(f->q);
    draw_disk_mesh(g_data.r, g_data.h, g_data.rho);
    draw_disk_arrows();
    draw_strike_marker(f);

    glPopMatrix();

    glDisable(GL_LIGHTING);
    glPointSize(6.0f);
    glBegin(GL_POINTS);
    if (contact_point_reliable(f)) {
        glColor3f(0.82f, 0.10f, 0.10f);
        glVertex3d(f->xp, f->yp, contact_z);
    }
    glColor3f(0.05f, 0.05f, 0.05f);
    glVertex3d(f->xc, f->yc, f->zc);
    glEnd();
    glPointSize(1.0f);
    glEnable(GL_LIGHTING);
}

static void draw_text_2d(int x, int y, const char *text)
{
    const char *p;
    glRasterPos2i(x, y);
    for (p = text; *p; p++) {
        glutBitmapCharacter(GLUT_BITMAP_8_BY_13, *p);
    }
}

static void draw_overlay(const Frame *f)
{
    char line[256];

    if (!g_show_time) return;

    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    gluOrtho2D(0.0, (double)g_width, 0.0, (double)g_height);

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();

    glDisable(GL_LIGHTING);
    glDisable(GL_DEPTH_TEST);
    glColor3f(0.05f, 0.07f, 0.09f);

    snprintf(line, sizeof(line), "t = %.3f s   frame %d/%d   speed %.2fx",
             f->t, g_frame + 1, g_data.n, g_speed);
    draw_text_2d(12, g_height - 24, line);
    draw_text_2d(12, 16, "space play/pause   drag orbit   wheel zoom   +/- speed   g grid   p path   r restart   esc quit");

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_LIGHTING);

    glPopMatrix();
    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
}

static void apply_camera(void)
{
    double yaw = g_yaw * M_PI / 180.0;
    double pitch = g_pitch * M_PI / 180.0;
    double cp = cos(pitch);
    double eye_x = g_target_x + g_pan_x + g_distance * cp * cos(yaw);
    double eye_y = g_target_y + g_pan_y + g_distance * cp * sin(yaw);
    double eye_z = g_target_z + g_pan_z + g_distance * sin(pitch);

    gluLookAt(eye_x, eye_y, eye_z,
              g_target_x + g_pan_x, g_target_y + g_pan_y, g_target_z + g_pan_z,
              0.0, 0.0, 1.0);
}

static void display(void)
{
    GLfloat light_pos[4] = {0.5f, -1.0f, 1.6f, 0.0f};
    GLfloat white[4] = {0.95f, 0.93f, 0.88f, 1.0f};
    GLfloat ambient[4] = {0.28f, 0.30f, 0.33f, 1.0f};
    Frame current = sample_frame(g_time, &g_frame);

    glViewport(0, 0, g_width, g_height);
    glClearColor(0.92f, 0.95f, 0.97f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(42.0, (double)g_width / (double)(g_height > 0 ? g_height : 1), 0.0005, 100.0);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    apply_camera();

    glEnable(GL_DEPTH_TEST);
    glEnable(GL_NORMALIZE);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glLightfv(GL_LIGHT0, GL_POSITION, light_pos);
    glLightfv(GL_LIGHT0, GL_DIFFUSE, white);
    glLightfv(GL_LIGHT0, GL_SPECULAR, white);
    glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient);
    glShadeModel(GL_SMOOTH);
    glDisable(GL_CULL_FACE);

    if (g_show_grid) draw_grid();
    if (g_show_path) draw_path();
    draw_axes(2.2 * g_data.r);
    draw_current_disk(&current);
    draw_overlay(&current);

    glutSwapBuffers();
}

static void reshape(int width, int height)
{
    g_width = width > 1 ? width : 1;
    g_height = height > 1 ? height : 1;
    glutPostRedisplay();
}

static void idle(void)
{
    int now = glutGet(GLUT_ELAPSED_TIME);
    int elapsed = now - g_last_ms;

    if (g_last_ms == 0) {
        elapsed = 0;
    }
    g_last_ms = now;

    if (g_playing && elapsed > 0) {
        g_time += ((double)elapsed / 1000.0) * g_speed;
        if (g_time >= g_data.frames[g_data.n - 1].t) {
            g_time = g_data.frames[g_data.n - 1].t;
            g_playing = 0;
        }
        g_frame = frame_for_time(g_time);
        glutPostRedisplay();
    }
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
    case ' ':
        g_playing = !g_playing;
        break;
    case 'r':
    case 'R':
        g_frame = 0;
        g_time = g_data.frames[0].t;
        g_playing = 0;
        break;
    case '+':
    case '=':
        g_speed *= 1.5;
        if (g_speed > 250.0) g_speed = 250.0;
        break;
    case '-':
    case '_':
        g_speed /= 1.5;
        if (g_speed < 0.02) g_speed = 0.02;
        break;
    case 'g':
    case 'G':
        g_show_grid = !g_show_grid;
        break;
    case 'p':
    case 'P':
        g_show_path = !g_show_path;
        break;
    case 't':
    case 'T':
        g_show_time = !g_show_time;
        break;
    case '1':
        g_speed = 1.0;
        break;
    case '2':
        g_speed = 2.0;
        break;
    case '5':
        g_speed = 5.0;
        break;
    case '0':
        g_speed = 10.0;
        break;
    default:
        break;
    }

    glutPostRedisplay();
}

static void special(int key, int x, int y)
{
    double step = 0.018 * data_span();
    (void)x;
    (void)y;

    switch (key) {
    case GLUT_KEY_LEFT:
        if (g_frame > 0) g_frame--;
        break;
    case GLUT_KEY_RIGHT:
        if (g_frame < g_data.n - 1) g_frame++;
        break;
    case GLUT_KEY_UP:
        g_pan_y += step;
        break;
    case GLUT_KEY_DOWN:
        g_pan_y -= step;
        break;
    default:
        break;
    }

    g_time = g_data.frames[g_frame].t;
    g_playing = 0;
    glutPostRedisplay();
}

static void mouse(int button, int state, int x, int y)
{
    if (button == 3 && state == GLUT_DOWN) {
        g_distance *= 0.88;
        if (g_distance < 0.04 * data_span()) g_distance = 0.04 * data_span();
        glutPostRedisplay();
        return;
    }
    if (button == 4 && state == GLUT_DOWN) {
        g_distance *= 1.13;
        glutPostRedisplay();
        return;
    }

    if (state == GLUT_DOWN) {
        g_mouse_button = button;
        g_mouse_x = x;
        g_mouse_y = y;
    } else {
        g_mouse_button = -1;
    }
}

static void motion(int x, int y)
{
    int dx = x - g_mouse_x;
    int dy = y - g_mouse_y;

    if (g_mouse_button == GLUT_LEFT_BUTTON) {
        g_yaw -= 0.35 * dx;
        g_pitch += 0.35 * dy;
        if (g_pitch > 89.0) g_pitch = 89.0;
        if (g_pitch < -89.0) g_pitch = -89.0;
    } else if (g_mouse_button == GLUT_MIDDLE_BUTTON || g_mouse_button == GLUT_RIGHT_BUTTON) {
        double s = 0.0018 * g_distance;
        double yaw = g_yaw * M_PI / 180.0;
        double pitch = g_pitch * M_PI / 180.0;
        double right_x = -sin(yaw);
        double right_y = cos(yaw);
        double up_x = -sin(pitch) * cos(yaw);
        double up_y = -sin(pitch) * sin(yaw);
        double up_z = cos(pitch);

        g_pan_x -= dx * s * right_x;
        g_pan_y -= dx * s * right_y;
        g_pan_x += dy * s * up_x;
        g_pan_y += dy * s * up_y;
        g_pan_z += dy * s * up_z;
    }

    g_mouse_x = x;
    g_mouse_y = y;
    glutPostRedisplay();
}

static void print_info(const char *path)
{
    printf("file: %s\n", path);
    printf("radius: %.10g m\n", g_data.r);
    printf("height: %.10g m\n", g_data.h);
    printf("fillet: %.10g m\n", g_data.rho);
    printf("frames: %d\n", g_data.n);
    printf("time: %.6g to %.6g s\n", g_data.frames[0].t, g_data.frames[g_data.n - 1].t);
    printf("bounds x: %.6g to %.6g\n", g_data.min_x, g_data.max_x);
    printf("bounds y: %.6g to %.6g\n", g_data.min_y, g_data.max_y);
    printf("bounds z: %.6g to %.6g\n", g_data.min_z, g_data.max_z);
}

int main(int argc, char **argv)
{
    const char *path = "animat.txt";
    int info_only = 0;
    int argi = 1;

    if (argc > 1 && strcmp(argv[1], "--info") == 0) {
        info_only = 1;
        argi = 2;
    }
    if (argc > argi) {
        path = argv[argi];
    }

    if (!read_data(path, &g_data)) {
        die("Failed to read animation data.");
    }

    g_time = g_data.frames[0].t;
    if (g_data.strike_mode && g_data.strike_point_count > 0) {
        g_playing = 0;
    }
    reset_camera();

    if (info_only) {
        print_info(path);
        free(g_data.frames);
        return 0;
    }

    glutInit(&argc, argv);
    glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGBA | GLUT_DEPTH | GLUT_MULTISAMPLE);
    glutInitWindowSize(g_width, g_height);
    glutInitWindowPosition(120, 80);
    glutCreateWindow("Euler Disk OpenGL Viewer");
#ifdef GLUT_ACTION_ON_WINDOW_CLOSE
    glutSetOption(GLUT_ACTION_ON_WINDOW_CLOSE, GLUT_ACTION_GLUTMAINLOOP_RETURNS);
#endif

#ifdef GL_MULTISAMPLE
    glEnable(GL_MULTISAMPLE);
#endif

    glutDisplayFunc(display);
    glutReshapeFunc(reshape);
    glutIdleFunc(idle);
    glutKeyboardFunc(keyboard);
    glutSpecialFunc(special);
    glutMouseFunc(mouse);
    glutMotionFunc(motion);

    g_last_ms = glutGet(GLUT_ELAPSED_TIME);
    glutMainLoop();

    free(g_data.frames);
    return 0;
}
