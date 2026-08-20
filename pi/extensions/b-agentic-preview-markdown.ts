/**
 * Inline Markdown previews for Pi's TUI tool results.
 *
 * The preview is intentionally static: it never writes a file or changes
 * session messages. In non-TUI modes the tool returns a concise fallback.
 */
import { getMarkdownTheme, type ExtensionAPI, type ExtensionContext, type Theme } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";

type PreviewDetails = {
  markdown: string;
  title: string;
};

const DEFAULT_TITLE = "Markdown preview";
const SOURCE_LABEL = "Original Markdown source";

function fallbackResult(mode: ExtensionContext["mode"]): {
  content: [{ type: "text"; text: string }];
  details: { interactive: false; mode: ExtensionContext["mode"] };
} {
  return {
    content: [{ type: "text", text: "Markdown preview is only available in Pi TUI mode." }],
    details: { interactive: false, mode },
  };
}

export default function bAgenticPreviewMarkdown(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "preview_markdown",
    label: "Preview Markdown",
    description: "Render Markdown inline in the Pi TUI without writing a file.",
    promptSnippet: "Render Markdown inline in the Pi TUI without creating a file",
    promptGuidelines: [
      "Use preview_markdown when the user asks to preview Markdown in Pi; pass the original Markdown source, not rendered text or an image.",
      "Use preview_markdown for an inline TUI tool result with the original source shown beneath; it does not write files or mutate session messages.",
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

      return {
        content: [{ type: "text", text: "Markdown preview rendered inline." }],
        details: { markdown: params.markdown, title } satisfies PreviewDetails,
      };
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
      content.addChild(new Spacer(1));
      content.addChild(new Text(theme.fg("muted", SOURCE_LABEL), 0, 0));
      content.addChild(new Text(details.markdown, 0, 0));
      return content;
    },
  });
}

export const __test__ = {
  DEFAULT_TITLE,
  SOURCE_LABEL,
  fallbackResult,
};
