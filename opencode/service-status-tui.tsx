/** @jsxImportSource @opentui/solid */
import { basename } from "node:path";
import { createSignal, For, onCleanup, Show } from "solid-js";

const pollIntervalMs = 3_000;

const run = async (command, args) => {
  const child = Bun.spawn([command, ...args], {
    stdout: "pipe",
    stderr: "ignore",
  });
  const output = await new Response(child.stdout).text();
  if ((await child.exited) !== 0) throw new Error(`${command} failed`);
  return output;
};

const parseListeners = (output) => {
  const listeners = new Map();
  let pid;

  for (const line of output.split("\n")) {
    if (line.startsWith("p")) {
      pid = Number.parseInt(line.slice(1), 10);
      continue;
    }
    if (!pid || !line.startsWith("n")) continue;

    const match = line.match(/:(\d+)$/);
    if (match) listeners.set(Number.parseInt(match[1], 10), pid);
  }

  return listeners;
};

const processCommands = async (pids) => {
  if (pids.length === 0) return new Map();

  let output;
  try {
    output = await run("ps", ["-p", pids.join(","), "-o", "pid=,command="]);
  } catch {
    return new Map();
  }
  return new Map(
    output
      .split("\n")
      .map((line) => line.match(/^\s*(\d+)\s+(.+)$/))
      .filter(Boolean)
      .map((match) => [Number.parseInt(match[1], 10), match[2]]),
  );
};

const worktreeName = async (pid) => {
  let cwdOutput;
  try {
    cwdOutput = await run("lsof", [
      "-a",
      "-p",
      String(pid),
      "-d",
      "cwd",
      "-Fn",
    ]);
  } catch {
    return "unknown";
  }
  const cwd = cwdOutput
    .split("\n")
    .find((line) => line.startsWith("n"))
    ?.slice(1);
  if (!cwd) return "unknown";

  try {
    const branch = (
      await run("git", ["-C", cwd, "branch", "--show-current"])
    ).trim();
    if (branch) return branch;
  } catch {}

  return basename(cwd);
};

export const detectServices = async () => {
  let listeners;
  try {
    listeners = parseListeners(
      await run("lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpn"]),
    );
  } catch {
    return [];
  }

  const commands = await processCommands([...new Set(listeners.values())]);
  const services = [];

  for (const [port, pid] of listeners) {
    const command = commands.get(pid)?.toLowerCase() ?? "";
    let name;

    if (port === 9200 && command.includes("elasticsearch")) name = "ES";
    else if (port >= 5601 && port < 5700 && command.includes("/scripts/kibana"))
      name = "Kibana";
    else if (port >= 9000 && port < 9100 && command.includes("storybook"))
      name = "Storybook";
    else continue;

    services.push({
      port,
      name,
      worktree: name === "ES" ? undefined : await worktreeName(pid),
    });
  }

  return services.sort((a, b) => a.port - b.port);
};

const ServiceStatus = ({ theme }) => {
  const [services, setServices] = createSignal([]);
  const [open, setOpen] = createSignal(true);
  let disposed = false;
  let timer;

  const refresh = async () => {
    try {
      const next = await detectServices();
      if (!disposed) setServices(next);
    } finally {
      if (!disposed) timer = setTimeout(refresh, pollIntervalMs);
    }
  };

  void refresh();
  onCleanup(() => {
    disposed = true;
    clearTimeout(timer);
  });

  return (
    <box flexDirection="column">
      <box
        flexDirection="row"
        gap={1}
        onMouseDown={() => setOpen((value) => !value)}
      >
        <text fg={theme.current.text}>{open() ? "▼" : "▶"}</text>
        <text fg={theme.current.text}>
          <b>Services</b>
        </text>
      </box>
      <Show when={open()}>
        <For each={services()}>
          {(service) => (
            <box flexDirection="row" gap={1}>
              <text flexShrink={0} fg={theme.current.success}>
                •
              </text>
              <text fg={theme.current.textMuted} wrapMode="word">
                <a
                  href={`http://localhost:${service.port}`}
                  style={{ fg: theme.current.primary }}
                >
                  {service.port}
                </a>{" "}
                - {service.name}
                {service.worktree ? ` ${service.worktree}` : ""}
              </text>
            </box>
          )}
        </For>
      </Show>
    </box>
  );
};

const plugin = {
  id: "local.service-status",
  tui: async (api) => {
    api.slots.register({
      order: 250,
      slots: {
        sidebar_content: (context) => <ServiceStatus theme={context.theme} />,
      },
    });
  },
};

export default plugin;
