/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/package
import std/os/path
import std/os/file
import std/os/process
import std/data/json
import parsers/alex/json-parse
import kokac/git

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

pub struct package-file
  compiler: compiler
  resolution: resolution
  dependencies: list<dependency>
  dev-dependencies: list<dependency>
  scripts: list<script>;

// Automatically generated.
// Shows a string representation of the `package-file` type.
pub fun package-file/show(this : package-file) : e string
  match this
    Package-file(compiler, resolution, dependencies, dev-dependencies, scripts) ->
      "Package-file(compiler: " ++ show(compiler) ++ ", resolution: " ++ show(resolution) ++ ", dependencies: " ++ show(dependencies) ++ ", dev-dependencies: " ++ show(dev-dependencies) ++ ", scripts: " ++ show(scripts) ++ ")"

pub fun compiler/from-json(jobj: json, json-path: string): pure compiler
  val npath = "compiler -> " ++ json-path
  match jobj
    JSString("default") -> Default
    JSObj(obj) -> 
      match obj.maybe/from-json("path", npath, ?from-json = string/from-json)
        Just(compiler-path) -> Path(compiler-path.path)
        _ ->
          match obj.maybe/from-json("commit", npath, ?from-json = string/from-json)
            Just(commit) -> Commit(commit)
            _ ->
              match obj.maybe/from-json("version", npath, ?from-json = string/from-json)
                Just(version) -> Version(version)
                _ -> 
                  throw("Invalid compiler object", info=JsonDeserializationException(jobj, npath))
    _ -> throw("Invalid compiler object", info=JsonDeserializationException(jobj, npath))

pub fun resolution/from-json(jobj: json, json-path: string): pure resolution
  val npath = "resolution -> " ++ json-path
  match jobj
    JSObj(obj) -> 
      match obj.maybe/from-json("global", npath, ?from-json = string/from-json)
        Just(global-path) -> Global(global-path.path)
        _ -> Local
    _ -> Local

pub fun deps/from-json(jobj: json, json-path: string): pure list<dependency>
  val npath = "dependencies -> " ++ json-path
  jobj.as-object(npath).map fn((name, source))
    Dependency(
      name,
      dep-source/from-json(source, npath)
    )

pub fun dep-source/from-json(jobj: json, json-path: string): pure dep-source
  val npath = "source -> " ++ json-path
  match jobj
    JSObj(obj) ->
      GitDep(
        obj.dict/from-json("url", npath, ?from-json = string/from-json),
        obj.maybe/from-json("path", npath, ?from-json = string/from-json).default(""),
        obj.maybe/from-json("ref", npath, ?from-json = git-ref/from-json).default(GitBranch("main"))
      )
    JSString(url) -> GitDep(url, "", GitDefault)

pub fun looks-like-hash(s: string): pure bool
  s.count == 40 && s.list.all(fn(c) c.is-hex-digit)

pub fun git-ref/from-json(jobj: json, json-path: string): pure git-ref
  val npath = "commit -> " ++ json-path
  match jobj
    JSString(ref) -> 
      if ref.looks-like-hash then GitCommit(ref)
      else GitBranch(ref)
      GitCommit(ref)
    _ -> throw("Expecting string, got " ++ jobj.show, info=JsonDeserializationException(jobj, npath))

pub fun scripts/from-json(jobj: json, json-path: string): pure list<script>
  val npath = "scripts -> " ++ json-path
  val obj = jobj.as-object(npath)
  obj.map(fn((key, value)) Script(key, value.string/from-json(npath)))
  

pub fun package-file/from-json(jobj: json, json-path: string): pure package-file
  val obj = jobj.as-object(json-path)
  Package-file(
    obj.maybe/from-json("compiler", "", ?from-json=compiler/from-json).default(Default),
    obj.maybe/from-json("resolution", "", ?from-json=resolution/from-json).default(Local),
    obj.maybe/from-json("dependencies", "", ?from-json=deps/from-json).default([]),
    obj.maybe/from-json("dev-dependencies", "", ?from-json=deps/from-json).default([]),
    obj.maybe/from-json("scripts", "", ?from-json=scripts/from-json).default([])
  )

pub fun parse-package(file: path): io package-file
  match run-system-read("python3 -c 'import yaml; import json; import sys; print(json.dumps(yaml.safe_load(open(\"" ++ file.string ++ "\", \"r\").read())));'")
    Error(err) -> throw("Failed to parse package file, make sure the file exists, you have python3 installed and the yaml python package installed:\n\t" ++ err.show)
    Ok(str) -> parse(json-parse/json/parse(str), package-file/from-json)
