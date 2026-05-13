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
#include <memory>
#include <string>
#include <vector>

#include <wayland-client.h>
#define namespace namespace_
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#undef namespace

#include <cairo/cairo.h>
#include <pango/pangocairo.h>

// Wayland shared-memory buffers are the bridge between our CPU-side drawing
// and the compositor. Cairo renders into `data`, and `wl` is the Wayland
// object attached to the surface for presentation.
struct Buffer {
    wl_buffer* wl = nullptr;
    void* data = nullptr;
    int fd = -1;
    int w = 0, h = 0, stride = 0, size = 0;
};

struct App;

// Each physical output needs its own layer-shell surface and backing buffer.
struct Bar {
    App* app = nullptr;
    wl_output* output = nullptr;
    wl_surface* surface = nullptr;
    zwlr_layer_surface_v1* layer_surface = nullptr;

    Buffer buf{};
    int width = 0;
    int height = 20;
    int output_scale = 1;
    int buffer_scale = 1;
    bool configured = false;
    bool redraw = true;
    bool visible = true;

    std::string output_name;
    std::string left = "[1] 2 3 4";
    std::string center = "minibar";
    std::string right = "--:--";
};

// `App` keeps all global Wayland objects and the shared text state in one
// place. Per-output rendering state lives in `bars`.
struct App {
    wl_display* display = nullptr;
    wl_registry* registry = nullptr;
    wl_compositor* compositor = nullptr;
    wl_shm* shm = nullptr;
    zwlr_layer_shell_v1* layer_shell = nullptr;

    std::vector<std::unique_ptr<Bar>> bars;

    bool running = true;

    int hypr_fd = -1;
    std::string hypr_buf;
};

constexpr char kSectionSeparator = '\x1f';

static int create_shm_file(size_t size) {
    // Wayland shm buffers need a file descriptor the compositor can also map.
    // `memfd_create` is the cleanest option when available; the mkstemp path is
    // a portable fallback.
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

static bool make_buffer(App& a, Bar& b, int w, int h) {
    // Recreate the backing store whenever the logical bar size or buffer scale
    // changes. The compositor sees the wl_buffer; Cairo sees the mmap'd memory.
    destroy_buffer(b.buf);
    b.buf.w = w;
    b.buf.h = h;
    b.buf.stride = w * 4;
    b.buf.size = b.buf.stride * h;
    b.buf.fd = create_shm_file(b.buf.size);
    if (b.buf.fd < 0) return false;

    b.buf.data = mmap(nullptr, b.buf.size, PROT_READ | PROT_WRITE, MAP_SHARED, b.buf.fd, 0);
    if (b.buf.data == MAP_FAILED) {
        b.buf.data = nullptr;
        destroy_buffer(b.buf);
        return false;
    }

    wl_shm_pool* pool = wl_shm_create_pool(a.shm, b.buf.fd, b.buf.size);
    b.buf.wl = wl_shm_pool_create_buffer(pool, 0, w, h, b.buf.stride, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    return b.buf.wl != nullptr;
}

static void draw_text(cairo_t* cr, const std::string& text, int x, int bar_h, int scale) {
    // Pango handles text shaping and markup, then Cairo paints the prepared
    // layout into the shared-memory image.
    PangoLayout* layout = pango_cairo_create_layout(cr);
    pango_layout_set_markup(layout, text.c_str(), -1);

    std::string font_str = "NotoSansM Nerd Font " + std::to_string(10 * scale);
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
    pango_layout_set_markup(layout, text.c_str(), -1);
    std::string font_str = "NotoSansM Nerd Font " + std::to_string(10 * scale);
    PangoFontDescription* font = pango_font_description_from_string(font_str.c_str());
    pango_layout_set_font_description(layout, font);
    int tw = 0;
    pango_layout_get_pixel_size(layout, &tw, nullptr);
    pango_font_description_free(font);
    g_object_unref(layout);
    return (tw + scale - 1) / scale;
}

static int choose_buffer_scale(const Bar& b) {
    // The compositor reports an output scale, but we allow an override because
    // tiny bars often look sharper if rendered into a denser buffer.
    if (const char* env = std::getenv("MINIBAR_BUFFER_SCALE")) {
        int s = std::atoi(env);
        if (s > 0) return s;
    }
    return b.output_scale > 1 ? b.output_scale : 2;
}

static void sync_buffer_scale(Bar& b) {
    int s = choose_buffer_scale(b);
    if (s != b.buffer_scale) {
        b.buffer_scale = s;
        if (b.surface) wl_surface_set_buffer_scale(b.surface, b.buffer_scale);
        b.redraw = true;
    }
}

static void set_bar_visible(App& a, Bar& b, bool visible) {
    if (!b.layer_surface || !b.surface || visible == b.visible) return;

    b.visible = visible;

    // The exclusive zone tells the compositor how much screen edge space this
    // layer surface wants to reserve. When hidden, we release that space.
    zwlr_layer_surface_v1_set_exclusive_zone(b.layer_surface, visible ? b.height : 0);

    if (visible) {
        // A null input region means the whole surface is interactive again.
        wl_surface_set_input_region(b.surface, nullptr);
        b.configured = false;
        b.redraw = false;
    } else {
        // An empty input region makes the hidden surface stop receiving input,
        // and detaching the buffer removes the already-drawn contents.
        wl_region* empty = wl_compositor_create_region(a.compositor);
        wl_surface_set_input_region(b.surface, empty);
        wl_region_destroy(empty);

        wl_surface_attach(b.surface, nullptr, 0, 0);
        wl_surface_damage_buffer(b.surface, 0, 0, INT32_MAX, INT32_MAX);
        b.configured = false;
        b.redraw = false;
    }

    wl_surface_commit(b.surface);
}

static int connect_hypr_socket2() {
    // Hyprland exposes a Unix socket with newline-delimited events. We only use
    // it for fullscreen notifications so the bar can get out of the way.
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
    constexpr char prefix[] = "fullscreen>>";
    constexpr size_t prefix_len = sizeof(prefix) - 1;
    if (line.rfind(prefix, 0) != 0) return;

    bool fullscreen = line.size() > prefix_len && line[prefix_len] != '0';
    for (auto& bar : a.bars) set_bar_visible(a, *bar, !fullscreen);
}

static void handle_hypr_readable(App& a) {
    if (a.hypr_fd < 0) return;

    // Read as much as is currently available, keep incomplete trailing data in
    // `hypr_buf`, and dispatch full newline-terminated events one by one.
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

static std::vector<std::string> split_fields(const std::string& line) {
    std::vector<std::string> fields;
    size_t start = 0;
    while (true) {
        size_t pos = line.find(kSectionSeparator, start);
        if (pos == std::string::npos) {
            fields.push_back(line.substr(start));
            return fields;
        }

        fields.push_back(line.substr(start, pos - start));
        start = pos + 1;
    }
}

static void set_bar_text(Bar& b, const std::string& left,
                         const std::string& center, const std::string& right) {
    b.left = left;
    b.center = center;
    b.right = right;
    b.redraw = true;
}

static void update_bar_text(App& a, const std::string& line) {
    std::vector<std::string> fields = split_fields(line);

    if (fields.size() == 3) {
        for (auto& bar : a.bars) set_bar_text(*bar, fields[0], fields[1], fields[2]);
        return;
    }

    if (fields.size() == 4) {
        for (auto& bar : a.bars) {
            if (bar->output_name == fields[0]) set_bar_text(*bar, fields[1], fields[2], fields[3]);
        }
    }
}

static void draw(App& a, Bar& b) {
    if (!b.configured || b.width <= 0 || !b.visible) return;

    // The layer surface size is in logical coordinates. The backing buffer may
    // be larger when rendering at scale > 1 for HiDPI output.
    int bw = b.width * b.buffer_scale;
    int bh = b.height * b.buffer_scale;
    if (!b.buf.wl || b.buf.w != bw || b.buf.h != bh) {
        if (!make_buffer(a, b, bw, bh)) {
            std::cerr << "failed to create shm buffer\n";
            a.running = false;
            return;
        }
    }

    cairo_surface_t* s = cairo_image_surface_create_for_data(
        static_cast<unsigned char*>(b.buf.data),
        CAIRO_FORMAT_ARGB32, b.buf.w, b.buf.h, b.buf.stride);
    cairo_t* cr = cairo_create(s);

    cairo_set_source_rgb(cr, 0.08, 0.08, 0.08);
    cairo_paint(cr);

    cairo_set_source_rgb(cr, 0.85, 0.85, 0.85);

    const int pad = 8;

    int cw = text_width(cr, b.center, b.buffer_scale);
    int rw = text_width(cr, b.right, b.buffer_scale);

    int lx = pad;
    int cx = (b.width - cw) / 2;
    int rx = b.width - rw - pad;

    draw_text(cr, b.left, lx, b.height, b.buffer_scale);
    draw_text(cr, b.center, cx, b.height, b.buffer_scale);
    draw_text(cr, b.right, rx, b.height, b.buffer_scale);
    cairo_destroy(cr);
    cairo_surface_destroy(s);

    wl_surface_attach(b.surface, b.buf.wl, 0, 0);
    wl_surface_damage_buffer(b.surface, 0, 0, b.buf.w, b.buf.h);
    wl_surface_commit(b.surface);
    b.redraw = false;
}

static void layer_surface_configure(void* data, zwlr_layer_surface_v1*, uint32_t serial,
                                    uint32_t width, uint32_t height) {
    auto& b = *static_cast<Bar*>(data);
    // Layer-shell surfaces are configured asynchronously. We cannot rely on the
    // requested size until the compositor sends this event and we ack it.
    zwlr_layer_surface_v1_ack_configure(b.layer_surface, serial);
    if (width > 0) b.width = (int)width;
    if (height > 0) b.height = (int)height;
    b.configured = true;
    b.redraw = true;
}

static void layer_surface_closed(void* data, zwlr_layer_surface_v1*) {
    auto& b = *static_cast<Bar*>(data);
    if (b.app) b.app->running = false;
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
    auto& b = *static_cast<Bar*>(data);
    b.output_scale = factor > 0 ? factor : 1;
    sync_buffer_scale(b);
}

static void output_name(void* data, wl_output*, const char* name) {
    auto& b = *static_cast<Bar*>(data);
    b.output_name = name ? name : "";
}

static void output_description(void*, wl_output*, const char*) {}

static const wl_output_listener output_listener = {
    output_geometry,
    output_mode,
    output_done,
    output_scale,
    output_name,
    output_description,
};

static void registry_add(void* data, wl_registry* reg, uint32_t name,
                         const char* iface, uint32_t version) {
    auto& a = *static_cast<App*>(data);

    // The Wayland registry is runtime discovery: the compositor tells us which
    // global interfaces exist, and we bind only the ones this program needs.
    if (strcmp(iface, wl_compositor_interface.name) == 0) {
        a.compositor = static_cast<wl_compositor*>(
            wl_registry_bind(reg, name, &wl_compositor_interface, 4));
    } else if (strcmp(iface, wl_shm_interface.name) == 0) {
        a.shm = static_cast<wl_shm*>(
            wl_registry_bind(reg, name, &wl_shm_interface, 1));
    } else if (strcmp(iface, wl_output_interface.name) == 0) {
        auto bar = std::make_unique<Bar>();
        bar->app = &a;
        uint32_t output_version = version < 4 ? version : 4;
        bar->output = static_cast<wl_output*>(
            wl_registry_bind(reg, name, &wl_output_interface, output_version));
        wl_output_add_listener(bar->output, &output_listener, bar.get());
        a.bars.push_back(std::move(bar));
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

static void create_layer_surface(App& a, Bar& b) {
    b.surface = wl_compositor_create_surface(a.compositor);
    b.layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        a.layer_shell, b.surface, b.output,
        ZWLR_LAYER_SHELL_V1_LAYER_TOP, "minibar");

    sync_buffer_scale(b);
    wl_surface_set_buffer_scale(b.surface, b.buffer_scale);

    zwlr_layer_surface_v1_add_listener(b.layer_surface, &layer_surface_listener, &b);
    zwlr_layer_surface_v1_set_anchor(
        b.layer_surface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_size(b.layer_surface, 0, b.height);
    zwlr_layer_surface_v1_set_exclusive_zone(b.layer_surface, b.height);
    zwlr_layer_surface_v1_set_margin(b.layer_surface, 0, 0, 0, 0);
    wl_surface_commit(b.surface);
}

int main() {
    App a{};

    // Connect to the compositor, discover globals, then create one layer-shell
    // surface anchored to the top edge of each output.
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

    a.hypr_fd = connect_hypr_socket2();

    if (a.bars.empty()) {
        auto bar = std::make_unique<Bar>();
        bar->app = &a;
        a.bars.push_back(std::move(bar));
    }

    for (auto& bar : a.bars) create_layer_surface(a, *bar);
    wl_display_roundtrip(a.display);

    int wl_fd = wl_display_get_fd(a.display);
    int stdin_fd = fileno(stdin);

    while (a.running) {
        for (auto& bar : a.bars) {
            if (bar->redraw) draw(a, *bar);
        }

        wl_display_flush(a.display);

        // One poll loop drives everything:
        // - Wayland socket: compositor events such as configure/scale
        // - stdin: external text updates for the bar contents
        // - Hyprland socket: fullscreen state changes
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
                update_bar_text(a, line);
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

    // Tear down in reverse order of ownership so Wayland objects do not outlive
    // the connection they were created from.
    for (auto& bar : a.bars) {
        destroy_buffer(bar->buf);
        if (bar->layer_surface) zwlr_layer_surface_v1_destroy(bar->layer_surface);
        if (bar->surface) wl_surface_destroy(bar->surface);
        if (bar->output) wl_output_destroy(bar->output);
    }
    if (a.hypr_fd >= 0) close(a.hypr_fd);
    if (a.layer_shell) zwlr_layer_shell_v1_destroy(a.layer_shell);
    if (a.shm) wl_shm_destroy(a.shm);
    if (a.compositor) wl_compositor_destroy(a.compositor);
    if (a.registry) wl_registry_destroy(a.registry);
    if (a.display) wl_display_disconnect(a.display);
    return 0;
}
