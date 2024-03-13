import React from "react";
import { useRouter } from "next/router";
import posthog from "posthog-js";
import "nextra-theme-docs/style.css";
import "../styles.css";

export default function Nextra({ Component, pageProps }) {
  const getLayout = Component.getLayout || ((page) => page);
  const router = useRouter();

  React.useEffect(() => {
    /**
     * Init PostHog
     */
    posthog.init(process.env.NEXT_PUBLIC_POSTHOG_API_KEY ?? "", {
      api_host: "/ingest",
      session_recording: {
        maskAllInputs: false,
      },
    });

    /**
     * Track page views
     */
    const handleRouteChange = () => posthog?.capture("$pageview");
    router.events.on("routeChangeComplete", handleRouteChange);

    return () => {
      router.events.off("routeChangeComplete", handleRouteChange);
    };
  }, []);

  return getLayout(
    <>
      <Component {...pageProps} />
    </>
  );
}
