/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
import std/os/env
import std/os/path
import kokac/kokac
import kokac/package
import kokac/git

pub fun test()
  install(Package-file(Default, Local, [Dependency("std", GitDep("git@github.com:koka-community/std", "", GitBranch("main")))], [], []))

pub fun test2()
  // Split the file from the rest of the arguments so we can resolve the package from the file
  run((cwd() / "../kokac/kokac/test/run.kk").realpath, ["-e", "test/run.kk"])

pub fun main(): <io> int
   val args = get-args()
   // Split the file from the rest of the arguments so we can resolve the package from the file
   val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
   match file
     Cons(f, Nil) -> 
      run((cwd() / f).realpath, args)
     _ -> 
      run-langserver(args) // Just passthrough the arguments using the cwd as location to resolve package file from.