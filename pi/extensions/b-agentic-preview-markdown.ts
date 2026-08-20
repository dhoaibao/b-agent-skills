/**
 * Inline Markdown previews for Pi's TUI tool results.
 *
 * The preview is intentionally static: it never writes a file or changes
 * session messages. In non-TUI modes the tool returns a concise fallback.
 */
import { copyToClipboard, getMarkdownTheme, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";

type PreviewDetails = {
  markdown: string;
  title: string;
};

const DEFAULT_TITLE = "Markdown preview";
let lastPreviewMarkdown: string | undefined;

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
    renderResult(result, _options, theme) {
      const details = result.details as PreviewDetails | undefined;
      if (!details || typeof details.markdown !== "string" || typeof details.title !== "string") {
        const text = result.content[0];
        return new Text(text?.type === "text" ? text.text : "", 0, 0);
      }

      const content = new Container();
      content.addChild(new Text(theme.fg("toolTitle", theme.bold(details.title)), 0, 0));
      content.addChild(new Spacer(1));
      content.addChild(
        new Markdown(details.markdown, 0, 0, getMarkdownTheme(), {
          color: (text: string) => theme.fg("text", text),
        }),
      );
      return content;
    },
  });
}

export const __test__ = {
  DEFAULT_TITLE,
  copyLatestPreviewSource,
  fallbackResult,
};
