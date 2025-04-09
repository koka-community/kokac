
import current/package
import kokac/config
import kokac/kokac
import kokac/utils
import kokac/exec
import std/os/env
import std/os/path

import parsing/package

val current_ts = 1744175503
val package-path = "/Users/timwhiting/koka-community/kokac/test/package.kk".path
val last-deps = ["parsing"]

fun main()
  with val package-root = package-path.dirname.path
  with val current-dir = package-root
  if current_ts != file_modified(package-path.string).unjust then 
    println("Package config out of date")
    install-deps(package-path, last-deps=last-deps)
    println("Updated package config, try rerunning the command")
    -1
  else
    with default-package-config
    current/package/package()
    register-dependencies(package-path, [parsing/package/package], last-deps)
    val args = get-args()
    // Split the file from the rest of the arguments so we can resolve the package from the file
    val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
    match file
      Cons(f, Nil) -> 
        run((cwd() / f).realpath, args)
      _ -> 
        run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.
