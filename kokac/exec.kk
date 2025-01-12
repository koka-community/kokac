/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/exec
import std/os/process
import std/os/path

pub effect val current-dir: path

pub fun run(command : string): <current-dir,io> ()
  val real-command = "cd \"" ++ current-dir.string ++ "\" && " ++ command
  match run-system-read(real-command)
    Ok -> ()
    Error(err) -> throw("Command failed: " ++ real-command ++ "\n\t" ++ err.show)

pub fun run-result(command : string): <current-dir,io> int
  val real-command = "cd \"" ++ current-dir.string ++ "\" && " ++ command
  run-system(real-command)
