/*----------------------------------------------------------------------------
   Copyright 2024, Koka-Community Authors

   Licensed under the MIT License ("The License"). You may not
   use this file except in compliance with the License. A copy of the License
   can be found in the LICENSE file at the root of this distribution.
----------------------------------------------------------------------------*/
module kokac/config
import kokac/package
import kokac/git
import std/os/path

pub effect package-config
  fun set-dependencies(deps: list<dependency>): ()
  fun set-dev-dependencies(deps: list<dependency>): ()
  fun set-scripts(scripts: list<script>): ()
  fun set-compiler(compiler: compiler): ()
  fun set-resolution(resolution: resolution): ()
  fun get-dependencies(): list<dependency>
  fun get-dev-dependencies(): list<dependency>
  fun get-scripts(): list<script>
  fun get-compiler(): compiler
  fun get-resolution(): resolution

pub fun default-package-config(f)
  var deps := []
  var scripts := []
  var dev-deps := []
  var compiler := Default
  var resolution := Local
  with handler
    fun set-dependencies(deps_new) deps := deps_new
    fun set-dev-dependencies(dev-deps_new) dev-deps := dev-deps_new
    fun set-scripts(scripts_new) scripts := scripts_new
    fun set-compiler(compiler_new) compiler := compiler_new
    fun set-resolution(resolution_new) resolution := resolution_new
    fun get-dependencies() deps
    fun get-dev-dependencies() dev-deps
    fun get-scripts() scripts
    fun get-compiler() compiler
    fun get-resolution() resolution
  f()

effect dependencies
  fun add-dep(d: dependency): ()

pub fun dependencies(f)
  var deps := []
  with fun add-dep(d) deps := Cons(d, deps)
  f()
  set-dependencies(deps)

pub fun simple/dep(name: string, git: () -> string)
  add-dep(Dependency(name, GitDep(git(), "", GitDefault)))

pub effect scripts
  fun script(name: string, command: () -> string): ()

pub fun scripts(f)
  var scripts := []
  with fun script(name, command) scripts := Cons(Script(name, command()), scripts)
  f()
  set-scripts(scripts)

pub fun install-location(s: string): <package-config> ()
  set-resolution(Global(s.path))

pub fun compiler(comp)
  set-compiler(comp)
