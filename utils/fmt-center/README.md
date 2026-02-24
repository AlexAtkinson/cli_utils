fmt-center
==========

Center a short string on the terminal line.

Usage:

  fmt-center [--width N] <text...>

If no positional argument is provided, `fmt-center` will read text from stdin.

Examples:

  fmt-center "hello world"
  echo "hello" | fmt-center
  fmt-center --width 20 "hello world"
