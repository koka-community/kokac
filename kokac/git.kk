/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/git
import kokac/exec
import std/os/path

pub type git-ref
  GitCommit(hash: string)
  GitBranch(name: string)

pub fun expose-branches(): <current-dir,io> ()
  run("git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'")

// Can turn a shallow repo into a deep one
pub fun fetch-all(shallow: bool = True): <current-dir,io> ()
  if shallow then run("git fetch --all --shallow")
  else run("git fetch --all")

pub fun checkout(ref: string)
  run("git checkout " ++ ref)

pub fun download(url: string, repo-path: string, commit: git-ref, target-dir: path)
  if repo-path != "" then 
    throw("Unsupported repo-path")
  match commit
    GitCommit(hash) -> 
      with val current-dir = target-dir
      run("git clone --depth=1 \"" ++ url ++ "\"")
      expose-branches()
      fetch-all(False)
      checkout(hash)
    GitBranch(b) ->
      with val current-dir = target-dir
      run("git clone --depth=1 -b " ++ b ++ " " ++ url)