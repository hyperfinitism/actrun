// WASI Runner Worker for Deno Deploy
// Executes WASM+WASI modules in a serverless environment.
//
// Endpoints:
//   POST /run    - Execute a WASM module with WASI P1 support
//   POST /plan   - Parse workflow YAML and return execution plan
//   GET  /health - Health check
//
// Usage:
//   deno run --allow-all workers/wasi-worker.ts         # local
//   deployctl deploy --project=actrun workers/wasi-worker.ts  # deploy

// --- Minimal WASI P1 Implementation (inline, no file dependency) ---

class WasiP1Runner {
  private memory!: WebAssembly.Memory;
  private fds = new Map<number, { path?: string; data: Uint8Array; offset: number }>();
  private nextFd = 3;
  private env: Record<string, string>;
  private stdoutBuf: Uint8Array[] = [];
  private stderrBuf: Uint8Array[] = [];
  private outputEntries: Record<string, string> = {};
  private exitCode = 0;

  constructor(env: Record<string, string>) {
    this.env = env;
    // fd 0=stdin, 1=stdout, 2=stderr
    this.fds.set(0, { data: new Uint8Array(), offset: 0 });
    this.fds.set(1, { data: new Uint8Array(), offset: 0 });
    this.fds.set(2, { data: new Uint8Array(), offset: 0 });
  }

  setMemory(mem: WebAssembly.Memory) { this.memory = mem; }

  getStdout(): string { return new TextDecoder().decode(concatBuffers(this.stdoutBuf)); }
  getStderr(): string { return new TextDecoder().decode(concatBuffers(this.stderrBuf)); }
  getOutputs(): Record<string, string> { return this.outputEntries; }
  getExitCode(): number { return this.exitCode; }

  private view() { return new DataView(this.memory.buffer); }
  private u8() { return new Uint8Array(this.memory.buffer); }
  private encoder = new TextEncoder();

  getImports(): WebAssembly.Imports {
    return {
      wasi_snapshot_preview1: {
        args_get: () => 0,
        args_sizes_get: (argc: number, argv_buf: number) => {
          this.view().setUint32(argc, 0, true);
          this.view().setUint32(argv_buf, 0, true);
          return 0;
        },
        environ_get: (environ: number, buf: number) => {
          const entries = Object.entries(this.env);
          let offset = buf;
          for (let i = 0; i < entries.length; i++) {
            this.view().setUint32(environ + i * 4, offset, true);
            const s = this.encoder.encode(`${entries[i][0]}=${entries[i][1]}\0`);
            this.u8().set(s, offset);
            offset += s.length;
          }
          return 0;
        },
        environ_sizes_get: (count: number, size: number) => {
          const entries = Object.entries(this.env);
          let total = 0;
          for (const [k, v] of entries) total += k.length + 1 + v.length + 1;
          this.view().setUint32(count, entries.length, true);
          this.view().setUint32(size, total, true);
          return 0;
        },
        fd_write: (fd: number, iovs: number, iovsLen: number, nwritten: number) => {
          let written = 0;
          for (let i = 0; i < iovsLen; i++) {
            const ptr = this.view().getUint32(iovs + i * 8, true);
            const len = this.view().getUint32(iovs + i * 8 + 4, true);
            const data = this.u8().slice(ptr, ptr + len);
            if (fd === 1) this.stdoutBuf.push(data);
            else if (fd === 2) this.stderrBuf.push(data);
            else {
              // File write — parse as GITHUB_OUTPUT-style key=value
              const text = new TextDecoder().decode(data);
              for (const line of text.split("\n")) {
                const eq = line.indexOf("=");
                if (eq > 0) {
                  this.outputEntries[line.substring(0, eq)] = line.substring(eq + 1);
                }
              }
            }
            written += len;
          }
          this.view().setUint32(nwritten, written, true);
          return 0;
        },
        fd_read: () => 0,
        fd_close: () => 0,
        fd_seek: () => 0,
        fd_fdstat_get: (fd: number, buf: number) => {
          this.view().setUint8(buf, fd <= 2 ? 2 : 4);
          this.view().setUint16(buf + 2, 0, true);
          this.view().setBigUint64(buf + 8, 0n, true);
          this.view().setBigUint64(buf + 16, 0n, true);
          return 0;
        },
        fd_prestat_get: (_fd: number, _buf: number) => 8, // EBADF — no preopens
        fd_prestat_dir_name: () => 8,
        path_open: (dirfd: number, _: number, pathPtr: number, pathLen: number,
                     __: number, ___: bigint, ____: bigint, _____: number, fdPtr: number) => {
          // Virtual file open: create a new fd for writing outputs
          const newFd = this.nextFd++;
          this.fds.set(newFd, { data: new Uint8Array(), offset: 0 });
          this.view().setUint32(fdPtr, newFd, true);
          return 0;
        },
        clock_time_get: (_: number, __: bigint, ptr: number) => {
          this.view().setBigUint64(ptr, BigInt(Date.now()) * 1000000n, true);
          return 0;
        },
        proc_exit: (code: number) => { this.exitCode = code; throw new WasiExit(code); },
        sched_yield: () => 0,
        random_get: (buf: number, len: number) => {
          crypto.getRandomValues(this.u8().subarray(buf, buf + len));
          return 0;
        },
        poll_oneoff: () => 0,
        path_filestat_get: () => 8,
        path_create_directory: () => 0,
        path_remove_directory: () => 0,
        path_unlink_file: () => 0,
        path_rename: () => 0,
        fd_readdir: () => 0,
        fd_filestat_get: () => 0,
      },
    };
  }
}

class WasiExit extends Error {
  constructor(public code: number) { super(`exit(${code})`); }
}

function concatBuffers(bufs: Uint8Array[]): Uint8Array {
  const total = bufs.reduce((s, b) => s + b.length, 0);
  const result = new Uint8Array(total);
  let offset = 0;
  for (const buf of bufs) { result.set(buf, offset); offset += buf.length; }
  return result;
}

// --- HTTP Handler ---

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  if (url.pathname === "/health") {
    return Response.json({ status: "ok", runtime: "deno", wasi: true });
  }

  if (url.pathname === "/run" && req.method === "POST") {
    try {
      const body = await req.json();
      const { module_url, module_bytes_base64, env = {}, inputs = {} } = body;

      // Build WASI env
      const wasiEnv: Record<string, string> = { ...env };
      for (const [k, v] of Object.entries(inputs)) {
        wasiEnv[`INPUT_${k.toUpperCase()}`] = v as string;
      }

      // Get module bytes
      let bytes: Uint8Array;
      if (module_bytes_base64) {
        bytes = Uint8Array.from(atob(module_bytes_base64), c => c.charCodeAt(0));
      } else if (module_url) {
        const resp = await fetch(module_url);
        if (!resp.ok) return Response.json({ error: `fetch failed: ${resp.status}` }, { status: 400 });
        bytes = new Uint8Array(await resp.arrayBuffer());
      } else {
        return Response.json({ error: "module_url or module_bytes_base64 required" }, { status: 400 });
      }

      // Compile and run
      const module = await WebAssembly.compile(bytes);
      const runner = new WasiP1Runner(wasiEnv);
      const instance = await WebAssembly.instantiate(module, runner.getImports());
      runner.setMemory(instance.exports.memory as WebAssembly.Memory);

      let exitCode = 0;
      try {
        (instance.exports._start as Function)();
      } catch (e) {
        if (e instanceof WasiExit) {
          exitCode = e.code;
        } else {
          return Response.json({ error: String(e) }, { status: 500 });
        }
      }

      return Response.json({
        status: exitCode === 0 ? "success" : "failed",
        exit_code: exitCode,
        stdout: runner.getStdout(),
        stderr: runner.getStderr(),
        outputs: runner.getOutputs(),
      });
    } catch (e) {
      return Response.json({ error: String(e) }, { status: 500 });
    }
  }

  return new Response("actrun wasi-worker\n\nPOST /run - execute WASM module\nGET /health - status\n");
});
