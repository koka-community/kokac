/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/package
import std/os/path
import std/os/file
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

pub type resolution
  Global(pkg-path: path)
  Local

pub type dep-source
  GitDep(url: string, path: string, commit: git-ref)

pub struct dependency
  name: string
  source: dep-source;

pub struct script
  command: string
  execute: string;

pub struct package-file
  compiler: compiler
  resolution: resolution
  dependencies: list<dependency>
  dev-dependencies: list<dependency>
  scripts: list<script>;

// TODO: Parsing a koka.yaml file
pub fun parse-package(file: path): io package-file
  val contents = file.read-text-file
  Package-file(Default, Local, [], [], [])