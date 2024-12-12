/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac
import std/os/process
import std/os/path

type compiler
   Default
   Path(sdk-path: path) 
   Commit(hash: string)
   Version(version: string)

type resolution
  Global(pkg-path: path)
  Local

type git-ref
   GitCommit(hash: string)
   GitBranch(name: string)


struct git-dep
   ssh: bool
   org: string
   project: string
   path: string
   commit: git-ref

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

// TODO: Check for changes / open editor in dependency
// TODO: Command line option forwarding to koka
// TODO: VSCode extension (try to use official extension but with different Koka executable location, since this should mimic it)
// TODO: Default shallow clone, but configured with a quick way to checkout another (non-fetched) branch. 
// TODO: Remove koka-community repo, and suggest migration to this tool

pub fun git-download(dep: git-dep): ()
  
  ()