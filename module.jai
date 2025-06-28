#module_parameters(USE_STATIC_LIB := true);

#if OS == .WINDOWS && USE_STATIC_LIB {
    #system_library,link_always "gdi32";
    #system_library,link_always "user32";
    #system_library,link_always "shell32";
} else #if OS == .LINUX && USE_STATIC_LIB {
    #system_library,link_always "libm";
} else #if OS == .MACOS && USE_STATIC_LIB {
    #system_library,link_always "IOKit";
}

GLFW_USE_STATIC_LIB :: USE_STATIC_LIB;

#load "dist/bindings.jai";
