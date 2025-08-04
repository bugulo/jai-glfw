# Jai GLFW

![Jai Version](https://img.shields.io/badge/Jai-0.2.016-blue)
![GLFW Version](https://img.shields.io/badge/GLFW-3.4.0-blue)

Jai bindings (generator) for [GLFW](https://github.com/glfw/glfw) compatible with **Windows (x64, ARM64)**, **Linux (x64, ARM64)** & **macOS (Universal)**

```jai
#import "glfw";
```

See also [examples/window.jai](./examples/window.jai) for a brief example.

## Generator

The repository contains pre-built bindings and libraries that can be used as-is. However, if you want to rebuild them, you can either run eg. `jai build.jai` or use your own build script and integrate [generator.jai](./generator.jai) programmatically:

```jai
options: glfw_generator.Options;
options.source_dir = "glfw";
options.output_dir = "dist";
options.debug_build = true;
glfw_generator.generate(options);

// This would be equal to running 'jai build.jai - -debug'
```

There are various options available to customize the generator, so be sure to check the respective files.

> [!IMPORTANT]
> To simplify the compilation of libraries, generator requires `cmake` to be installed and included in your PATH. The minimum CMake version depends on the [CMakeLists](https://github.com/glfw/glfw/blob/master/CMakeLists.txt) that comes with the provided GLFW source.

## Dynamic linking

Library is linked statically by default. You can change this by using optional module parameter:

```jai
#import "glfw"(USE_STATIC_LIB=false);
```

> [!NOTE]
> If you are compiling your project using WSL but your source files are located on Windows filesystem, dynamic linking will fail with `Dynamic library load failed: linux/x64/libglfw.so: file too short` because Linux does not understand Windows symlinks (see [link](https://stackoverflow.com/questions/56504821/sharing-git-repo-symlinks-between-windows-and-wsl))

