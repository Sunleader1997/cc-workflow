#!/usr/bin/env node
// cc-workflow CLI entry point
// Starts the FastAPI backend with embedded frontend static files

const { spawn, execSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

const BACKEND_DIR = path.resolve(__dirname, "..", "backend");
const STATIC_DIR = path.resolve(__dirname, "..", "frontend", "dist");
const REQUIREMENTS = path.resolve(BACKEND_DIR, "requirements.txt");

function log(msg) {
  console.log(`[cc-workflow] ${msg}`);
}

function error(msg) {
  console.error(`[cc-workflow] ERROR: ${msg}`);
  process.exit(1);
}

function checkPython() {
  const candidates = ["python3", "python"];
  for (const cmd of candidates) {
    try {
      execSync(`${cmd} --version`, { stdio: "pipe" });
      return cmd;
    } catch {}
  }
  error("Python 3 is required but not found. Please install Python 3.10+ and ensure 'python3' or 'python' is in PATH.");
}

function checkPip(pythonCmd) {
  const candidates = [`${pythonCmd} -m pip`, "pip3", "pip"];
  for (const cmd of candidates) {
    try {
      execSync(`${cmd} --version`, { stdio: "pipe" });
      return cmd;
    } catch {}
  }
  error("pip is required but not found.");
}

function ensurePythonDeps(pythonCmd, pipCmd) {
  const marker = path.join(BACKEND_DIR, ".deps_installed");
  const requirementsContent = fs.readFileSync(REQUIREMENTS, "utf-8");

  // Check if already installed and marker matches requirements hash
  let currentHash = "";
  if (fs.existsSync(marker)) {
    try {
      currentHash = fs.readFileSync(marker, "utf-8").trim();
    } catch {}
  }

  const crypto = require("crypto");
  const expectedHash = crypto.createHash("sha256").update(requirementsContent).digest("hex");

  if (currentHash === expectedHash) {
    log("Python dependencies already installed.");
    return;
  }

  // Check for offline wheels directory
  const wheelsDir = path.join(BACKEND_DIR, "wheels");
  const hasWheels = fs.existsSync(wheelsDir) && fs.readdirSync(wheelsDir).some(f => f.endsWith(".whl"));

  if (hasWheels) {
    log("Installing Python dependencies from offline wheels...");
    try {
      execSync(`${pipCmd} install --no-index --find-links "${wheelsDir}" -r "${REQUIREMENTS}"`, {
        stdio: "inherit",
        cwd: BACKEND_DIR,
      });
      fs.writeFileSync(marker, expectedHash);
      log("Python dependencies installed from wheels.");
      return;
    } catch (e) {
      error(`Failed to install from offline wheels: ${e.message}`);
    }
  }

  log("Installing Python dependencies from PyPI...");
  try {
    execSync(`${pipCmd} install -r "${REQUIREMENTS}"`, {
      stdio: "inherit",
      cwd: BACKEND_DIR,
    });
    fs.writeFileSync(marker, expectedHash);
    log("Python dependencies installed.");
  } catch (e) {
    error(
      `Failed to install Python dependencies: ${e.message}\n\n` +
      `For offline installation, pre-download wheels:\n` +
      `  pip download -r backend/requirements.txt -d backend/wheels/\n` +
      `Then reinstall the package.`
    );
  }
}

function parseArgs() {
  const args = process.argv.slice(2);
  const result = { port: 9800, host: "0.0.0.0", background: false, help: false };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "-p" || arg === "--port") {
      result.port = parseInt(args[++i], 10);
    } else if (arg === "-h" || arg === "--host") {
      result.host = args[++i];
    } else if (arg === "-d" || arg === "--background") {
      result.background = true;
    } else if (arg === "--help" || arg === "-?") {
      result.help = true;
    } else if (arg.startsWith("--port=")) {
      result.port = parseInt(arg.split("=")[1], 10);
    } else if (arg.startsWith("--host=")) {
      result.host = arg.split("=")[1];
    }
  }
  return result;
}

function showHelp() {
  console.log(`
cc-workflow - Claude Code Workflow Orchestrator

Usage: cc-workflow [options]

Options:
  -p, --port <port>     Server port (default: 9800)
  -h, --host <host>     Server host (default: 0.0.0.0)
  -d, --background      Run in background
      --help            Show this help message

Examples:
  cc-workflow                    # Start on default port 9800
  cc-workflow -p 8080            # Start on port 8080
  cc-workflow -d                 # Run in background

The server will be available at http://<host>:<port>
`);
  process.exit(0);
}

function openBrowser(url) {
  const platform = os.platform();
  const cmd =
    platform === "darwin" ? "open" :
    platform === "win32" ? "start" :
    "xdg-open";
  try {
    spawn(cmd, [url], { detached: true, stdio: "ignore" }).unref();
  } catch {
    // Silently fail if browser can't be opened
  }
}

function main() {
  const opts = parseArgs();
  if (opts.help) showHelp();

  // Verify static files exist
  if (!fs.existsSync(STATIC_DIR)) {
    error(
      `Frontend build not found at ${STATIC_DIR}.\n` +
      `Please run 'npm run build' in the frontend directory first.`
    );
  }

  const pythonCmd = checkPython();
  const pipCmd = checkPip(pythonCmd);
  ensurePythonDeps(pythonCmd, pipCmd);

  log(`Starting server on ${opts.host}:${opts.port}...`);

  const env = {
    ...process.env,
    CC_WORKFLOW_STATIC_DIR: STATIC_DIR,
    CC_WORKFLOW_PORT: String(opts.port),
    CC_WORKFLOW_HOST: opts.host,
  };

  const uvicornArgs = [
    "-m", "uvicorn",
    "app:app",
    "--host", opts.host,
    "--port", String(opts.port),
  ];

  const child = spawn(pythonCmd, uvicornArgs, {
    cwd: BACKEND_DIR,
    env,
    stdio: opts.background ? "ignore" : "inherit",
    detached: opts.background,
  });

  if (opts.background) {
    child.unref();
    log(`Server started in background (PID: ${child.pid})`);
    log(`Access at http://${opts.host === "0.0.0.0" ? "localhost" : opts.host}:${opts.port}`);
    process.exit(0);
  }

  // Give uvicorn a moment to start, then open browser
  setTimeout(() => {
    const url = `http://${opts.host === "0.0.0.0" ? "localhost" : opts.host}:${opts.port}`;
    openBrowser(url);
  }, 1200);

  child.on("exit", (code) => {
    process.exit(code ?? 0);
  });

  process.on("SIGINT", () => {
    log("Shutting down...");
    child.kill("SIGINT");
  });

  process.on("SIGTERM", () => {
    child.kill("SIGTERM");
  });
}

main();
