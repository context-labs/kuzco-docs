/** @type {import('next-sitemap').IConfig} */
module.exports = {
  siteUrl: process.env.SITE_URL || "https://docs.kuzco.xyz",
  generateRobotsTxt: true, // (optional)
  // ...other options
};
