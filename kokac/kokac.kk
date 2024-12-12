/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/kokac
import std/os/process
import std/os/path
import std/os/dir
import kokac/package
import kokac/git

// TODO: Check for changes / open editor in dependency
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone, but configured with a quick way to checkout another (non-fetched) branch. 
// TODO: Remove koka-community repo, and suggest migration to this tool

pub fun download(dep: dependency, target-dir: path): io ()
  match dep.source
    GitDep(url, path, ref) -> download-or-update(dep.name, url, path, ref, target-dir)

pub fun path(resolution: resolution): io path
  match resolution
    Global(pkg-path) -> pkg-path
    Local -> cwd() / "deps"

pub fun install(pkg: package-file): io ()
  val download-dir = pkg.resolution.path
  ensure-dir(download-dir)
  pkg.dependencies.foreach fn(dep)
    download(dep, download-dir)
  pkg.dev-dependencies.foreach fn(dep)
    download(dep, download-dir)
  ()

pub fun imports(pkg: package-file): io list<path>
  val top-path = pkg.resolution.path
  (pkg.dependencies ++ pkg.dev-dependencies).map fn(dep)
    top-path / dep.name / dep.name

pub fun run(file: path, args: list<string>): io int
  val dir = file.dirname.path
  val pkg = dir / "koka.yaml"
  if is-file(pkg) then
    val package = parse-package(pkg)
    install(package) // TODO: Keep track of timestamp to not refetch for 30 seconds?
    val args' = package.imports.map(fn(p) "-i" ++ p.string) ++ args
    run-system("koka " ++ args'.join(" "))
  else
    println("No package file found in " ++ dir.string)
    -1
