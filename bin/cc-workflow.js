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
const PID_DIR = path.join(os.homedir(), ".cc-workflow");
const PID_FILE = path.join(PID_DIR, "pid");

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

function savePid(pid) {
  try {
    fs.mkdirSync(PID_DIR, { recursive: true });
    fs.writeFileSync(PID_FILE, String(pid));
  } catch (e) {
    // Non-critical: PID file is only for convenience
  }
}

function readPid() {
  try {
    return parseInt(fs.readFileSync(PID_FILE, "utf-8").trim(), 10);
  } catch {
    return null;
  }
}

function clearPid() {
  try {
    fs.unlinkSync(PID_FILE);
  } catch {}
}

function isProcessRunning(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function findProcessByPort(port) {
  const platform = os.platform();
  try {
    if (platform === "darwin" || platform === "linux") {
      const output = execSync(`lsof -ti:${port}`, { encoding: "utf-8", stdio: ["pipe", "pipe", "ignore"] });
      const pids = output.trim().split("\n").map(s => parseInt(s.trim(), 10)).filter(n => !isNaN(n));
      return pids.length > 0 ? pids : null;
    } else if (platform === "win32") {
      const output = execSync(`netstat -ano | findstr :${port}`, { encoding: "utf-8", stdio: ["pipe", "pipe", "ignore"] });
      const lines = output.trim().split("\n").filter(l => l.includes("LISTENING"));
      const pids = lines.map(l => {
        const parts = l.trim().split(/\s+/);
        return parseInt(parts[parts.length - 1], 10);
      }).filter(n => !isNaN(n));
      return pids.length > 0 ? pids : null;
    }
  } catch {
    return null;
  }
}

function cmdStart(args) {
  const opts = { port: 9800, host: "0.0.0.0", background: false };
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "-p" || arg === "--port") {
      opts.port = parseInt(args[++i], 10);
    } else if (arg === "-h" || arg === "--host") {
      opts.host = args[++i];
    } else if (arg === "-d" || arg === "--background") {
      opts.background = true;
    } else if (arg.startsWith("--port=")) {
      opts.port = parseInt(arg.split("=")[1], 10);
    } else if (arg.startsWith("--host=")) {
      opts.host = arg.split("=")[1];
    }
  }

  // Check if already running
  const existingPid = readPid();
  if (existingPid && isProcessRunning(existingPid)) {
    log(`Server already running (PID: ${existingPid})`);
    log(`Access at http://${opts.host === "0.0.0.0" ? "localhost" : opts.host}:${opts.port}`);
    process.exit(0);
  }

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

  savePid(child.pid);

  if (opts.background) {
    child.unref();
    log(`Server started in background (PID: ${child.pid})`);
    log(`Access at http://${opts.host === "0.0.0.0" ? "localhost" : opts.host}:${opts.port}`);
    log(`Stop with: cc-workflow stop`);
    process.exit(0);
  }

  setTimeout(() => {
    const url = `http://${opts.host === "0.0.0.0" ? "localhost" : opts.host}:${opts.port}`;
    openBrowser(url);
  }, 1200);

  child.on("exit", (code) => {
    clearPid();
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

function cmdStop() {
  const pid = readPid();
  let killed = false;

  if (pid && isProcessRunning(pid)) {
    try {
      process.kill(pid, "SIGTERM");
      killed = true;
      log(`Stopped process (PID: ${pid})`);
    } catch (e) {
      log(`Failed to stop PID ${pid}: ${e.message}`);
    }
  }

  // Fallback: find by port
  const port = process.env.CC_WORKFLOW_PORT || "9800";
  const pids = findProcessByPort(port);
  if (pids) {
    for (const p of pids) {
      if (p === pid) continue; // Already handled
      try {
        process.kill(p, "SIGTERM");
        killed = true;
        log(`Stopped process on port ${port} (PID: ${p})`);
      } catch {}
    }
  }

  clearPid();

  if (!killed) {
    log("No running server found.");
  }
}

function cmdStatus() {
  const pid = readPid();
  if (pid && isProcessRunning(pid)) {
    log(`Server is running (PID: ${pid})`);
    process.exit(0);
  }

  const port = process.env.CC_WORKFLOW_PORT || "9800";
  const pids = findProcessByPort(port);
  if (pids) {
    log(`Server is running on port ${port} (PID: ${pids.join(", ")})`);
    process.exit(0);
  }

  log("Server is not running.");
  process.exit(1);
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

function showHelp() {
  console.log(`
cc-workflow - Claude Code Workflow Orchestrator

Usage: cc-workflow <command> [options]

Commands:
  start [options]       Start the server (default command)
  stop                  Stop the running server
  status                Check if server is running
  --help                Show this help message

Start Options:
  -p, --port <port>     Server port (default: 9800)
  -h, --host <host>     Server host (default: 0.0.0.0)
  -d, --background      Run in background

Examples:
  cc-workflow                    # Start on default port 9800
  cc-workflow start -p 8080      # Start on port 8080
  cc-workflow start -d           # Run in background
  cc-workflow stop               # Stop the server
  cc-workflow status             # Check server status
`);
  process.exit(0);
}

function main() {
  const args = process.argv.slice(2);

  if (args.includes("--help") || args.includes("-?")) {
    showHelp();
    return;
  }

  const command = args[0];

  if (!command || command.startsWith("-")) {
    // No command or starts with flag → default to start
    cmdStart(args);
    return;
  }

  switch (command) {
    case "start":
      cmdStart(args.slice(1));
      break;
    case "stop":
      cmdStop();
      break;
    case "status":
      cmdStatus();
      break;
    case "--help":
    case "-?":
    case "help":
      showHelp();
      break;
    default:
      error(`Unknown command: ${command}\nRun 'cc-workflow --help' for usage.`);
  }
}

main();
