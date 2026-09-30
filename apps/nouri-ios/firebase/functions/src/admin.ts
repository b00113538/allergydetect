import { initializeApp, getApps } from "firebase-admin/app";

/** Initialise the Admin SDK once for every function module that needs it. */
if (getApps().length === 0) initializeApp();
