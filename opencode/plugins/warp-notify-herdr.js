import { writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { basename } from "node:path";

// @warp-dot-dev/opencode-warp writes its OSC 777 to /dev/tty. Under Herdr that
// is the pane pty, whose Ghostty-based VT core parses OSC 9/777 into its own
// `show_desktop_notification` command and consumes it, so Warp never sees it.
// The herdr *client* process is the one attached to Warp's real pty, so emit
// there instead. Verified: OSC 777 to that pty renders Warp's native toast.
const NOTIFICATION_TITLE = "warp://cli-agent";

const resolveWarpTty = () => {
  try {
    const pids = execFileSync("pgrep", ["-x", "herdr"], { encoding: "utf8" })
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
    for (const pid of pids) {
      const tty = execFileSync("ps", ["-o", "tty=", "-p", pid], { encoding: "utf8" }).trim();
      if (tty && !tty.startsWith("?")) return `/dev/${tty}`;
    }
  } catch {}
  return null;
};

const truncate = (text, max) => (text.length > max ? `${text.slice(0, max - 1)}…` : text);

const extractText = (parts) =>
  (parts ?? [])
    .filter((part) => part?.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();

export const WarpNotifyHerdrPlugin = async ({ client, directory }) => {
  if (process.env.HERDR_ENV !== "1" || !process.env.WARP_CLI_AGENT_PROTOCOL_VERSION) {
    return {};
  }

  const warpTty = resolveWarpTty();
  if (!warpTty) return {};

  const cwd = directory || "";
  const project = cwd ? basename(cwd) : "";
  const protocolVersion = Math.min(
    Number.parseInt(process.env.WARP_CLI_AGENT_PROTOCOL_VERSION, 10) || 1,
    1
  );
  const childSessions = new Set();

  const notify = (event, sessionID, extra = {}) => {
    if (sessionID && childSessions.has(sessionID)) return;
    const body = JSON.stringify({
      v: protocolVersion,
      agent: "opencode",
      event,
      session_id: sessionID ?? "",
      cwd,
      project,
      ...extra,
    });
    try {
      writeFileSync(warpTty, `\x1b]777;notify;${NOTIFICATION_TITLE};${body}\x07`);
    } catch {}
  };

  const lastExchange = async (sessionID) => {
    if (!sessionID) return { query: "", response: "" };
    try {
      const result = await client.session.messages({ path: { id: sessionID } });
      const reversed = [...(result.data ?? [])].reverse();
      const user = reversed.find((message) => message.info.role === "user");
      const assistant = reversed.find((message) => message.info.role === "assistant");
      return {
        query: user ? truncate(extractText(user.parts), 200) : "",
        response: assistant ? truncate(extractText(assistant.parts), 200) : "",
      };
    } catch {
      return { query: "", response: "" };
    }
  };

  const permissionSummary = (properties) => {
    const tool = properties?.type || "unknown";
    const metadata = properties?.metadata ?? {};
    const preview = metadata.command ?? metadata.file_path ?? metadata.filePath ?? "";
    return preview ? `Wants to run ${tool}: ${truncate(String(preview), 120)}` : `Wants to run ${tool}`;
  };

  return {
    event: async ({ event }) => {
      const properties = event.properties ?? {};
      const info = properties.info;
      if (info?.id && info.parentID) childSessions.add(info.id);

      switch (event.type) {
        case "session.idle": {
          const sessionID = properties.sessionID;
          notify("stop", sessionID, await lastExchange(sessionID));
          return;
        }
        case "permission.asked":
        case "permission.updated": {
          notify("permission_request", properties.sessionID, {
            summary: permissionSummary(properties),
            tool_name: properties.type || "unknown",
          });
          return;
        }
        case "session.deleted": {
          if (info?.id) childSessions.delete(info.id);
          return;
        }
        default:
          return;
      }
    },

    "tool.execute.before": async (input) => {
      if (input.tool !== "question") return;
      notify("question_asked", input.sessionID, { tool_name: input.tool });
    },
  };
};
