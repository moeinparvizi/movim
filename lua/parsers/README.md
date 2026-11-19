# Bundled Angular Tree-sitter parsers

These shared libraries are built from `tree-sitter-angular` revision
`38a8014ed5452cd6b7cf1399c00177a1f5374256`, using `src/parser.c` and
`src/scanner.c`. The upstream MIT license is in `ANGULAR-LICENSE.txt`.
They allow updates to provide template highlighting without downloading a
compiler or replacing a user's installed parsers. Neovim falls back to its
HTML parser on unsupported platforms.

Build each target with `zig cc -shared -O1 -I src src/parser.c src/scanner.c`
and the appropriate Zig target (`x86_64-windows`, `x86_64-linux-gnu`,
`aarch64-linux-gnu`, `x86_64-macos`, or `aarch64-macos`). The output is named
`angular.so` even on Windows, as expected by Neovim's parser loader.
