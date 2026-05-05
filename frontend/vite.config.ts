import {defineConfig, loadEnv} from "vite"
import EntryShakingPlugin from "vite-plugin-entry-shaking";
import react from "@vitejs/plugin-react-swc";
import obfuscatorPlugin from "vite-plugin-javascript-obfuscator";

const normalizePublicBase = (value?: string) => {
  if (!value) {
    return "/";
  }

  return value.endsWith("/") ? value : `${ value }/`;
};

// https://vitejs.dev/config/
export default ({mode}) => {
  const env = {...process.env, ...loadEnv(mode, process.cwd(), "")};
  const clientEnv = Object.fromEntries(
    Object.entries(env).filter(([key]) =>
      key.startsWith("REACT_APP_") || ["DEBUG", "NODE_ENV", "PUBLIC_URL"].includes(key)
    )
  );

  return defineConfig({
    base: normalizePublicBase(env.PUBLIC_URL),
    plugins: [
      react()
    ],
    esbuild: {
      charset: "ascii",
    },
    build: {
    },
    define: {
      "process.env": clientEnv
    },
    server: {
      host: env.HOST || "localhost",
      port: env.PORT ? parseInt(env.PORT, 10) : 3000
    },
    resolve: {
      alias: [
        {
          find: /^~(.*)$/,
          replacement: "$1",
        },
      ],
    }
  })
}
