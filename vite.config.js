import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import { resolve } from "node:path";

export default defineConfig({
  plugins: [tailwindcss()],
  build: {
    rollupOptions: {
      input: {
        main: resolve(import.meta.dirname, "index.html"),
        field: resolve(import.meta.dirname, "field/index.html"),
        demo: resolve(import.meta.dirname, "demo/index.html"),
      },
    },
  },
});
