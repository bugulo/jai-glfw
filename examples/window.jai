#import "Basic";

#import "GL";

#import,file "../module.jai";

// You can also utilize optional module parameters:
// #import,file "../module.jai"(USE_STATIC_LIB=true);
// #import,file "../module.jai"(USE_STATIC_LIB=false);

// Or you can load the bindings directly:
// GLFW_USE_STATIC_LIB :: false;
// #load "../dist/bindings.jai";

main :: () {
  result := glfwInit();
  defer glfwTerminate();

  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GLFW_TRUE);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

  window := glfwCreateWindow(1280, 720, "Window", null, null);
  defer glfwDestroyWindow(window);

  glfwMakeContextCurrent(window);

  gl_load(*gl, glfwGetProcAddress.(*void));

  glfwSetWindowUserPointer(window, *context);
  glfwSetCursorPosCallback(window, glfwCursorCallback);

  glViewport(0, 0, 1280, 720);

  while !glfwWindowShouldClose(window) {
    glfwPollEvents();

    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(0.5, 0.5, 0.5, 1.0);

    glfwSwapBuffers(window);
  }
}

glfwCursorCallback :: (w: *GLFWwindow, x: float64, y: float64) #c_call {
    push_context {
        print("X: %, Y: %\n", x, y);
    }
}
