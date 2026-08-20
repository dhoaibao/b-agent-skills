/**
 * Direct in-session Markdown previews for Pi's TUI.
 *
 * The preview is intentionally ephemeral: it never writes a file or changes
 * session messages. In non-TUI modes the tool returns a concise fallback.
 */
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import type { Component } from "@earendil-works/pi-tui";

type CopySource = (source: string) => Promise<void>;
type Notify = (message: string, type?: "info" | "warning" | "error") => void;

type PreviewFrame = Component;

const DEFAULT_TITLE = "Markdown preview";
const COPY_HINT = "⧉ Copy [c]";
const CLOSE_HINT = "Esc Close";

export class MarkdownPreviewComponent implements Component {
  private readonly source: string;
  private readonly frame: PreviewFrame;
  private readonly copySource: CopySource;
  private readonly notify: Notify;
  private readonly close: () => void;

  constructor(
    source: string,
    frame: PreviewFrame,
    copySource: CopySource,
    notify: Notify,
    close: () => void,
  ) {
    this.source = source;
    this.frame = frame;
    this.copySource = copySource;
    this.notify = notify;
    this.close = close;
  }

  render(width: number): string[] {
    return this.frame.render(width);
  }

  invalidate(): void {
    this.frame.invalidate();
  }

  readonly onKey = (key: string): boolean => {
    if (key === "escape" || key === "\u001b" || key === "\u001b\u001b") {
      this.close();
      return true;
    }
    if (key === "c" || key === "C") {
      void this.copy();
      return true;
    }
    return false;
  };

  handleInput(data: string): void {
    this.onKey(data);
  }

  private async copy(): Promise<void> {
    try {
      await this.copySource(this.source);
      this.notify("Markdown source copied to clipboard", "info");
    } catch {
      this.notify("Failed to copy Markdown source to clipboard", "error");
    }
  }
}

export async function createMarkdownPreviewComponent(
  source: string,
  title: string,
  theme: Theme,
  copySource: CopySource,
  notify: Notify,
  close: () => void,
): Promise<MarkdownPreviewComponent> {
  const { Box, Markdown, Spacer, Text } = await import("@earendil-works/pi-tui");
  const { getMarkdownTheme } = await import("@earendil-works/pi-coding-agent");
  const frame = new Box(1, 1, (content: string) => theme.bg("customMessageBg", content));
  frame.addChild(new Text(theme.fg("customMessageLabel", title), 0, 0));
  frame.addChild(new Spacer(1));
  frame.addChild(
    new Markdown(source, 0, 0, getMarkdownTheme(), {
      color: (content: string) => theme.fg("customMessageText", content),
    }),
  );
  frame.addChild(new Spacer(1));
  frame.addChild(
    new Text(
      `${theme.fg("accent", COPY_HINT)}  ${theme.fg("dim", CLOSE_HINT)}`,
      0,
      0,
    ),
  );
  return new MarkdownPreviewComponent(source, frame, copySource, notify, close);
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

export default function bAgenticPreviewMarkdown(pi: ExtensionAPI): void {
  pi.registerTool({
    name: "preview_markdown",
    label: "Preview Markdown",
    description: "Open Markdown in a temporary native Pi TUI preview without writing a file.",
    promptSnippet: "Preview Markdown directly in the Pi TUI without creating a file",
    promptGuidelines: [
      "Use preview_markdown when the user asks to preview Markdown in Pi; pass the original Markdown source, not rendered text or an image.",
      "Use preview_markdown for an in-session visual preview only; it does not write files or mutate session messages.",
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

      const { copyToClipboard } = await import("@earendil-works/pi-coding-agent");
      await ctx.ui.custom<void>(async (tui, theme, _keybindings, done) => {
        void tui;
        return createMarkdownPreviewComponent(
          params.markdown,
          title,
          theme,
          copyToClipboard,
          ctx.ui.notify,
          () => done(),
        );
      });

      return {
        content: [{ type: "text", text: "Markdown preview closed." }],
        details: { interactive: true, title },
      };
    },
  });
}

export const __test__ = {
  COPY_HINT,
  CLOSE_HINT,
  DEFAULT_TITLE,
  fallbackResult,
};
