/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/kokac
import std/os/path
import std/os/dir
import std/os/file
import std/os/process
import std/os/env
import kokac/package
import kokac/exec
import kokac/git
import kokac/config
import kokac/exec

// TODO: Check for changes / open editor in dependency
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone, but configured with a quick way to checkout another (non-fetched) branch. 
// TODO: Remove koka-community repo, and suggest migration to this tool
effect val package-root : path

pub fun download(dep: dependency, target-dir: path): io ()
  match dep.source
    GitDep(url, path, ref) -> download-or-update(dep.name, url, path, ref, target-dir)

pub fun path(resolution: resolution): <package-root,io> path
  match resolution
    Global(pkg-path) -> pkg-path
    Local -> package-root / "deps"

pub fun install(): <package-config,package-root,io> ()
  val download-dir = get-resolution().path
  ensure-dir(download-dir)
  get-dependencies().foreach fn(dep)
    download(dep, download-dir)
  get-dev-dependencies().foreach fn(dep)
    download(dep, download-dir)
  ()

pub fun imports(): <package-config,package-root,io> list<path>
  val top-path = get-resolution().path
  (get-dependencies() ++ get-dev-dependencies()).map fn(dep)
    top-path / dep.name

pub fun imports-args(): <package-config,package-root,io> list<string>
  imports().map(fn(p) "-i" ++ p.string)

pub fun find-package-root(file: path): io maybe<(path, path)>
  if file.dirname == file.string || file.dirname == "" then
    Nothing
  else
    val pkgpath = file.dirname 
    if is-file(pkgpath / "package.kk") then
      Just((pkgpath.path, pkgpath / "package.kk"))
    else
      find-package-root(file.dirname.path)

val basic-package = r#"
import kokac/config

fun package()
  dependencies
    dep("std")
      "git@github.com:koka-community/std"
"#

val basic-test = r#"
import std/data/json
fun main()
  JSList([JSString("Hi")]).println
"#

pub fun name/init(nm: path)
  val pkg = nm / "package.kk"
  if !is-file(pkg) then
    write-text-file(pkg, basic-package, True)
  write-text-file(nm / "bin" / "run.kk", basic-test, True)
  init-runner(pkg)

pub fun basic/init()
  val pkg = cwd() / "package.kk"
  if !is-file(pkg) then
    write-text-file(pkg, basic-package)
  init-runner(pkg)

val runner = r#"
import package
import kokac/config
import kokac/kokac
import std/os/env
import std/os/path

fun main()
  with default-package-config
  package()
  val args = get-args()
  // Split the file from the rest of the arguments so we can resolve the package from the file
  val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
  match file
    Cons(f, Nil) -> 
      run((cwd() / f).realpath, args)
    _ -> 
      run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.
"#

pub fun get-compiler-command(): <package-config,io> string
  match get-compiler()
    Default -> "koka"
    Sdk(sdk-path) -> 
      // TODO: Cache this?
      var command := "stack path --local-install-root"
      if get-os-name() != "windows" then
        val ghcenv = homedir() / "ghcup/env"
        if is-file(ghcenv) then 
          val shell = get-env-value("SHELL").default("bash")
          command := shell ++ " -c \"source " ++ ghcenv.string ++ " && stack path --local-install-root\""
      match run-system-read("cd \"" ++ sdk-path.string ++ "\" && " ++ command)
        Ok(build-path) -> 
          val koka-path = build-path.trim() / "bin/koka"
          if is-file(koka-path) then
            koka-path.string
          else
            throw("Compiler not found at " ++ koka-path.string)
    _ -> throw("Compiler configuration not supported yet")

pub fun init-runner(file: path): io ()
  val deps = file.dirname / "deps"
  ensure-dir(deps)
  download-or-update("kokac", "https://github.com/koka-community/kokac", "", GitDefault, deps)
  val kokac = file.dirname / ".kokac"
  ensure-dir(kokac)
  copy-file(file, kokac / "package.kk")
  if !is-file(kokac / "kokap.kk") then
    write-text-file(kokac / "kokap.kk".path, runner)
  val build = (kokac / "kokap.kk ").string
  val out = (file.dirname / "koka").string
  val kokacpath = (file.dirname / "deps/kokac").string
  // This cannot use get-compiler-commend(), because it is in the init
  run-system("koka " ++ build ++ " -i" ++ kokacpath ++  " -o" ++ out)
  ("Give the generated koka executable at " ++ out ++ " execute permissions").println
  ()

pub fun run(file: path, args: list<string>): <package-config,io> int
  match find-package-root(file)
    Just((root, _)) ->
      with val package-root = root
      // println(root)
      install() // TODO: Keep track of timestamp to not refetch for 30 seconds?
      // println(imports-args())
      val args' = imports-args() ++ args
      val command = get-compiler-command() ++ " " ++ file.realpath.string ++ " " ++ args'.join(" ")
      with val current-dir = root
      println(command)
      run-result(command)
    _ ->
      println("No package file found in directories above " ++ file.string)
      -1

pub fun run-basic(args: list<string>): <package-config,io> int
  match find-package-root(cwd() / "package.kk") // Dummy filename, since we don't have a file to resolve the package file from
    Just((root, _)) ->
      with val package-root = root
      // println(root)
      install()
      // println(imports-args())
      val args' = imports-args() ++ args
      val command = get-compiler-command() ++ " " ++ args'.join(" ")
      with val current-dir = root
      println(command)
      run-result(command)
    _ -> 
      println("No package file found in directories above " ++ cwd().string)
      -1