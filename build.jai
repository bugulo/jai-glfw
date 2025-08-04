glfw_generator :: #import,file "generator.jai";

#run {
    set_build_options_dc(.{do_output=false});

    args := get_build_options().compile_time_command_line;

    current_dir := get_absolute_path("./");

    options: glfw_generator.Options;
    options.source_dir = tprint("%/glfw", current_dir);
    options.output_dir = tprint("%/dist", current_dir);

    options.debug_build = array_find(args, "-debug");

    success, error := glfw_generator.generate(options);
    if !success {
        print("Failed to generate libraries or bindings: %\n", error);
        compiler_set_workspace_status(.FAILED);
    }
}

#import "File";
#import "Basic";
#import "Compiler";
