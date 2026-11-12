# Run, debug and test

Start from your project's directory or pass it to `start-webstorm.cmd`. Nothing runs automatically on project open.

## Scripts and output

Space rr selects a package.json script; Space rd runs dev/start/serve, Space rs stops it. The runner selects pnpm, yarn, bun or npm by lockfile. Its terminal holds process output; compiler output is not automatically parsed into quickfix. Space th opens another terminal; Ctrl+\ Ctrl+N exits Terminal mode.

## Jest and Vitest

Install the test framework in the project, and install the relevant Treesitter parsers with `:TSInstall javascript typescript tsx`. Space tn runs the nearest test, Space tf the current file, Space tT the current working directory, Space tS opens results, Space to opens output, and Space tq stops a run. Adapter selection checks the nearest package.json; a package declaring both chooses Vitest. In a monorepo, declare the framework in the package containing the tests or adjust the adapter root logic. Parameterized test discovery depends on adapter support.

## Node and browser debugging

Mason's js-debug-adapter and Node must be installed. Space db toggles a breakpoint, Space dB sets a conditional breakpoint, F9 resumes, F8 steps over, F7 steps in, Shift+F8 steps out (Space db and F5/F10/F11 are fallbacks), Space du toggles scopes, watches and stack UI, Space de evaluates an expression and Space dx terminates. Select **Launch current file** for executable JavaScript, or start Node with `--inspect=9229` and select **Attach to :9229**. TypeScript requires an appropriate runtime or compiled JavaScript and source maps; debugging a raw TS file is not universally supported.

For browser code, start the development server yourself, choose **Launch Chrome**, and supply its URL. The adapter needs Chrome and project source maps. Browser launch, source map accuracy and interactive stepping have not been verified in this environment. Breakpoint, variable, console and browser behavior depend on the program and runtime; use the DAP UI to inspect the session.
