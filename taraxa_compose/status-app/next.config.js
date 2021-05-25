module.exports = {
  publicRuntimeConfig: {
    NEXT_PUBLIC_RPC:
      process.env.NEXT_PUBLIC_RPC || "http://node:7777",
  },
};
