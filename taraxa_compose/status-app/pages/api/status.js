import { nodeStatus } from "../../lib/rpc";

export default async function statusHandler(_, res) {
  try {
    const status = await nodeStatus();
    return res.json(status);
  } catch (e) {
    res.status(e.status).json({ error: e.message });
  }
}
