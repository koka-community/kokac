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
import kokac/utils

pub fun register-dependencies(package-path: path, deps: list<() -> <current-dir,package-root,package-config,io> ()>, last-deps: list<string>): <current-dir,package-root,package-config,io> ()
  deps.foreach(submodule/config)
  println(get-dependencies().map(fn(d) d.name).join(", "))
  install()
  println("Resolution...")
  val pdeps = get-resolution().deps-path
  println("Current Deps...")
  val deps' = current-packages(pdeps).map(fn(x) relative-path(x, pdeps).string)
  if deps' != last-deps then
    println("Dependencies changed, installing new dependencies " ++ last-deps.show ++ " -> " ++ deps'.show)
    println("Package path: " ++ package-path.string)
    install-deps(package-path, deps = (package-path.dirname ++ "/deps").path, kokac = (package-path.dirname ++ "/.kokac").path, last-deps = last-deps)
    throw("Dependencies changed, please rerun the command")
  else
    println("Up to date")
    ()


// TODO: Check for changes / open editor in dependency
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone, but configured with a quick way to checkout another (non-fetched) branch. 
// TODO: Remove koka-community repo, and suggest migration to this tool
pub effect val package-root : path

pub fun download(dep: dependency, target-dir: path): io ()
  match dep.source
    GitDep(url, path, ref) -> download-or-update(dep.name, url, path, ref, target-dir)

pub fun deps-path(resolution: resolution): <package-root,io> path
  match resolution
    Global(pkg-path) -> pkg-path
    Local -> package-root / "deps"

pub fun install(): <package-config,package-root,io> ()
  val download-dir = get-resolution().deps-path
  ensure-dir(download-dir)
  get-dependencies().foreach fn(dep)
    download(dep, download-dir)
  get-dev-dependencies().foreach fn(dep)
    download(dep, download-dir)
  ()

pub fun imports(): <package-config,package-root,io> list<path>
  val top-path = get-resolution().deps-path
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
  println("Init " ++ nm.realpath.string)
  val pkg = (cwd() / nm.string / "package.kk").realpath
  if !is-file(pkg) then
    write-text-file(pkg, basic-package, True)
  write-text-file(nm / "bin" / "run.kk", basic-test, True)
  init-runner(pkg)

pub fun basic/init()
  val pkg = cwd() / "package.kk"
  if !is-file(pkg) then
    write-text-file(pkg, basic-package)
  init-runner(pkg)

fun runner(current_ts : int, path: string, deps: list<string>)
  r#"
import current/package
import kokac/config
import kokac/kokac
import kokac/utils
import kokac/exec
import std/os/env
import std/os/path
import std/os/dir
"# ++ deps.map(fn(d) "\nimport " ++ d ++ "/package").join("") ++ r#"

val current_ts = "# ++ current_ts.show ++ r#"
val package-path = "# ++ path.show ++ r#".path
val last-deps = ["# ++ deps.map(fn(d) "\"" ++ d ++ "\"").join(", ") ++ r#"]

fun main()
  with val package-root = package-path.dirname.path
  with val current-dir = package-root
  if current_ts != file_modified(package-path.string).unjust then 
    println("Package config out of date")
    copy-file(package-path, ".kokac/current/package.kk".path)
    install-deps(package-path, deps = (package-path.dirname ++ "/deps").path, kokac = (package-path.dirname ++ "/.kokac").path, last-deps=last-deps)
    println("Updated package config, try rerunning the command")
    -1
  else
    with default-package-config
    current/package/package()
    register-dependencies(package-path, ["# ++ 
  deps.map(fn(d) d ++ "/package/package").join(", ") ++
     r#"], last-deps)
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

pub fun current-packages(dep-dir: path): io list<path>
  dep-dir.list-directory.filter fn(d)
    (d / "package.kk").is-file

pub fun all-packages(dep-dir: path): io list<path>
  trace("Dep dir" ++ dep-dir.string)
  dep-dir.list-directory

fun path/(==)(p1: path, p2: path): bool
  p1.string == p2.string

pub fun relative-path(p: path, base: path): io path 
  // println("relative-path " ++ p.string ++ " " ++ base.string)
  val pparts = p.realpath.dirparts
  val bparts = base.realpath.dirparts
  fun go(b': list<string>, p': list<string>)
    match (b', p')
      (Nil, _) -> p'
      (_, Nil) -> throw("Cannot find relative path " ++ p.string.show ++ " " ++ base.string.show)
      (Cons(bh, bt), Cons(ph, pt)) ->
        if bh == ph then
          go(bt, pt)
        else
          throw("Cannot find relative path " ++ p.string.show ++ " " ++ base.string.show)
  // println("relative-path2 " ++ p.string ++ " " ++ base.string)
  go(bparts, pparts).foldl("".path, fn(acc, x) acc / x)

pub fun init-runner(file: path): io ()
  val deps = file.dirname / "deps"
  ensure-dir(deps)
  download-or-update("kokac", "https://github.com/koka-community/kokac", "", GitDefault, deps)
  val kokac = file.dirname / ".kokac"
  ensure-dir(kokac)
  ensure-dir(kokac / "current")
  copy-file(file, kokac / "current/package.kk")
  with val current-dir = file.dirname.path
  install-deps(file, deps, kokac)
  val kokac-path = (file.dirname / "deps/kokac").string
  val imports = "-i" ++ kokac-path ++ " -i" ++ deps.string ++ " -i" ++ kokac.string
  run("koka -e " ++ ".kokac/kokap.kk " ++ imports)
  ()

// Install deps recursively, rerunning the bootstrap script until no new dependencies are found.
pub fun install-deps(file: path, deps: path = file.dirname / "deps", kokac: path = file.dirname / ".kokac", last-deps : list<string> = []): <current-dir,io> ()
  val packaged-deps = current-packages(deps)
  val relative-deps = packaged-deps.map(fn(x) relative-path(x, deps).string)
  // Write koka wrapper / runner file with project specific dependencies
  println("Writing runner")
  write-text-file(kokac / "kokap.kk", runner(file_modified(file.string).unjust, file.realpath.string, relative-deps))
  // Run Install?
  val build = ".kokac/kokap.kk "
  val kokac-path = (file.dirname / "deps/kokac").string  
  val imports = "-i" ++ kokac-path ++ " -i" ++ deps.string ++ " -i" ++ kokac.string
  if last-deps != relative-deps then 
    println("Iterating deps")
    // This cannot use get-compiler-command(), because it is in the init
    run("koka -e " ++ build ++ imports)
    ()
  else 
    println("Finalizing deps")
    run("koka " ++ build ++ imports ++  " -o koka")
    trace("Building koka executable for package")
    run("/bin/bash -c \"chmod +x koka\"")
    ()
  // println("Give the generated koka executable at ./koka execute permissions")

// Runs a file
pub fun run(file: path, args: list<string>): <package-root,current-dir,package-config,io> int
  val args' = imports-args() ++ args
  val command = get-compiler-command() ++ " " ++ file.realpath.string ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)
   
// Runs the language server or passes through arguments that don't contain a file
pub fun run-basic(args: list<string>): <package-root,current-dir,package-config,io> int
  val args' = imports-args() ++ args
  val command = get-compiler-command() ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)