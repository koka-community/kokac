import kokac/config

fun project()
  dependencies
    dep("parsing")
      "git@github.com:koka-community/parsing"
    dep("std")
      "git@github.com:koka-community/std"

  scripts
    script("run")
      "echo \"Hello World\""