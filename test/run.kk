import kokac/package
import kokac/kokac
import std/os/path

fun test()
  create-package-runner("../kokac/test/package.kk".path)
  // run("../kokac/test/bin/run.kk".path, ["-e"])
  ()
  
