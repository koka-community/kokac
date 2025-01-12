import kokac/package
import kokac/kokac
import std/os/path

fun main()
  parse-package("../kokac/test/koka.yml".path)
  run("../kokac/test/bin/run.kk".path, ["-e"])
  ()
  