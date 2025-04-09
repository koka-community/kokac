import std/os/path
import std/os/dir

extern import
  c file "utils.c"

extern string/file_modified(path: string): fsys maybe<int>
  c "kk_file_modified"

pub fun path/file_modified(p: path): <fsys,exn> int
  p.string.file_modified.unjust

pub fun find-package-root(file: path): io path
  if file.dirname == file.string || file.dirname == "" then
    throw("Couldn't find the package path")
  else
    val pkg-path = file.dirname 
    if is-file(pkg-path / "package.kk") then
      pkg-path.path
    else
      find-package-root(file.dirname.path)

pub fun path/(==)(p1: path, p2: path): bool
  p1.string == p2.string

pub fun relative-path(p: path, base: path): io path 
  // println("relative-path " ++ p.string ++ " " ++ base.string)
  val pparts = p.realpath.dirparts
  val bparts = base.realpath.dirparts
  fun go(b': list<string>, p': list<string>)
    match (b', p')
      (Nil, _) -> p'
      (_, Nil) -> throw("Cannot find relative path " ++ p.string.show ++ " " ++ base.string.show)
      (Cons(bh, bt), Cons(ph, pt)) ->
        if bh == ph then
          go(bt, pt)
        else
          throw("Cannot find relative path " ++ p.string.show ++ " " ++ base.string.show)
  // println("relative-path2 " ++ p.string ++ " " ++ base.string)
  go(bparts, pparts).foldl("".path, fn(acc, x) acc / x)