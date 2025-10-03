/**
 * @fileoverview Manages retrieval of configuration from script properties.
 * This approach keeps sensitive data out of the source code.
 */
import { getScriptProperty } from './properties';

// Functions to get KiotViet credentials from Script Properties
export const getKiotVietClientId = (): string => getScriptProperty('kiotviet_client_id');
export const getKiotVietClientSecret = (): string => getScriptProperty('kiotviet_client_secret');
export const getKiotVietRetailer = (): string => getScriptProperty('kiotviet_retailer');

// Functions to get Firestore credentials from Script Properties
export const getFirestoreClientEmail = (): string => getScriptProperty('firestore_client_email');
export const getFirestorePrivateKey = (): string => getScriptProperty('firestore_private_key');
export const getFirestoreProjectId = (): string => getScriptProperty('firestore_project_id');