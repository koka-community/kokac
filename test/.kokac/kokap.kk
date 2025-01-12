
  import package
  import kokac/config
  import kokac/kokac
  fun main()
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
      fun get-dependencies(): deps
      fun get-dev-dependencies(): dev-deps
      fun get-scripts(): scripts
      fun get-compiler(): compiler
      fun get-resolution(): resolution
    val args = get-args()
    // Split the file from the rest of the arguments so we can resolve the package from the file
    val file = args.filter(fn(a) a.starts-with("-").is-nothing && a.starts-with("--").is-nothing)
    match file
      Cons(f, Nil) -> 
        run((cwd() / f).realpath, args)
      _ -> 
        run-langserver(args) // Just passthrough the arguments using the cwd as location to resolve package file from.
    