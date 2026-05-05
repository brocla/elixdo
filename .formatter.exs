[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/*/migrations"],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/*/seeds.exs"]
]

# The HEEx formatter is deliberatly disabled 
#   because it keeps expanding single-line <span> tags 
#   into multi-line blocks, which injects literal whitespace 
#   into pre-wrap elements and causes a blank-line bug.
