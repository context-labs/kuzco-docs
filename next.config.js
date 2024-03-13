// eslint-disable-next-line @typescript-eslint/no-var-requires
const withNextra = require("nextra")({
  theme: "nextra-theme-docs",
  themeConfig: "./theme.config.js",
  defaultShowCopyCode: true,
});

module.exports = withNextra({
  reactStrictMode: true,
  async redirects() {
    return [
      {
        source: "/ingest/:path*",
        destination: "https://app.posthog.com/:path*",
        permanent: true,
      },
    ];
  },
});
