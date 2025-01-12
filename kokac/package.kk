/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/package
import std/os/path
import std/os/file
import std/os/dir
import std/os/process
import kokac/git
import kokac/exec

// WIP: Package file format
// ``` koka.yaml
// compiler: default // if default is specified then the one from the system path is used
//   path: ... (a path to the koka SDK directory -- the Koka executable will be discovered via stack)
//   commit: ... (a specific version of the koka compiler to checkout (shallowly) in a hash referenced location and compiled via `stack build`)
//   version: ... (ensures the version is downloaded to some known location, but not installed globally, so there can be multiple simultaneous versions)
// 
// resolution:
//   global: path
//   local // (defaults to local) global resolution stores all packages in a global directory (i.e. koka-community is the default path), local stores it relative to the koka.yaml (in deps/) - make sure to .gitignore
// 
// dependencies:
//   name: git.... // or just a url
//   name:
//     git: 
//       url: ...
//       ref: ... (optional) defaults to main
//       path: ... (optional)
// 
// dev_dependencies: (used for dependencies used in /bin /test /examples, but not in your main package) if you are not creating a package, and just a binary ignore this
//   name:
//     ....
// 
// scripts:
//   name: '...' // a subcommand of kokac to provide quick commands
// ```
pub type compiler
  Default
  Path(sdk-path: path) 
  Commit(hash: string)
  Version(version: string)

// Automatically generated.
// Shows a string representation of the `compiler` type.
pub fun compiler/show(this : compiler) : e string
  match this
    Default ->
      "Default"
    Path(sdk-path) ->
      "Path(sdk-path: " ++ show(sdk-path) ++ ")"
    Commit(hash) ->
      "Commit(hash: " ++ hash ++ ")"
    Version(version) ->
      "Version(version: " ++ version ++ ")"

pub type resolution
  Global(pkg-path: path)
  Local

// Automatically generated.
// Shows a string representation of the `resolution` type.
pub fun resolution/show(this : resolution) : e string
  match this
    Global(pkg-path) ->
      "Global(pkg-path: " ++ show(pkg-path) ++ ")"
    Local ->
      "Local"

pub type dep-source
  GitDep(url: string, path: string, commit: git-ref)

// Automatically generated.
// Shows a string representation of the `dep-source` type.
pub fun dep-source/show(this : dep-source) : e string
  match this
    GitDep(url, path, commit) ->
      "GitDep(url: " ++ url ++ ", path: " ++ path ++ ", commit: " ++ show(commit) ++ ")"

pub struct dependency
  name: string
  source: dep-source;

// Automatically generated.
// Shows a string representation of the `dependency` type.
pub fun dependency/show(this : dependency) : e string
  match this
    Dependency(name, source) ->
      "Dependency(name: " ++ name ++ ", source: " ++ source.show ++ ")"

pub struct script 
  command: string
  execute: string;

// Automatically generated.
// Shows a string representation of the `script` type.
pub fun script/show(this : script) : e string
  match this
    Script(command, execute) ->
      "Script(command: " ++ command ++ ", execute: " ++ execute ++ ")"

pub fun create-package-runner(file: path): io ()
  val deps = file.dirname / "deps"
  ensure-dir(deps)
  with val current-dir = deps
  download-or-update("kokac", "https://github.com/koka-community/kokac", "", GitDefault, deps)
  val kokac = file.dirname / ".kokac"
  ensure-dir(kokac)
  copy-file(file, kokac / "package.kk")
  if !is-file(kokac / "kokap.kk") then
    write-text-file(kokac / "kokap.kk".path, r#"
  import package
  import kokac/config
  import kokac/kokac
  fun main()
    var deps := []
    var scripts := []
    var dev-deps := []
    var compiler := Default
    var resolution := Local
    with handler
      fun set-dependencies(deps_new) deps := deps_new
      fun set-dev-dependencies(dev-deps_new) dev-deps := dev-deps_new
      fun set-scripts(scripts_new) scripts := scripts_new
      fun set-compiler(compiler_new) compiler := compiler_new
      fun set-resolution(resolution_new) resolution := resolution_new
      fun get-dependencies(): deps
      fun get-dev-dependencies(): dev-deps
      fun get-scripts(): scripts
      fun get-compiler(): compiler
      fun get-resolution(): resolution
    val args = get-args()
    // Split the file from the rest of the arguments so we can resolve the package from the file
    val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
    match file
      Cons(f, Nil) -> 
        run((cwd() / f).realpath, args)
      _ -> 
        run-langserver(args) // Just passthrough the arguments using the cwd as location to resolve package file from.
    "#)
  val build = (kokac / "kokap.kk ").string
  val out = (file.dirname / "koka").string
  run-system("koka " ++ build ++ "-ideps/kokac -o=" ++ out)
  ()