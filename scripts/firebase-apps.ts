import { JWT } from "npm:google-auth-library@9";

// The credential stays on this machine and is never emitted or bundled.
const credentialPath = Deno.args[0];
if (!credentialPath) throw new Error("Pass the private Firebase service-account file path.");
const account = JSON.parse(await Deno.readTextFile(credentialPath));
if (account.project_id !== "tokilomobileapp") throw new Error("Wrong Firebase project; refusing to continue.");
const client = new JWT({ email: account.client_email, key: account.private_key,
  scopes: ["https://www.googleapis.com/auth/firebase"] });
const auth = await client.authorize();
const headers = { Authorization: `Bearer ${auth.access_token}`, "Content-Type": "application/json" };
const base = "https://firebase.googleapis.com/v1beta1/projects/tokilomobileapp/androidApps";
const response = await fetch(base, { headers });
const result = await response.json();
if (!response.ok) {
  console.error(`Firebase app listing failed (${response.status}): ${result.error?.message ?? "Unknown error"}`);
  Deno.exit(1);
}
console.log(JSON.stringify((result.apps ?? []).map((app: {name: string; packageName: string; appId: string}) =>
  ({ name: app.name, packageName: app.packageName, appId: app.appId })), null, 2));

const packageName = Deno.args[1];
if (packageName) {
  if (packageName !== "com.tokilotechnologies.businesshub") throw new Error("Unexpected release package.");
  let app = (result.apps ?? []).find((item: {packageName: string}) => item.packageName === packageName);
  if (!app) {
    const created = await fetch(base, { method: "POST", headers,
      body: JSON.stringify({ packageName, displayName: "Tokilo Business Hub" }) });
    if (!created.ok) throw new Error(`App registration failed (${created.status}).`);
    let operation = await created.json();
    for (let retry = 0; !operation.done && retry < 20; retry++) {
      await new Promise(resolve => setTimeout(resolve, 1500));
      const check = await fetch(`https://firebase.googleapis.com/v1beta1/${operation.name}`, { headers });
      if (!check.ok) throw new Error(`Registration status failed (${check.status}).`);
      operation = await check.json();
    }
    if (!operation.done || operation.error) throw new Error("Firebase registration did not complete.");
    app = operation.response;
  }
  const sdk = await fetch(`https://firebase.googleapis.com/v1beta1/${app.name}/config`, { headers });
  if (!sdk.ok) throw new Error(`SDK configuration failed (${sdk.status}).`);
  const config = await sdk.json();
  const decoded = new TextDecoder().decode(Uint8Array.from(atob(config.configFileContents), character => character.charCodeAt(0)));
  const next = JSON.parse(decoded);
  const target = "android/app/google-services.json";
  const existing = JSON.parse(await Deno.readTextFile(target));
  if (next.project_info.project_id !== "tokilomobileapp" || existing.project_info.project_id !== "tokilomobileapp") {
    throw new Error("SDK configuration belongs to a different project.");
  }
  const clients = existing.client.filter((item: {client_info: {android_client_info: {package_name: string}}}) =>
    item.client_info.android_client_info.package_name !== packageName);
  await Deno.writeTextFile(target, JSON.stringify({ ...existing, client: [...clients, ...next.client] }, null, 2) + "\n");
  console.log(`Registered ${packageName}; public Firebase SDK configuration saved.`);
}
