/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/git
import kokac/exec
import std/os/path
import std/os/dir

pub type git-ref
  GitCommit(hash: string)
  GitBranch(name: string)

pub fun ref(r: git-ref)
  match r
    GitCommit(h) -> h
    GitBranch(b) -> b

pub fun expose-branches(): <current-dir,io> ()
  run("git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'")

// Can turn a shallow repo into a deep one
pub fun fetch-all(shallow: bool = True): <current-dir,io> ()
  if shallow then run("git fetch --all --shallow")
  else run("git fetch --all")

pub fun checkout(ref: string)
  run("git checkout " ++ ref)

pub fun pull()
  run("git pull")

pub fun download-or-update(name: string, url: string, repo-path: string, commit: git-ref, target-dir: path)
  if repo-path != "" then 
    throw("Unsupported repo-path")
  with val current-dir = target-dir
  if is-directory(target-dir / name) then 
    checkout(commit.ref)
    pull()
  else download(name, url, repo-path, commit)

// TODO: Add an option to fork / shallow fetch all the repo when cloning to set up for contributions from outside and inside the organization
pub fun download(name: string, url: string, repo-path: string, commit: git-ref)
  if repo-path != "" then 
    throw("Unsupported repo-path")
  match commit
    GitCommit(hash) -> 
      run("git clone --depth=1 \"" ++ url ++ "\"" ++ name)
      expose-branches()
      fetch-all(False)
      checkout(hash)
    GitBranch(b) ->
      run("git clone --depth=1 -b " ++ b ++ " " ++ url ++ " " ++ name)
      expose-branches()
      fetch-all()