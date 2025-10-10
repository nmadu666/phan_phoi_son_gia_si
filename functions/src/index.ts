/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {kiotVietApiService} from "./api/kiotviet";

setGlobalOptions({maxInstances: 10, region: "asia-southeast1"});

export const kiotvietProxy = onRequest(
  {cors: true},
  async (request, response) => {
    try {
      const {method, endpoint, data} = request.body;

      if (!method || !endpoint) {
        response.status(400).send(
          "Missing 'method' or 'endpoint' in request body.",
        );
        return;
      }

      logger.info(`Proxying request: ${method} ${endpoint}`);

      const result = await kiotVietApiService.makeApiRequest(
        method,
        endpoint,
        data,
      );
      response.status(200).send(result);
    } catch (error) {
      logger.error("Error in KiotViet proxy:", error);
      response.status(500).send(
        "An error occurred while proxying the request.",
      );
    }
  },
);

export const kiotvietSync = onRequest(
  {cors: true},
  async (request, response) => {
    try {
      const {endpoint} = request.body;

      if (!endpoint) {
        response.status(400).send("Missing 'endpoint' in request body.");
        return;
      }

      logger.info(`Syncing all data from: ${endpoint}`);

      const result = await kiotVietApiService.fetchAllKiotVietData(endpoint);
      response.status(200).send(result);
    } catch (error) {
      logger.error("Error in KiotViet sync:", error);
      response.status(500).send("An error occurred while syncing data.");
    }
  },
);
