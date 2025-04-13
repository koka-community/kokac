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

pub effect package-paths
  val package-root : path
  val package-runner-source : path
  val package-runner-exe : path
  val update-runner-source : path
  val update-runner-exe : path

fun set-package-root(root: path, f: () -> <package-paths,ndet|e> a): <ndet|e> a
  val kokac = root / ".kokac"
  with handler
    val package-root = root
    val package-runner-source = kokac / "koka-package-runner.kk"
    val package-runner-exe = (kokac / "koka-package-runner").exe-path
    val update-runner-source = kokac / "koka-update-runner.kk"
    val update-runner-exe = (root / "koka").exe-path
  f()


// Runs a file
fun run-file(file: path, args: list<string>): <package-paths,current-dir,package-config,io> int
  val args' = imports-args() ++ args
  val command = get-compiler-command() ++ " " ++ file.realpath.string ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)

// Runs the language server or passes through arguments that don't contain a file
fun run-basic(args: list<string>): <package-paths,current-dir,package-config,io> int
  val args' = imports-args() ++ args
  val command = get-compiler-command() ++ " " ++ args'.join(" ")
  println(command)
  run-result(command)

fun download(dep: dependency, target-dir: path): io ()
  match dep.source
    GitDep(url, path, ref) -> download-or-update(dep.name, url, path, ref, target-dir)

fun deps-path(resolution: resolution): <package-paths,io> path
  match resolution
    Global(pkg-path) -> pkg-path
    Local -> package-root / "deps"

fun install(): <package-config,package-paths,io> ()
  val download-dir = get-resolution().deps-path
  ensure-dir(download-dir)
  get-dependencies().foreach fn(dep)
    download(dep, download-dir)
  get-dev-dependencies().foreach fn(dep)
    download(dep, download-dir)
  ()

fun imports(): <package-config,package-paths,io> list<path>
  val top-path = get-resolution().deps-path
  (get-dependencies() ++ get-dev-dependencies()).map fn(dep)
    top-path / dep.name

fun imports-args(): <package-config,package-paths,io> list<string>
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

fun copy-package-file(file: path, kokac: path)
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
import std/os/env
import std/os/path
import std/os/dir
"# ++ deps.map(fn(d) "\nimport " ++ d ++ "/package").join("") ++ r#"

val package-path = "# ++ path.show ++ r#".path
val last-deps = ["# ++ deps.map(fn(d) "\"" ++ d ++ "\"").join(", ") ++ r#"]

fun main()
  with val current-dir = cwd()
  with set-package-root(find-package-root(current-dir / "test.kk"))
  with default-package-config
  current/package/package()
  install-run(package-path, ["# ++ 
    deps.map(fn(d) d ++ "/package/package").join(", ") ++
      r#"], last-deps)
"#

fun current-packages(dep-dir: path): io list<string>
  val packages = dep-dir.list-directory.filter fn(d)
    (d / "package.kk").is-file
  packages.map(fn(x) relative-path(x, dep-dir).string)

alias package-registrar = () -> <package-config> ()

pub fun install-run(package-path: path,
                    deps: list<package-registrar>, 
                    last-deps: list<string>): <current-dir,package-paths,package-config,io> int
  deps.foreach(submodule/config)
  install()
  if current-packages(get-resolution().deps-path) != last-deps then
    -1
  else
    val args = get-args()
    // Split the file from the rest of the arguments so we can resolve the package from the file
    val (file, rest) = args.span(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
    match file
      Cons(f, Nil) -> 
        run-file((cwd() / f).realpath, rest)
      _ -> 
        run-basic(args) // Just passthrough the arguments using the cwd as location to resolve package file from.

