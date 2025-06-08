# Jai GLFW

![Jai Version](https://img.shields.io/badge/Jai-0.2.014-blue)
![GLFW Version](https://img.shields.io/badge/GLFW-3.4.0-blue)

Jai bindings for [GLFW](https://github.com/glfw/glfw). Tested and compatible with **Windows**, **Linux** & **OSX**.

## Generate
The repository contains pre-built binding files and compiled libraries for supported platforms. To compile for an older version of GLFW or target different forks of GLFW, you can change the following constants in [generate.jai](./generate.jai) and rerun it with `jai generate.jai`:

```
SOURCE_GIT_URL
SOURCE_GIT_COMMIT

SOURCE_VERSION_MAJOR
SOURCE_VERSION_MINOR
SOURCE_VERSION_PATCH
```

**Note**: You can also download the GLFW source manually and place it in this folder. The automatic download from the provided Git repository will then be skipped.

To simplify the compilation of libraries, [generate.jai](./generate.jai) requires `cmake` to be installed and included in your PATH. The minimum CMake version depends on the [CMakeLists](https://github.com/glfw/glfw/blob/master/CMakeLists.txt) that comes with the provided GLFW source.

## Dynamic linking

By default, static linking is enabled. If you prefer dynamic linking, you can utilize optional module parameter to toggle this behavior:

```jai
#import "glfw"(USE_STATIC_LIB=false);
```
