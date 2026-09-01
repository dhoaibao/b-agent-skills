import eslint from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  {
    ignores: [
      "pi/extensions/b-agentic-support/mcp.ts",
      "pi/extensions/b-agentic-support/role.ts",
    ],
  },
  eslint.configs.recommended,
  ...tseslint.configs.recommended,
);
