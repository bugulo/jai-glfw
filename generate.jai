// Generate script will automatically download GLFW source (if not found) from provided git repository
SOURCE_GIT_URL :: "https://github.com/glfw/glfw";
SOURCE_GIT_COMMIT :: "7b6aead9fb88b3623e3b3725ebb42670cbe4c579";

// Version of provided GLFW source
SOURCE_VERSION_MAJOR := 3;
SOURCE_VERSION_MINOR := 4;
SOURCE_VERSION_PATCH := 0;

#run {
    set_build_options_dc(.{do_output=false});

    options := get_build_options();
    success, error := generate(options.compile_time_command_line);
    if !success {
        print("Failed to generate libraries or bindings: %\n", error);
        compiler_set_workspace_status(.FAILED);
    }
}

generate :: (args: [] string) -> success := false, error := "" {
    current_dir := get_absolute_path("./");

    keep_source_files := array_find(args, "-keep_source");

    source_dir := tprint("%/glfw", current_dir);
    if !file_exists(source_dir) {
        if run_command("git", "clone", SOURCE_GIT_URL, source_dir).exit_code != 0
            return error = "Failed to clone from specified SOURCE_GIT_URL";

        if run_command("git", "checkout", SOURCE_GIT_COMMIT, working_directory = source_dir).exit_code != 0
            return error = "Failed to checkout to specified SOURCE_GIT_COMMIT";
    }

    output_dir: string;
    #if OS == .WINDOWS {
        output_dir = tprint("%/windows", current_dir);
    } else #if OS == .LINUX {
        output_dir = tprint("%/linux", current_dir);
    } else #if OS == .MACOS {
        output_dir = tprint("%/macos", current_dir);
    } else {
        return error = "Generation is not supported on this platform";
    }

    success, error := compile_libraries(source_dir, output_dir);

    if !keep_source_files {
        delete_directory(source_dir);
    }

    return success, error;
}

compile_libraries :: (source_dir: string, output_dir: string) -> success := false, error := "" {
    build_dir := tprint("%/build", source_dir);

    if !file_exists(source_dir)
        return error = "Could not find GLFW source";
    if !recreate_directory(build_dir)
        return error = "Could not recreate build directory";
    if !recreate_directory(output_dir)
        return error = "Could not recreate output directory";

    #if OS == .WINDOWS {
        shared_lib_dir := tprint("%/shared", build_dir);
        static_lib_dir := tprint("%/static", build_dir);

        if !build_glfw(source_dir, build_dir, shared_lib_dir, .["-DBUILD_SHARED_LIBS=ON"])
            return error = "Could not compile shared library";
        if !build_glfw(source_dir, build_dir, static_lib_dir, .["-DBUILD_SHARED_LIBS=OFF"])
            return error = "Could not compile static library";

        success := copy_file(tprint("%/glfw3.dll", shared_lib_dir), tprint("%/glfw3.dll", output_dir));
        success &&= copy_file(tprint("%/glfw3dll.lib", shared_lib_dir), tprint("%/glfw3.lib", output_dir));

        // We add _static to static library name otherwise it would overwrite import library for the dynamic one
        success &&= copy_file(tprint("%/glfw3.lib", static_lib_dir), tprint("%/glfw3_static.lib", output_dir));
        success &&= copy_file(tprint("%/glfw3.lib", static_lib_dir), tprint("%/glfw.lib", build_dir));

        if !success return error = "Failed to copy libraries into output directory";

    } else #if OS == .LINUX {
        libs_dir := tprint("%/libs", build_dir);
        if !build_glfw(source_dir, build_dir, libs_dir, .["-DBUILD_SHARED_LIBS=ON"])
            return error = "Could not compile shared library";
        if !build_glfw(source_dir, build_dir, libs_dir, .["-DBUILD_SHARED_LIBS=OFF"])
            return error = "Could not compile static library";

        // Copy libraries into output directory & create missing symlinks to dynamic library
        dynamic_lib_name := tprint("libglfw.so.3.%", SOURCE_VERSION_MINOR);
        success := copy_file(tprint("%/%", libs_dir, dynamic_lib_name), tprint("%/%", output_dir, dynamic_lib_name));
        success &&= run_command("ln", "-s", dynamic_lib_name, tprint("%/libglfw.so.3", output_dir)).exit_code == 0;
        success &&= run_command("ln", "-s", "libglfw.so.3", tprint("%/libglfw.so", output_dir)).exit_code == 0;

        success &&= copy_file(tprint("%/libglfw3.a", libs_dir), tprint("%/libglfw3.a", output_dir));
        success &&= copy_file(tprint("%/libglfw3.a", libs_dir), tprint("%/glfw.a", build_dir));

        if !success return error = "Failed to copy libraries into output directory";

    } else #if OS == .MACOS {
        arm_libs_dir := tprint("%/arm", build_dir);
        if !build_glfw(source_dir, build_dir, arm_libs_dir, .["-DBUILD_SHARED_LIBS=ON", "-DCMAKE_OSX_ARCHITECTURES=arm64",  "-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"])
            return error = "Could not compile shared ARM library";
        if !build_glfw(source_dir, build_dir, arm_libs_dir, .["-DBUILD_SHARED_LIBS=OFF", "-DCMAKE_OSX_ARCHITECTURES=arm64",  "-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0"])
            return error = "Could not compile static ARM library";

        x64_libs_dir := tprint("%/x86_64", build_dir);
        if !build_glfw(source_dir, build_dir, x64_libs_dir, .["-DBUILD_SHARED_LIBS=ON", "-DCMAKE_OSX_ARCHITECTURES=x86_64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.13"])
            return error = "Could not compile shared x86_64 library";
        if !build_glfw(source_dir, build_dir, x64_libs_dir, .["-DBUILD_SHARED_LIBS=OFF", "-DCMAKE_OSX_ARCHITECTURES=x86_64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=10.13"])
            return error = "Could not compile static x86_64 library";

        uni_libs_dir := tprint("%/universal", build_dir);
        if !make_directory_if_it_does_not_exist(uni_libs_dir)
            return error = "Could not create universal library directory";

        // Create universal dynamic library
        dynamic_lib_name := tprint("libglfw.3.%.dylib", SOURCE_VERSION_MINOR);
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
        success := copy_file(tprint("%/%", uni_libs_dir, dynamic_lib_name), tprint("%/%", output_dir, dynamic_lib_name));
        success &&= run_command("ln", "-s", dynamic_lib_name, tprint("%/libglfw.3.dylib", output_dir)).exit_code == 0;
        success &&= run_command("ln", "-s", "libglfw.3.dylib", tprint("%/libglfw.dylib", output_dir)).exit_code == 0;

        success &&= copy_file(tprint("%/libglfw3.a", uni_libs_dir), tprint("%/libglfw3.a", output_dir));
        success &&= copy_file(tprint("%/libglfw3.a", uni_libs_dir), tprint("%/glfw.a", build_dir));

        if !success return error = "Failed to copy libraries into output directory";

    } else {
        return error = "Compilation is not supported on this platform";
    }

    options: Generate_Bindings_Options;
    {
        using options;

        array_add(*libnames, "glfw");
        array_add(*libpaths, build_dir);

        footer = BINDINGS_FOOTER;
        generate_library_declarations = false;
        generate_compile_time_struct_checks = false;

        array_add(*extra_clang_arguments, "-DGLFW_INCLUDE_NONE");

        array_add(*source_files, tprint("%/include/GLFW/glfw3.h", source_dir));
    }

    if !generate_bindings(options, "bindings.jai")
        return error = "Could not generate bindings";

    return true;
}

BINDINGS_FOOTER :: #string END
#if USE_STATIC_LIB {
    #if OS == .WINDOWS  glfw :: #library,no_dll "windows/glfw3_static";
    #if OS == .LINUX    glfw :: #library,no_dll "linux/libglfw3";
    #if OS == .MACOS    glfw :: #library,no_dll "macos/libglfw3";
} else {
    #if OS == .WINDOWS  glfw :: #library "windows/glfw3";
    #if OS == .LINUX    glfw :: #library "linux/libglfw";
    #if OS == .MACOS    glfw :: #library "macos/libglfw";
}
END

build_glfw :: (source_dir: string, build_dir: string, output_dir: string, args: [] string) -> bool {
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

    array_add(*config_command, ..args);

    cmake_config_dir := tprint("%/cmake", build_dir);
    if !recreate_directory(cmake_config_dir)
        return false;

    if run_command(..config_command, working_directory = cmake_config_dir).exit_code != 0
        return false;

    return run_command("cmake", "--build", cmake_config_dir).exit_code == 0;
}

recreate_directory :: (name: string) -> bool {
    if file_exists(name) {
        if !delete_directory(name) {
            return false;
        }
    }
    return make_directory_if_it_does_not_exist(name);
}

#import "File";
#import "Basic";
#import "Process";
#import "Compiler";

#import "File_Utilities";
#import "Bindings_Generator";
