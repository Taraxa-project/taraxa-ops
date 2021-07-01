import { accountAddress } from "../../lib/rpc";

export default async function addressHandler(_, res) {
  try {
    const address = await accountAddress();
    return res.json(address);
  } catch (e) {
    res.status(e.status).json({ error: e.message });
  }
}
