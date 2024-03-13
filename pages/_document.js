import Document, { Html, Head, Main, NextScript } from "next/document";

// We use display=block to remove the jank

class MyDocument extends Document {
  render() {
    return (
      <Html>
        <Head>
          <link rel="preconnect" href="https://fonts.googleapis.com" />
          <link
            rel="preconnect"
            href="https://fonts.gstatic.com"
            crossOrigin="true"
          />
          <link
            href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700;800&display=optional"
            rel="stylesheet"
          />

          {/* Load in Context */}
          <script
            id="__CONTEXT_BUBBLE__"
            src="https://portal.kuzco.xyz/portal/portal.js"
            data-bot-id="j472bRred"
            data-theme="dark"
            data-type="attribute"
            data-position="bottom-right"
            data-background="#000000"
            data-color="#FFFFFF"
          ></script>

          {/* Load in Intercom */}
          <script
            dangerouslySetInnerHTML={{
              __html: `window.intercomSettings = {
              api_base: "https://api-iam.intercom.io",
              app_id: "s8wtjm4p"
              };`,
            }}
          />
          <script
            dangerouslySetInnerHTML={{
              __html: `(function(){var w=window;var ic=w.Intercom;if(typeof ic==="function"){ic('reattach_activator');ic('update',w.intercomSettings);}else{var d=document;var i=function(){i.c(arguments);};i.q=[];i.c=function(args){i.q.push(args);};w.Intercom=i;var l=function(){var s=d.createElement('script');s.type='text/javascript';s.async=true;s.src='https://widget.intercom.io/widget/s8wtjm4p';var x=d.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};if(document.readyState==='complete'){l();}else if(w.attachEvent){w.attachEvent('onload', l);}else{w.addEventListener('load', l, false);}}})();`,
            }}
          />
        </Head>
        <body>
          <Main />
          <NextScript />
        </body>
      </Html>
    );
  }
}

export default MyDocument;
