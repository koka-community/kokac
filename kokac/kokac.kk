/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/kokac
import std/os/path
import std/os/dir
import kokac/package
import kokac/exec
import kokac/git
import kokac/config

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
      Just((pkgpath.path, pkgpath / "koka.yaml"))
    elif is-file(pkgpath / "koka.yml") then
      Just((pkgpath.path, pkgpath / "koka.yml"))
    else
      find-package-root(file.dirname.path)

pub fun run(file: path, args: list<string>): <package-config,io> int
  match find-package-root(file)
    Just((root, _)) ->
      with val package-root = root
      // println(root)
      install() // TODO: Keep track of timestamp to not refetch for 30 seconds?
      // println(imports-args())
      val args' = imports-args() ++ args
      val command = "koka " ++ file.realpath.string ++ " " ++ args'.join(" ")
      with val current-dir = root
      run-result(command)
    _ ->
      println("No package file found in directories above " ++ file.string)
      -1

pub fun run-basic(args: list<string>): <package-config,io> int
  match find-package-root(cwd() / "koka.yaml") // Dummy filename, since we don't have a file to resolve the package file from
    Just((root, _)) ->
      with val package-root = root
      // println(root)
      install()
      // println(imports-args())
      val args' = imports-args() ++ args
      val command = "koka " ++ args'.join(" ")
      with val current-dir = root
      run-result(command)
    _ -> 
      println("No package file found in directories above " ++ cwd().string)
      -1