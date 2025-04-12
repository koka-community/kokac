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

// TODO: Check for changes / open editor in dependency
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone. 
// TODO: Remove koka-community repo, and suggest migration to this tool

pub effect val package-root : path

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
          val koka-path = build-path.trim() / "bin" / "koka"
          if is-file(koka-path) then
            koka-path.string
          else
            throw("Compiler not found at " ++ koka-path.string)
    _ -> throw("Compiler configuration not supported yet")

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

val basic-test = r#"
import std/data/json
fun main()
  JSList([JSString("Hi")]).println
"#

val basic-package = r#"
import kokac/config

fun package()
  dependencies
    dep("std")
      "git@github.com:koka-community/std"
"#

pub fun name/init(nm: path)
  println("Init " ++ nm.realpath.string)
  with val current-dir = cwd() / nm.string 
  val pkg = (current-dir / "package.kk").realpath
  if !is-file(pkg) then
    write-text-file(pkg, basic-package, True)
  write-text-file(nm / "bin" / "run.kk", basic-test, True)
  init-top-runner()

pub fun basic/init()
  val pkg = cwd() / "package.kk"
  with val current-dir = cwd()
  if !is-file(pkg) then
    write-text-file(pkg, basic-package)
  init-top-runner()

fun init-directory(package-path: path): io ()
  val deps = package-path / "deps"
  ensure-dir(deps)
  download-or-update("kokac", "https://github.com/koka-community/kokac", "", GitDefault, deps)
  val kokac = package-path / ".kokac"
  ensure-dir(kokac)
  copy-package-file(package-path / "package.kk", kokac)

pub fun copy-package-file(file: path, kokac: path)
  ensure-dir(kokac / "current")
  copy-file(file, kokac / "current" / "package.kk")

fun package-file-deps(file: path): io list<string>
  val kokac-path = (file.dirname / "deps" / "kokac").string
  val deps = (file.dirname / "deps").string
  val kokac = (file.dirname / ".kokac").string
  [kokac-path, deps, kokac]

fun package-file-imports(file: path): io string
  package-file-deps(file).map(fn(d) "-i" ++ d).join(" ")

fun init-top-runner()
  val runner = current-dir / ".kokac" / "kokax.kk"
  val out = exe-path(current-dir / "koka")
  init-directory(current-dir)
  write-text-file(runner, top-runner(current-dir.string))
  write-text-file(current-dir / ".kokac" / "last-deps", "")
  run("koka " ++ runner.string ++ " -o\"" ++ out.string ++ "\" -i" ++ ("deps" / "kokac").string)
  make-executable(out)
  update-kokap()
  build-kokap()
  ()

fun top-runner(package-dir: string)
  r#"
import kokac/kokac
import std/os/path

fun main()
  bootstrap-package("# ++ package-dir.show ++ r#".path)
  ()
"#

pub fun bootstrap-package(package-dir: path)
  with val current-dir = package-dir
  var needs-build := False
  while {out-of-date()} 
    println("Package config out of date")
    update-kokap()
    needs-build := True
    ()
  if needs-build then
    build-kokap()
    ()
  run-kokap()

fun update-kokap()
  val package-path = current-dir / "package.kk";
  val kokac = current-dir / ".kokac"
  val last-deps = current-packages(current-dir / "deps");
  copy-file(current-dir / "package.kk", kokac / "current" / "package.kk")
  write-text-file(kokac / "koka-deps", last-deps.join("\n"))  
  write-text-file(kokac / "kokap.kk", runner(package-path.string, last-deps))

fun out-of-date()
  val pkg = file_modified(current-dir / "package.kk")
  val current = file_modified(current-dir / ".kokac" / "kokap.kk")
  val deps = current-packages(current-dir / "deps")
  val last-deps = parse-last-deps()
  if pkg > current then
    println("Package file out of date " ++ pkg.show ++ " " ++ current.show)
    True
  elif deps != last-deps then
    println("Current packages " ++ deps.show ++ " newer than last packages " ++ last-deps.show)
    True
  else False

fun parse-last-deps()
  val file = read-text-file(current-dir / ".kokac" / "koka-deps")
  file.split("\n").filter(fn(p) p != "")

fun build-kokap()
  val out = (".kokac" / "koka").exe-path
  val kokap = (".kokac" / "kokap.kk").string
  run("koka " ++ kokap ++ " -o \"" ++ out.string ++ "\" -ideps -i.kokac -i" ++ ("deps" / "kokac").string)
  make-executable(out)

fun run-kokap()
  val args = get-args()
  run-result((".kokac" / "koka").string ++ " " ++ args.join(" "))

fun runner(path: string, deps: list<string>)
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

val package-path = "# ++ path.show ++ r#".path
val last-deps = ["# ++ deps.map(fn(d) "\"" ++ d ++ "\"").join(", ") ++ r#"]

fun main()
  with val current-dir = cwd()
  with val package-root = find-package-root(current-dir / "test.kk")
  with default-package-config
  current/package/package()
  match register-dependencies(package-path, ["# ++ 
    deps.map(fn(d) d ++ "/package/package").join(", ") ++
      r#"], last-deps)
    Just(new-deps) | new-deps != last-deps -> 
      -1 // Need to rebuild
    _ ->
      val args = get-args()
      // Split the file from the rest of the arguments so we can resolve the package from the file
      val (file, rest) = args.span(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
      match file
        Cons(f, Nil) -> 
          run((cwd() / f).realpath, rest)
        _ -> 
          run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.
"#


pub fun current-packages(dep-dir: path): io list<string>
  val packages = dep-dir.list-directory.filter fn(d)
    (d / "package.kk").is-file
  packages.map(fn(x) relative-path(x, dep-dir).string)

pub fun register-dependencies(package-path: path, deps: list<() -> <current-dir,package-root,package-config,io> ()>, last-deps: list<string>): <current-dir,package-root,package-config,io> maybe<list<string>>
  deps.foreach(submodule/config)
  install()
  Just(current-packages(get-resolution().deps-path))
