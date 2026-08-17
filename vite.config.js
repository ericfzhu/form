import { resolve } from "node:path";
import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";

const demoArtwork = {
  name: "form-demo-artwork",
  transformIndexHtml(_html, context) {
    const filename = context?.filename?.replaceAll("\\", "/") ?? "";
    if (!filename.endsWith("/demo/index.html")) return;

    return [
      {
        tag: "link",
        attrs: { rel: "stylesheet", href: "/src/demo-artwork.css" },
        injectTo: "head",
      },
      {
        tag: "script",
        attrs: { type: "module", src: "/src/demo-artwork.js" },
        injectTo: "head",
      },
    ];
  },
};

export default defineConfig({
  plugins: [tailwindcss(), demoArtwork],
  build: {
    rollupOptions: {
      input: {
        main: resolve(process.cwd(), "index.html"),
        demo: resolve(process.cwd(), "demo/index.html"),
      },
    },
  },
});
