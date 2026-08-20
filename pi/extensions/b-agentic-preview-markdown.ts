/**
 * Inline Markdown previews for Pi's TUI tool results.
 *
 * The preview is intentionally static: it never writes a file or changes
 * session messages. In non-TUI modes the tool returns a concise fallback.
 */
import { copyToClipboard, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Box, Markdown, Spacer, Text, truncateToWidth, type Component } from "@earendil-works/pi-tui";

type PreviewDetails = {
  markdown: string;
  title: string;
};

const DEFAULT_TITLE = "Markdown preview";
const PALETTE = {
  pageBg: "#18181e",
  cardBg: "#1e1e24",
  text: "#d4d4d4",
  accent: "#8abeb7",
  muted: "#808080",
  darkGray: "#505050",
  heading: "#f0c674",
  link: "#81a2be",
  codeBlock: "#b5bd68",
} as const;
const ANSI_RESET = "\u001b[0m";
const ANSI_FOREGROUND_RESET = "\u001b[39m";

function truecolor(mode: "38" | "48", hex: string): string {
  const value = Number.parseInt(hex.slice(1), 16);
  const red = (value >> 16) & 0xff;
  const green = (value >> 8) & 0xff;
  const blue = value & 0xff;
  return `\u001b[${mode};2;${red};${green};${blue}m`;
}

const FIXED_PAGE_BACKGROUND = truecolor("48", PALETTE.pageBg);
const FIXED_CARD_BACKGROUND = truecolor("48", PALETTE.cardBg);
const FIXED_BORDER = truecolor("38", PALETTE.darkGray);
const FIXED_HEADER = truecolor("38", PALETTE.accent);
const FIXED_TITLE = truecolor("38", PALETTE.text);
const FIXED_TEXT = truecolor("38", PALETTE.text);
const FIXED_MUTED = truecolor("38", PALETTE.muted);
const FIXED_HEADING = truecolor("38", PALETTE.heading);
const FIXED_LINK = truecolor("38", PALETTE.link);
const FIXED_CODE = truecolor("38", PALETTE.accent);
const FIXED_CODE_BLOCK = truecolor("38", PALETTE.codeBlock);
let lastPreviewMarkdown: string | undefined;

function fixedColor(color: string, text: string): string {
  return `${color}${text}${ANSI_FOREGROUND_RESET}`;
}

const FIXED_MARKDOWN_THEME = {
  heading: (text: string) => fixedColor(FIXED_HEADING, text),
  link: (text: string) => fixedColor(FIXED_LINK, text),
  linkUrl: (text: string) => fixedColor(FIXED_MUTED, text),
  code: (text: string) => fixedColor(FIXED_CODE, text),
  codeBlock: (text: string) => fixedColor(FIXED_CODE_BLOCK, text),
  codeBlockBorder: (text: string) => fixedColor(FIXED_MUTED, text),
  quote: (text: string) => fixedColor(FIXED_MUTED, text),
  quoteBorder: (text: string) => fixedColor(FIXED_MUTED, text),
  hr: (text: string) => fixedColor(FIXED_MUTED, text),
  listBullet: (text: string) => fixedColor(FIXED_HEADER, text),
  bold: (text: string) => fixedColor(FIXED_TITLE, text),
  italic: (text: string) => fixedColor(FIXED_TEXT, text),
  strikethrough: (text: string) => fixedColor(FIXED_MUTED, text),
  underline: (text: string) => fixedColor(FIXED_HEADER, text),
};

class PreviewCard implements Component {
  private readonly body: Box;

  constructor(body: Box) {
    this.body = body;
  }

  render(width: number): string[] {
    if (width < 3) return this.body.render(width);

    const innerWidth = width - 2;
    const bodyLines = this.body.render(innerWidth).map((line) => truncateToWidth(line, innerWidth, "", true));
    const pageLine = (line: string) => `${FIXED_PAGE_BACKGROUND}${line}${ANSI_RESET}`;
    const border = (left: string, right: string) =>
      pageLine(fixedColor(FIXED_BORDER, `${left}${"─".repeat(innerWidth)}${right}`));
    const framed = bodyLines.map(
      (line) =>
        `${FIXED_PAGE_BACKGROUND}${fixedColor(FIXED_BORDER, "│")}${line}${FIXED_PAGE_BACKGROUND}${fixedColor(FIXED_BORDER, "│")}${ANSI_RESET}`,
    );
    return [border("╭", "╮"), ...framed, border("╰", "╯")];
  }

  invalidate(): void {
    this.body.invalidate();
  }
}

function fallbackResult(mode: ExtensionContext["mode"]): {
  content: [{ type: "text"; text: string }];
  details: { interactive: false; mode: ExtensionContext["mode"] };
} {
  return {
    content: [{ type: "text", text: "Markdown preview is only available in Pi TUI mode." }],
    details: { interactive: false, mode },
  };
}

async function copyLatestPreviewSource(
  ctx: ExtensionContext,
  copy: (markdown: string) => Promise<void> = copyToClipboard,
): Promise<void> {
  if (lastPreviewMarkdown === undefined) {
    ctx.ui.notify("No Markdown preview source is available to copy", "warning");
    return;
  }

  try {
    await copy(lastPreviewMarkdown);
    ctx.ui.notify("Latest Markdown preview source copied to clipboard", "info");
  } catch {
    ctx.ui.notify("Failed to copy latest Markdown preview source to clipboard", "error");
  }
}

export default function bAgenticPreviewMarkdown(pi: ExtensionAPI): void {
  pi.registerShortcut("ctrl+shift+m", {
    description: "Copy the latest Markdown preview source",
    handler: (ctx) => copyLatestPreviewSource(ctx),
  });

  pi.registerTool({
    name: "preview_markdown",
    label: "Preview Markdown",
    description: "Render Markdown inline in the Pi TUI without writing a file.",
    promptSnippet: "Render Markdown inline in the Pi TUI without creating a file",
    promptGuidelines: [
      "Use preview_markdown when the user asks to preview Markdown in Pi; pass the original Markdown source, not rendered text or an image.",
      "Use preview_markdown for an inline TUI tool result; copy the original source afterward with ctrl+shift+m; it does not write files or mutate session messages.",
    ],
    parameters: {
      type: "object",
      properties: {
        markdown: { type: "string", description: "The original Markdown source to preview." },
        title: { type: "string", description: "Optional title shown above the preview." },
      },
      required: ["markdown"],
      additionalProperties: false,
    },
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const title = params.title?.trim() || DEFAULT_TITLE;
      if (ctx.mode !== "tui") return fallbackResult(ctx.mode);

      const result = {
        content: [{ type: "text", text: "Markdown preview rendered inline." }],
        details: { markdown: params.markdown, title } satisfies PreviewDetails,
      };
      lastPreviewMarkdown = params.markdown;
      return result;
    },
    renderResult(result, _options, _theme) {
      const details = result.details as PreviewDetails | undefined;
      if (!details || typeof details.markdown !== "string" || typeof details.title !== "string") {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }

      const body = new Box(1, 1, (line) => `${FIXED_CARD_BACKGROUND}${line}${ANSI_RESET}`);
      body.addChild(new Text(fixedColor(FIXED_HEADER, "MARKDOWN PREVIEW"), 0, 0));
      body.addChild(new Text(fixedColor(FIXED_TITLE, details.title), 0, 0));
      body.addChild(new Spacer(1));
      body.addChild(
        new Markdown(details.markdown, 0, 0, FIXED_MARKDOWN_THEME, {
          color: (text: string) => fixedColor(FIXED_TEXT, text),
        }),
      );
      body.addChild(new Spacer(1));
      body.addChild(new Text(fixedColor(FIXED_MUTED, "Ctrl+Shift+M  Copy source"), 0, 0));
      return new PreviewCard(body);
    },
  });
}

export const __test__ = {
  DEFAULT_TITLE,
  copyLatestPreviewSource,
  fallbackResult,
};
