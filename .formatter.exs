[
  import_deps: [:ecto, :phoenix],
  inputs: [
    "*.{ex,exs}",
    "{config,lib,test,bench}/**/*.{ex,exs}",
    "priv/repo/*.{ex,exs}"
  ],
  subdirectories: ["priv/**/migrations/*.{ex,exs}"]
]
