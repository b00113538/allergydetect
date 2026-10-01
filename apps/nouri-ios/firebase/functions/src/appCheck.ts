import { defineBoolean } from "firebase-functions/params";

/**
 * Callable functions only accept requests carrying a valid Firebase App Check token, i.e. from the
 * genuine Nouri app on a real device (App Attest / DeviceCheck) or a registered debug build — so
 * nobody can script the endpoints and run up the Claude bill. Emergency off-switch: set
 * ENFORCE_APP_CHECK=false in functions/.env and redeploy.
 */
export const ENFORCE_APP_CHECK = defineBoolean("ENFORCE_APP_CHECK", { default: true });
