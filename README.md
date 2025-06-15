# Jai GLFW

![Jai Version](https://img.shields.io/badge/Jai-0.2.014-blue)
![GLFW Version](https://img.shields.io/badge/GLFW-3.4.0-blue)

Jai bindings for [GLFW](https://github.com/glfw/glfw). Compatible with **Windows (x64, ARM64)**, **Linux (x64, ARM64)** & **OSX (Universal)**.

The easiest way to get started is to import this folder as module ([module.jai](./module.jai)), which is setup to work with pre-built binding files and compiled libraries for all the supported platforms:

```jai
#import "glfw";
```

## Generate
You can simply run `jai build.jai`, which will compile the libraries for the host platform and generates bindings into the [dist](./dist) folder.

If you prefer not to use the pre-built files, you can also just load [generator.jai](./generator.jai) directly in your own build system and run the generation yourself, basically just like [build.jai](./build.jai).

> [!IMPORTANT]
> To simplify the compilation of libraries, [generator.jai](./generate.jai) requires `cmake` to be installed and included in your PATH. The minimum CMake version depends on the [CMakeLists](https://github.com/glfw/glfw/blob/master/CMakeLists.txt) that comes with the provided GLFW source.

## Dynamic linking

By default, static libraries will be used. If you prefer to use dynamic libraries, you can utilize optional module parameter to toggle this behavior:

```jai
#import "glfw"(USE_STATIC_LIB=false);
```

> [!NOTE]
> If you are using WSL to compile Linux binaries but your files actually reside on Windows, dynamic linking will fail with `Dynamic library load failed: linux/x64/libglfw.so: file too short` because Linux does not understand Windows symlinks (see [link](https://stackoverflow.com/questions/56504821/sharing-git-repo-symlinks-between-windows-and-wsl))
