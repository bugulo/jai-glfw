#if !#exists(GLFW_SHARED) {
    GLFW_SHARED :: false;
}

#if OS == .WINDOWS && !GLFW_SHARED {
    #system_library,link_always "gdi32";
    #system_library,link_always "user32";
    #system_library,link_always "shell32";
} else #if OS == .LINUX && !GLFW_SHARED {
    #system_library,link_always "libm";
} else #if OS == .MACOS && !GLFW_SHARED {
    #system_library,link_always "IOKit";
}

#load "bindings.jai";
