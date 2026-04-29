#include <flutter_linux/flutter_linux.h>

#include "my_application.h"
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <polkit/polkit.h>

#include <iostream>
#include <map>
#include <memory>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
    GtkApplication parent_instance;
    char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static void can_authenticate(FlMethodCall* method_call) {
    GError* error = nullptr;
    PolkitAuthority* authority = polkit_authority_get_sync(nullptr, &error);
    if (error) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false))), nullptr);
        g_clear_error(&error);
        return;
    }
    if (authority == nullptr) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false))), nullptr);
        return;
    }

    const gchar* snap = g_getenv("SNAP");
    if (snap != nullptr) {
        g_autofree gchar* snap_policy_path = g_build_filename(snap, "meta", "polkit", "polkit.app.openauthenticator.policy", nullptr);
        gboolean success = g_file_test(snap_policy_path, G_FILE_TEST_IS_REGULAR);

        g_object_unref(authority);
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(success))), nullptr);
        return;
    }

    GList* actions = polkit_authority_enumerate_actions_sync(authority, nullptr, &error);
    if (error) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_error_response_new("authCheckError", error->message, nullptr)), nullptr);
        g_clear_error(&error);
        g_object_unref(authority);
        return;
    }
    bool hasOpenApp = false, hasSensible = false, hasEnable = false, hasDisable = false;
    for (GList* l = actions; l; l = g_list_next(l)) {
        auto* desc = static_cast<PolkitActionDescription*>(l->data);
        const gchar* id = polkit_action_description_get_action_id(desc);
        if (!id) {
            continue;
        }
        if (strcmp(id, "app.openauthenticator.openApp") == 0) {
            hasOpenApp = true;
        }
        else if (strcmp(id, "app.openauthenticator.sensibleAction") == 0) {
            hasSensible = true;
        }
        else if (strcmp(id, "app.openauthenticator.enable") == 0) {
            hasEnable = true;
        }
        else if (strcmp(id, "app.openauthenticator.disable") == 0) {
            hasDisable = true;
        }
        if (hasOpenApp && hasSensible && hasEnable && hasDisable) {
            break;
        }
    }

    gboolean success = hasOpenApp && hasSensible && hasEnable && hasDisable;
    g_list_free_full(actions, g_object_unref);
    g_object_unref(authority);
    fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(success))), nullptr);
}

static void authenticate_async_callback(PolkitAuthority* authority, GAsyncResult* result, gpointer user_data) {
    GError* error = nullptr;

    PolkitAuthorizationResult* auth_result = polkit_authority_check_authorization_finish(authority, result, &error);

    if (error) {
        std::cout << error->message << std::endl;
        fl_method_call_respond((FlMethodCall*)user_data, FL_METHOD_RESPONSE(fl_method_error_response_new("authError", error->message, nullptr)), nullptr);
        g_clear_error(&error);
        g_object_unref(user_data);
        return;
    }
    if (auth_result == nullptr) {
        fl_method_call_respond((FlMethodCall*)user_data, FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(false))), nullptr);
        g_object_unref(user_data);
        return;
    }

    gboolean success = polkit_authorization_result_get_is_authorized(auth_result);
    fl_method_call_respond((FlMethodCall*)user_data, FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(success))), nullptr);

    g_object_unref(user_data);
}

static PolkitSubject* make_subject_from_system_bus(GError** error) {
    GDBusConnection* system_bus = g_bus_get_sync(G_BUS_TYPE_SYSTEM, nullptr, error);
    if (!system_bus) {
        return nullptr;
    }

    const gchar* unique = g_dbus_connection_get_unique_name(system_bus);
    if (!unique) {
        g_set_error(error, G_IO_ERROR, G_IO_ERROR_FAILED, "No unique D-Bus name on system bus");
        g_object_unref(system_bus);
        return nullptr;
    }

    PolkitSubject* subject = polkit_system_bus_name_new(unique);

    g_object_unref(system_bus);
    return subject;
}

static void authenticate(const std::string reason, FlMethodCall* method_call) {
    GError* error = nullptr;
    PolkitAuthority* authority = polkit_authority_get_sync(nullptr, &error);
    if (error || authority == nullptr) {
        fl_method_call_respond(method_call, FL_METHOD_RESPONSE(fl_method_error_response_new("authError", error->message, nullptr)), nullptr);
        return;
    }

    PolkitSubject* subject = make_subject_from_system_bus(&error);
    if (!subject) {
        fl_method_call_respond(method_call,FL_METHOD_RESPONSE(fl_method_error_response_new("authError", error ? error->message : "subject error", nullptr)), nullptr);
        if (error) {
            g_clear_error(&error);
        }
        return;
    }

    polkit_authority_check_authorization(
        authority,
        subject,
        ("app.openauthenticator." + reason).c_str(),
        nullptr,
        POLKIT_CHECK_AUTHORIZATION_FLAGS_ALLOW_USER_INTERACTION,
        nullptr,
        (GAsyncReadyCallback) authenticate_async_callback,
        g_object_ref(method_call)
    );
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
    const gchar* method = fl_method_call_get_name(method_call);

    if (strcmp(method, "localAuth.isDeviceSupported") == 0) {
        can_authenticate(method_call);
    } else if (strcmp(method, "localAuth.authenticate") == 0) {
        FlValue* args = fl_method_call_get_args(method_call);
        FlValue* reason = fl_value_lookup_string(args, "reason");
        authenticate(fl_value_get_string(reason), method_call);
    } else {
        g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
        fl_method_call_respond(method_call, response, nullptr);
    }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
    MyApplication* self = MY_APPLICATION(application);

    GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
    if (windows) {
        gtk_window_present(GTK_WINDOW(windows->data));
        return;
    }

    GtkWindow* window =
            GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

    // Use a header bar when running in GNOME as this is the common style used
    // by applications and is the setup most users will be using (e.g. Ubuntu
    // desktop).
    // If running on X and not using GNOME then just use a traditional title bar
    // in case the window manager does more exotic layout, e.g. tiling.
    // If running on Wayland assume the header bar will work (may need changing
    // if future cases occur).
    gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
    GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
    if (use_header_bar) {
        GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
        gtk_widget_show(GTK_WIDGET(header_bar));
        gtk_header_bar_set_title(header_bar, "Open Authenticator");
        gtk_header_bar_set_show_close_button(header_bar, TRUE);
        gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
    } else {
        gtk_window_set_title(window, "Open Authenticator");
    }

    gtk_window_set_default_size(window, 1280, 720);
    gtk_widget_show(GTK_WIDGET(window));

    g_autoptr(FlDartProject) project = fl_dart_project_new();
    fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

    FlView* view = fl_view_new(project);
    gtk_widget_show(GTK_WIDGET(view));
    gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

    fl_register_plugins(FL_PLUGIN_REGISTRY(view));

    FlEngine* engine = fl_view_get_engine(view);

    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    g_autoptr(FlBinaryMessenger) messenger = fl_engine_get_binary_messenger(engine);
    g_autoptr(FlMethodChannel) channel = fl_method_channel_new(messenger, "app.openauthenticator.localauth", FL_METHOD_CODEC(codec));
    fl_method_channel_set_method_call_handler(channel, method_call_cb, g_object_ref(view), g_object_unref);

    gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
    MyApplication* self = MY_APPLICATION(application);
    // Strip out the first argument as it is the binary name.
    self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

    g_autoptr(GError) error = nullptr;
    if (!g_application_register(application, nullptr, &error)) {
        g_warning("Failed to register: %s", error->message);
        *exit_status = 1;
        return TRUE;
    }

    g_application_activate(application);
    *exit_status = 0;

    return FALSE;
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
    MyApplication* self = MY_APPLICATION(object);
    g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
    G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
    G_APPLICATION_CLASS(klass)->activate = my_application_activate;
    G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
    G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
    g_set_prgname(APPLICATION_ID);
    return MY_APPLICATION(g_object_new(my_application_get_type(), "application-id", APPLICATION_ID, "flags", G_APPLICATION_HANDLES_COMMAND_LINE | G_APPLICATION_HANDLES_OPEN, nullptr));
}
