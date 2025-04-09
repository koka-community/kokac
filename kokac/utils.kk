extern import
  c file "utils.c"

extern file_modified(path: string): fsys maybe<int>
  c "kk_file_modified"