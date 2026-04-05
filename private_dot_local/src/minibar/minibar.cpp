#include <fcntl.h>
#include <poll.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/mman.h>
#include <unistd.h>
#include <cerrno>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <vector>

#include <wayland-client.h>
#define namespace namespace_
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#undef namespace

#include <cairo/cairo.h>
#include <pango/pangocairo.h>

struct Buffer {
    wl_buffer* wl = nullptr;
    void* data = nullptr;
    int fd = -1;
    int w = 0, h = 0, stride = 0, size = 0;
};

struct App {
    wl_display* display = nullptr;
    wl_registry* registry = nullptr;
    wl_compositor* compositor = nullptr;
    wl_shm* shm = nullptr;
    wl_output* output = nullptr;
    zwlr_layer_shell_v1* layer_shell = nullptr;

    wl_surface* surface = nullptr;
    zwlr_layer_surface_v1* layer_surface = nullptr;

    Buffer buf{};
    int width = 0;
    int height = 20;
    int output_scale = 1;
    int buffer_scale = 1;
    bool configured = false;
    bool running = true;
    bool redraw = true;
    bool visible = true;

    int hypr_fd = -1;
    std::string hypr_buf;

    std::string left = "[1] 2 3 4";
    std::string center = "minibar";
    std::string right = "--:--";
};

static int create_shm_file(size_t size) {
#ifdef MFD_CLOEXEC
    {
        int fd = memfd_create("minibar", MFD_CLOEXEC);
        if (fd >= 0) {
            if (ftruncate(fd, (off_t)size) == 0) return fd;
            close(fd);
        }
    }
#endif
    char name[] = "/minibar-XXXXXX";
    int fd = mkstemp(name);
    if (fd < 0) return -1;
    unlink(name);
    if (ftruncate(fd, (off_t)size) < 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static void destroy_buffer(Buffer& b) {
    if (b.wl) wl_buffer_destroy(b.wl);
    if (b.data) munmap(b.data, b.size);
    if (b.fd >= 0) close(b.fd);
    b = {};
}

static bool make_buffer(App& a, int w, int h) {
    destroy_buffer(a.buf);
    a.buf.w = w;
    a.buf.h = h;
    a.buf.stride = w * 4;
    a.buf.size = a.buf.stride * h;
    a.buf.fd = create_shm_file(a.buf.size);
    if (a.buf.fd < 0) return false;

    a.buf.data = mmap(nullptr, a.buf.size, PROT_READ | PROT_WRITE, MAP_SHARED, a.buf.fd, 0);
    if (a.buf.data == MAP_FAILED) {
        a.buf.data = nullptr;
        destroy_buffer(a.buf);
        return false;
    }

    wl_shm_pool* pool = wl_shm_create_pool(a.shm, a.buf.fd, a.buf.size);
    a.buf.wl = wl_shm_pool_create_buffer(pool, 0, w, h, a.buf.stride, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    return a.buf.wl != nullptr;
}

static void draw_text(cairo_t* cr, const std::string& text, int x, int bar_h, int scale) {
    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_text(layout, text.c_str(), -1);

    std::string font_str = "Noto Sans Mono " + std::to_string(10 * scale);
    PangoFontDescription* font = pango_font_description_from_string(font_str.c_str());
    pango_layout_set_font_description(layout, font);

    int th = 0;
    pango_layout_get_pixel_size(layout, nullptr, &th);

    cairo_move_to(cr, x * scale, ((bar_h * scale) - th) / 2);
    pango_cairo_show_layout(cr, layout);

    pango_font_description_free(font);
    g_object_unref(layout);
}

static int text_width(cairo_t* cr, const std::string& text, int scale) {
    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_text(layout, text.c_str(), -1);
    std::string font_str = "Noto Sans Mono " + std::to_string(10 * scale);
    PangoFontDescription* font = pango_font_description_from_string(font_str.c_str());
    pango_layout_set_font_description(layout, font);
    int tw = 0;
    pango_layout_get_pixel_size(layout, &tw, nullptr);
    pango_font_description_free(font);
    g_object_unref(layout);
    return (tw + scale - 1) / scale;
}

static int choose_buffer_scale(const App& a) {
    if (const char* env = std::getenv("MINIBAR_BUFFER_SCALE")) {
        int s = std::atoi(env);
        if (s > 0) return s;
    }
    return a.output_scale > 1 ? a.output_scale : 2;
}

static void sync_buffer_scale(App& a) {
    int s = choose_buffer_scale(a);
    if (s != a.buffer_scale) {
        a.buffer_scale = s;
        if (a.surface) wl_surface_set_buffer_scale(a.surface, a.buffer_scale);
        a.redraw = true;
    }
}

static void set_bar_visible(App& a, bool visible) {
    if (!a.layer_surface || !a.surface || visible == a.visible) return;

    a.visible = visible;

    zwlr_layer_surface_v1_set_exclusive_zone(a.layer_surface, visible ? a.height : 0);

    if (visible) {
        wl_surface_set_input_region(a.surface, nullptr);
        a.configured = false;
        a.redraw = false;
    } else {
        wl_region* empty = wl_compositor_create_region(a.compositor);
        wl_surface_set_input_region(a.surface, empty);
        wl_region_destroy(empty);

        wl_surface_attach(a.surface, nullptr, 0, 0);
        wl_surface_damage_buffer(a.surface, 0, 0, INT32_MAX, INT32_MAX);
        a.configured = false;
        a.redraw = false;
    }

    wl_surface_commit(a.surface);
}

static int connect_hypr_socket2() {
    const char* runtime = std::getenv("XDG_RUNTIME_DIR");
    const char* sig = std::getenv("HYPRLAND_INSTANCE_SIGNATURE");
    if (!runtime || !sig || !*runtime || !*sig) return -1;

    std::string path = std::string(runtime) + "/hypr/" + sig + "/.socket2.sock";

    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0) return -1;

    sockaddr_un addr{};
    if (path.size() >= sizeof(addr.sun_path)) {
        close(fd);
        return -1;
    }
    addr.sun_family = AF_UNIX;
    std::memcpy(addr.sun_path, path.c_str(), path.size() + 1);

    if (connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        close(fd);
        return -1;
    }

    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0) fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    return fd;
}

static void handle_hypr_event(App& a, const std::string& line) {
    constexpr const char* prefix = "fullscreen>>";
    if (line.rfind(prefix, 0) != 0) return;

    bool fullscreen = line.size() > std::strlen(prefix) && line[std::strlen(prefix)] != '0';
    set_bar_visible(a, !fullscreen);
}

static void handle_hypr_readable(App& a) {
    if (a.hypr_fd < 0) return;

    char buf[1024];
    while (true) {
        ssize_t n = recv(a.hypr_fd, buf, sizeof(buf), 0);
        if (n > 0) {
            a.hypr_buf.append(buf, (size_t)n);
            size_t pos = 0;
            while (true) {
                size_t nl = a.hypr_buf.find('\n', pos);
                if (nl == std::string::npos) {
                    a.hypr_buf.erase(0, pos);
                    break;
                }
                handle_hypr_event(a, a.hypr_buf.substr(pos, nl - pos));
                pos = nl + 1;
            }
            continue;
        }

        if (n == 0) {
            close(a.hypr_fd);
            a.hypr_fd = -1;
            a.hypr_buf.clear();
            return;
        }

        if (errno == EAGAIN || errno == EWOULDBLOCK) return;

        close(a.hypr_fd);
        a.hypr_fd = -1;
        a.hypr_buf.clear();
        return;
    }
}

static void draw(App& a) {
    if (!a.configured || a.width <= 0 || !a.visible) return;
    int bw = a.width * a.buffer_scale;
    int bh = a.height * a.buffer_scale;
    if (!a.buf.wl || a.buf.w != bw || a.buf.h != bh) {
        if (!make_buffer(a, bw, bh)) {
            std::cerr << "failed to create shm buffer\n";
            a.running = false;
            return;
        }
    }

    cairo_surface_t* s = cairo_image_surface_create_for_data(
        static_cast<unsigned char*>(a.buf.data),
        CAIRO_FORMAT_ARGB32, a.buf.w, a.buf.h, a.buf.stride);
    cairo_t* cr = cairo_create(s);

    cairo_set_source_rgb(cr, 0.08, 0.08, 0.08);
    cairo_paint(cr);

    cairo_set_source_rgb(cr, 0.85, 0.85, 0.85);

    const int pad = 8;

    int cw = text_width(cr, a.center, a.buffer_scale);
    int rw = text_width(cr, a.right, a.buffer_scale);

    int lx = pad;
    int cx = (a.width - cw) / 2;
    int rx = a.width - rw - pad;

    draw_text(cr, a.left, lx, a.height, a.buffer_scale);
    draw_text(cr, a.center, cx, a.height, a.buffer_scale);
    draw_text(cr, a.right, rx, a.height, a.buffer_scale);
    cairo_destroy(cr);
    cairo_surface_destroy(s);

    wl_surface_attach(a.surface, a.buf.wl, 0, 0);
    wl_surface_damage_buffer(a.surface, 0, 0, a.buf.w, a.buf.h);
    wl_surface_commit(a.surface);
    a.redraw = false;
}

static void layer_surface_configure(void* data, zwlr_layer_surface_v1*, uint32_t serial,
                                    uint32_t width, uint32_t height) {
    auto& a = *static_cast<App*>(data);
    zwlr_layer_surface_v1_ack_configure(a.layer_surface, serial);
    if (width > 0) a.width = (int)width;
    if (height > 0) a.height = (int)height;
    a.configured = true;
    a.redraw = true;
}

static void layer_surface_closed(void* data, zwlr_layer_surface_v1*) {
    static_cast<App*>(data)->running = false;
}

static const zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed = layer_surface_closed,
};

static void output_geometry(void*, wl_output*, int32_t, int32_t, int32_t, int32_t,
                            int32_t, const char*, const char*, int32_t) {}

static void output_mode(void*, wl_output*, uint32_t, int32_t, int32_t, int32_t) {}

static void output_done(void*, wl_output*) {}

static void output_scale(void* data, wl_output*, int32_t factor) {
    auto& a = *static_cast<App*>(data);
    a.output_scale = factor > 0 ? factor : 1;
    sync_buffer_scale(a);
}

static const wl_output_listener output_listener = {
    output_geometry,
    output_mode,
    output_done,
    output_scale,
    nullptr,
    nullptr,
};

static void registry_add(void* data, wl_registry* reg, uint32_t name,
                         const char* iface, uint32_t version) {
    auto& a = *static_cast<App*>(data);
    (void)version;

    if (strcmp(iface, wl_compositor_interface.name) == 0) {
        a.compositor = static_cast<wl_compositor*>(
            wl_registry_bind(reg, name, &wl_compositor_interface, 4));
    } else if (strcmp(iface, wl_shm_interface.name) == 0) {
        a.shm = static_cast<wl_shm*>(
            wl_registry_bind(reg, name, &wl_shm_interface, 1));
    } else if (strcmp(iface, wl_output_interface.name) == 0 && !a.output) {
        a.output = static_cast<wl_output*>(
            wl_registry_bind(reg, name, &wl_output_interface, 1));
        wl_output_add_listener(a.output, &output_listener, &a);
    } else if (strcmp(iface, zwlr_layer_shell_v1_interface.name) == 0) {
        a.layer_shell = static_cast<zwlr_layer_shell_v1*>(
            wl_registry_bind(reg, name, &zwlr_layer_shell_v1_interface, 1));
    }
}

static void registry_remove(void*, wl_registry*, uint32_t) {}

static const wl_registry_listener registry_listener = {
    .global = registry_add,
    .global_remove = registry_remove,
};

int main() {
    App a{};

    a.display = wl_display_connect(nullptr);
    if (!a.display) {
        std::cerr << "failed to connect to wayland\n";
        return 1;
    }

    a.registry = wl_display_get_registry(a.display);
    wl_registry_add_listener(a.registry, &registry_listener, &a);
    wl_display_roundtrip(a.display);

    if (!a.compositor || !a.shm || !a.layer_shell) {
        std::cerr << "missing required wayland globals\n";
        return 1;
    }

    a.surface = wl_compositor_create_surface(a.compositor);
    a.layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        a.layer_shell, a.surface, a.output,
        ZWLR_LAYER_SHELL_V1_LAYER_TOP, "minibar");
    a.hypr_fd = connect_hypr_socket2();
    sync_buffer_scale(a);

    zwlr_layer_surface_v1_add_listener(a.layer_surface, &layer_surface_listener, &a);
    zwlr_layer_surface_v1_set_anchor(
        a.layer_surface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_size(a.layer_surface, 0, a.height);
    zwlr_layer_surface_v1_set_exclusive_zone(a.layer_surface, a.height);
    zwlr_layer_surface_v1_set_margin(a.layer_surface, 0, 0, 0, 0);
    wl_surface_commit(a.surface);
    wl_display_roundtrip(a.display);

    int wl_fd = wl_display_get_fd(a.display);
    int stdin_fd = fileno(stdin);

    while (a.running) {
        if (a.redraw) draw(a);

        wl_display_flush(a.display);

        pollfd fds[3] = {
            { .fd = wl_fd, .events = POLLIN, .revents = 0 },
            { .fd = stdin_fd, .events = POLLIN, .revents = 0 },
            { .fd = a.hypr_fd, .events = POLLIN, .revents = 0 },
        };

        if (poll(fds, 3, -1) < 0) break;

        if (fds[0].revents & POLLIN) {
            if (wl_display_dispatch(a.display) < 0) break;
        } else {
            wl_display_dispatch_pending(a.display);
        }

        if (fds[1].revents & POLLIN) {
            std::string line;
            if (!std::getline(std::cin, line)) {
                a.running = false;
            } else {
                if (line.empty()) {
                    a.left = " ";
                    a.center.clear();
                    a.right.clear();
                } else {
                    size_t p1 = line.find('\x1f');
                    size_t p2 = (p1 == std::string::npos) ? std::string::npos : line.find('\x1f', p1 + 1);
                    bool split = p1 != std::string::npos && p2 != std::string::npos;
                    a.left = split ? line.substr(0, p1) : line;
                    a.center = split ? line.substr(p1 + 1, p2 - p1 - 1) : "";
                    a.right = split ? line.substr(p2 + 1) : "";
                }
                a.redraw = true;
            }
        }

        if (fds[2].revents & POLLIN) {
            handle_hypr_readable(a);
        } else if (fds[2].revents & (POLLHUP | POLLERR | POLLNVAL)) {
            close(a.hypr_fd);
            a.hypr_fd = -1;
            a.hypr_buf.clear();
        }
    }

    destroy_buffer(a.buf);
    if (a.layer_surface) zwlr_layer_surface_v1_destroy(a.layer_surface);
    if (a.surface) wl_surface_destroy(a.surface);
    if (a.output) wl_output_destroy(a.output);
    if (a.hypr_fd >= 0) close(a.hypr_fd);
    if (a.layer_shell) zwlr_layer_shell_v1_destroy(a.layer_shell);
    if (a.shm) wl_shm_destroy(a.shm);
    if (a.compositor) wl_compositor_destroy(a.compositor);
    if (a.registry) wl_registry_destroy(a.registry);
    if (a.display) wl_display_disconnect(a.display);
    return 0;
}
