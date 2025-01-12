
import package
import kokac/config
import kokac/kokac
import std/os/env
import std/os/path

fun main()
  with default-package-config
  val args = get-args()
  // Split the file from the rest of the arguments so we can resolve the package from the file
  val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
  match file
    Cons(f, Nil) -> 
      run((cwd() / f).realpath, args)
    _ -> 
      run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.
  