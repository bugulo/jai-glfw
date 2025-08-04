Options :: struct {
    source_dir: string;
    output_dir: string;

    debug_build := false;

    // To make things simpler, by default, the generator downloads the GLFW source into the specified source_dir automatically.
    // If you want to use a custom GLFW source, it has to be located in the specified source_dir, and source_download needs to be disabled.
    // - Make sure to adjust the source_version_ options in this case as well.
    source_download := true;
    source_delete   := true; // Delete specified source_dir after generation is done (ignored if source_download is false)

    source_git_url := "https://github.com/glfw/glfw";
    source_git_ref := "tags/3.4";

    source_version_major := 3;
    source_version_minor := 4;
    source_version_patch := 0;

    max_parallel_jobs := 0;
}

generate :: (options: Options) -> success := false, error := "" {
    if options.source_download {
        if file_exists(options.source_dir) {
            if !delete_directory(options.source_dir)
                return error = "Failed to delete old source_dir";
        }

        if run_command("git", "clone", options.source_git_url, options.source_dir).exit_code != 0
            return error = "Failed to clone from specified source_git_url";

        if run_command("git", "checkout", options.source_git_ref, working_directory = options.source_dir).exit_code != 0
            return error = "Failed to checkout specified source_git_ref";
    }

    success, error := compile_libraries(options);

    // Don't delete source_dir if user provided own source
    if options.source_download && options.source_delete {
        delete_directory(options.source_dir);
    }

    return success, error;
}

#scope_file

compile_libraries :: (options: Options) -> success := false, error := "" {
    source_dir := options.source_dir;
    output_dir := options.output_dir;

    libs_output_dir: string;
    #if OS == .MACOS {
        libs_output_dir = tprint("%/macos", output_dir);
    } else #if OS == .LINUX && CPU == .X64 {
        libs_output_dir = tprint("%/linux/x64", output_dir);
    } else #if OS == .LINUX && CPU == .ARM64 {
        libs_output_dir = tprint("%/linux/arm64", output_dir);
    } else #if OS == .WINDOWS && CPU == .X64 {
        libs_output_dir = tprint("%/windows/x64", output_dir);
    } else #if OS == .WINDOWS && CPU == .ARM64 {
        libs_output_dir = tprint("%/windows/arm64", output_dir);
    } else {
        return error = "Generation is not supported on this platform";
    }

    build_dir := tprint("%/build", source_dir);

    if !file_exists(source_dir)
        return error = "Could not find GLFW source";
    if !recreate_directory(build_dir)
        return error = "Could not recreate build directory";
    if !recreate_directory(libs_output_dir)
        return error = "Could not recreate libs output directory";

    #if OS == .WINDOWS {
        shared_lib_dir := tprint("%/shared", build_dir);
        static_lib_dir := tprint("%/static", build_dir);

        if !build_glfw(source_dir, build_dir, shared_lib_dir, options, .["-DBUILD_SHARED_LIBS=ON"])
            return error = "Could not compile shared library";
        if !build_glfw(source_dir, build_dir, static_lib_dir, options, .["-DBUILD_SHARED_LIBS=OFF"])
            return error = "Could not compile static library";

        success := copy_file(tprint("%/glfw3.dll", shared_lib_dir), tprint("%/glfw3.dll", libs_output_dir));
        success &&= copy_file(tprint("%/glfw3dll.lib", shared_lib_dir), tprint("%/glfw3.lib", libs_output_dir));

        // We add _static to static library name otherwise it would overwrite import library for the dynamic one
        success &&= copy_file(tprint("%/glfw3.lib", static_lib_dir), tprint("%/glfw3_static.lib", libs_output_dir));

        if !success return error = "Failed to copy libraries into output directory";

    } else #if OS == .LINUX {
        libs_dir := tprint("%/libs", build_dir);
        if !build_glfw(source_dir, build_dir, libs_dir, options, .["-DBUILD_SHARED_LIBS=ON"])
            return error = "Could not compile shared library";
        if !build_glfw(source_dir, build_dir, libs_dir, options, .["-DBUILD_SHARED_LIBS=OFF"])
            return error = "Could not compile static library";

        // Copy libraries into output directory & create missing symlinks to dynamic library
        dynamic_lib_name := tprint("libglfw.so.3.%", options.source_version_minor);
        success := copy_file(tprint("%/%", libs_dir, dynamic_lib_name), tprint("%/%", libs_output_dir, dynamic_lib_name));
        success &&= run_command("ln", "-s", dynamic_lib_name, tprint("%/libglfw.so.3", libs_output_dir)).exit_code == 0;
        success &&= run_command("ln", "-s", "libglfw.so.3", tprint("%/libglfw.so", libs_output_dir)).exit_code == 0;

        success &&= copy_file(tprint("%/libglfw3.a", libs_dir), tprint("%/libglfw3.a", libs_output_dir));

        if !success return error = "Failed to copy libraries into output directory";

    } else #if OS == .MACOS {
        arm_libs_dir := tprint("%/arm", build_dir);
        if !build_glfw(source_dir, build_dir, arm_libs_dir, options, .["-DBUILD_SHARED_LIBS=ON", "-DCMAKE_OSX_ARCHITECTURES=arm64",  "-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"])
            return error = "Could not compile shared ARM library";
        if !build_glfw(source_dir, build_dir, arm_libs_dir, options, .["-DBUILD_SHARED_LIBS=OFF", "-DCMAKE_OSX_ARCHITECTURES=arm64",  "-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"])
            return error = "Could not compile static ARM library";

        x64_libs_dir := tprint("%/x86_64", build_dir);
        if !build_glfw(source_dir, build_dir, x64_libs_dir, options, .["-DBUILD_SHARED_LIBS=ON", "-DCMAKE_OSX_ARCHITECTURES=x86_64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.13"])
            return error = "Could not compile shared x86_64 library";
        if !build_glfw(source_dir, build_dir, x64_libs_dir, options, .["-DBUILD_SHARED_LIBS=OFF", "-DCMAKE_OSX_ARCHITECTURES=x86_64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.13"])
            return error = "Could not compile static x86_64 library";

        uni_libs_dir := tprint("%/universal", build_dir);
        if !make_directory_if_it_does_not_exist(uni_libs_dir)
            return error = "Could not create universal library directory";

        // Create universal dynamic library
        dynamic_lib_name := tprint("libglfw.3.%.dylib", options.source_version_minor);
        if run_command("lipo", "-create", "-output",
            tprint("%/%", uni_libs_dir, dynamic_lib_name),
            tprint("%/%", arm_libs_dir, dynamic_lib_name),
            tprint("%/%", x64_libs_dir, dynamic_lib_name),
        ).exit_code != 0 then return error = "Could not create universal dynamic library";

        // Create universal static library
        if run_command("lipo", "-create", "-output",
            tprint("%/libglfw3.a", uni_libs_dir),
            tprint("%/libglfw3.a", arm_libs_dir),
            tprint("%/libglfw3.a", x64_libs_dir),
        ).exit_code != 0 then return error = "Could not create universal static library";

        // Copy universal libraries into output directory & create missing symlinks to dynamic library
        success := copy_file(tprint("%/%", uni_libs_dir, dynamic_lib_name), tprint("%/%", libs_output_dir, dynamic_lib_name));
        success &&= run_command("ln", "-s", dynamic_lib_name, tprint("%/libglfw.3.dylib", libs_output_dir)).exit_code == 0;
        success &&= run_command("ln", "-s", "libglfw.3.dylib", tprint("%/libglfw.dylib", libs_output_dir)).exit_code == 0;

        success &&= copy_file(tprint("%/libglfw3.a", uni_libs_dir), tprint("%/libglfw3.a", libs_output_dir));

        if !success return error = "Failed to copy libraries into output directory";

    } else {
        return error = "Compilation is not supported on this platform";
    }

    bindings_options: Generate_Bindings_Options;
    {
        using bindings_options;

        #if OS == .WINDOWS {
            array_add(*libraries, .{filename="glfw3", identifier="glfw"});
        } else #if OS == .LINUX || OS == .MACOS {
            array_add(*libraries, .{filename="libglfw", identifier="glfw"});
        }

        array_add(*library_search_paths, libs_output_dir);

        footer = BINDINGS_FOOTER;
        generate_library_declarations = false;
        generate_compile_time_struct_checks = false;

        array_add(*extra_clang_arguments, "-DGLFW_INCLUDE_NONE");

        array_add(*source_files, tprint("%/include/GLFW/glfw3.h", source_dir));
    }

    if !generate_bindings(bindings_options, tprint("%/bindings.jai", output_dir))
        return error = "Could not generate bindings";

    return true;
}

BINDINGS_FOOTER :: #string END
#if GLFW_USE_STATIC_LIB {
    #if OS == .MACOS                        glfw :: #library,no_dll "macos/libglfw3";
    #if OS == .LINUX    && CPU == .X64      glfw :: #library,no_dll "linux/x64/libglfw3";
    #if OS == .LINUX    && CPU == .ARM64    glfw :: #library,no_dll "linux/arm64/libglfw3";
    #if OS == .WINDOWS  && CPU == .X64      glfw :: #library,no_dll "windows/x64/glfw3_static";
    #if OS == .WINDOWS  && CPU == .ARM64    glfw :: #library,no_dll "windows/arm64/glfw3_static";
} else {
    #if OS == .MACOS                        glfw :: #library "macos/libglfw";
    #if OS == .LINUX    && CPU == .X64      glfw :: #library "linux/x64/libglfw";
    #if OS == .LINUX    && CPU == .ARM64    glfw :: #library "linux/arm64/libglfw";
    #if OS == .WINDOWS  && CPU == .X64      glfw :: #library "windows/x64/glfw3";
    #if OS == .WINDOWS  && CPU == .ARM64    glfw :: #library "windows/arm64/glfw3";
}
END

build_glfw :: (source_dir: string, build_dir: string, output_dir: string, options: Options, args: [] string) -> bool {
    build_type := ifx options.debug_build then "Debug" else "Release";

    config_command: [..] string;
    array_add(*config_command, "cmake");
    array_add(*config_command, source_dir);
    array_add(*config_command, "-DGLFW_BUILD_DOCS=false");
    array_add(*config_command, "-DGLFW_BUILD_TESTS=false");
    array_add(*config_command, "-DGLFW_BUILD_EXAMPLES=false");

    array_add(*config_command, tprint("-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY=%", output_dir));
    array_add(*config_command, tprint("-DCMAKE_LIBRARY_OUTPUT_DIRECTORY=%", output_dir));
    array_add(*config_command, tprint("-DCMAKE_RUNTIME_OUTPUT_DIRECTORY=%", output_dir));

    #if OS == .WINDOWS {
        array_add(*config_command, tprint("-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG=%", output_dir));
        array_add(*config_command, tprint("-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG=%", output_dir));
        array_add(*config_command, tprint("-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG=%", output_dir));

        array_add(*config_command, tprint("-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=%", output_dir));
        array_add(*config_command, tprint("-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=%", output_dir));
        array_add(*config_command, tprint("-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=%", output_dir));
    }

    array_add(*config_command, tprint("-DCMAKE_BUILD_TYPE=%", build_type));
    array_add(*config_command, ..args);

    cmake_config_dir := tprint("%/cmake", build_dir);
    if !recreate_directory(cmake_config_dir)
        return false;

    if run_command(..config_command, working_directory = cmake_config_dir).exit_code != 0
        return false;

    build_command: [..] string;
    array_add(*build_command, "cmake", "--build", cmake_config_dir);

    array_add(*build_command, "--parallel");
    if options.max_parallel_jobs > 0 {
        array_add(*build_command, tprint("%", options.max_parallel_jobs));
    }

    if OS == .WINDOWS {
        array_add(*build_command, tprint("--config=%", build_type));
    }

    return run_command(..build_command).exit_code == 0;
}

recreate_directory :: (name: string) -> bool {
    if file_exists(name) {
        if !delete_directory(name) {
            return false;
        }
    }
    return make_directory_if_it_does_not_exist(name, recursive = true);
}

#import "File";
#import "Basic";
#import "Process";

#import "File_Utilities";
#import "Bindings_Generator";
