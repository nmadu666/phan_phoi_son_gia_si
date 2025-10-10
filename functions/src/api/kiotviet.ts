import axios, {isAxiosError} from "axios";
import * as logger from "firebase-functions/logger";
import {
  getKiotVietClientId,
  getKiotVietClientSecret,
  getKiotVietRetailer,
} from "../core/config";
import {URLSearchParams} from "url";

/**
 * Service class for interacting with the KiotViet API.
 */
class KiotVietApiService {
  private static instance: KiotVietApiService;
  private accessToken: string | null = null;
  private tokenExpiry: number | null = null;

  /**
   * Private constructor for the singleton pattern.
   * @private
   */
  private constructor() {
    // eslint-disable-next-line @typescript-eslint/no-empty-function
  }

  /**
   * Returns the singleton instance of the KiotVietApiService.
   * @return {KiotVietApiService} The singleton instance.
   */
  public static getInstance(): KiotVietApiService {
    if (!KiotVietApiService.instance) {
      KiotVietApiService.instance = new KiotVietApiService();
    }
    return KiotVietApiService.instance;
  }

  /**
   * Refreshes the KiotViet access token.
   * @private
   */
  private async refreshAccessToken(): Promise<void> {
    const tokenUrl = "https://id.kiotviet.vn/connect/token";
    const params = new URLSearchParams();
    params.append("scopes", "PublicApi.Access");
    params.append("grant_type", "client_credentials");
    params.append("client_id", getKiotVietClientId());
    params.append("client_secret", getKiotVietClientSecret());

    try {
      const response = await axios.post(tokenUrl, params, {
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
      });

      if (response.status === 200 && response.data.access_token) {
        this.accessToken = response.data.access_token;
        // Set expiry to 5 minutes before the actual expiry time to be safe
        this.tokenExpiry =
          Date.now() + (response.data.expires_in - 300) * 1000;
        logger.info("Successfully refreshed KiotViet access token.");
      } else {
        throw new Error("Access token not found in KiotViet response.");
      }
    } catch (error) {
      logger.error("Failed to refresh KiotViet access token:", error);
      throw new Error("Failed to refresh KiotViet access token.");
    }
  }

  /**
   * Ensures that the access token is valid, refreshing it if necessary.
   * @private
   */
  private async ensureValidToken(): Promise<void> {
    if (
      !this.accessToken ||
      (this.tokenExpiry && Date.now() >= this.tokenExpiry)
    ) {
      await this.refreshAccessToken();
    }
  }

  /**
   * Makes a request to the KiotViet API.
   * @param {"get" | "post" | "put" | "delete"} method The HTTP method.
   * @param {string} endpoint The API endpoint.
   * @param {unknown} data The request data.
   * @return {Promise<unknown>} The response data.
   */
  public async makeApiRequest(
    method: "get" | "post" | "put" | "delete",
    endpoint: string,
    data?: unknown,
  ): Promise<unknown> {
    await this.ensureValidToken();

    const url = `https://public.kiotapi.com${endpoint}`;
    const headers = {
      "Authorization": `Bearer ${this.accessToken}`,
      "Retailer": getKiotVietRetailer(),
      "Content-Type": "application/json",
    };

    try {
      const response = await axios({
        method,
        url,
        headers,
        data,
      });
      return response.data;
    } catch (error: unknown) {
      if (isAxiosError(error) && error.response?.status === 401) {
        logger.info("KiotViet token expired. Refreshing and retrying...");
        await this.refreshAccessToken();
        // Retry the request with the new token
        headers["Authorization"] = `Bearer ${this.accessToken}`;
        const response = await axios({
          method,
          url,
          headers,
          data,
        });
        return response.data;
      }
      logger.error(`KiotViet API request to ${endpoint} failed:`, error);
      throw error;
    }
  }

  /**
   * Fetches all data from a paginated KiotViet API endpoint.
   * @param {string} endpoint The API endpoint to fetch data from.
   * @return {Promise<unknown[]>} A promise that resolves to an array of all
   * items.
   */
  public async fetchAllKiotVietData(endpoint: string): Promise<unknown[]> {
    const allData: unknown[] = [];
    let currentItem = 0;
    const pageSize = 100;
    let totalItems = -1;

    logger.info(`Starting data fetch from: ${endpoint}`);

    const url = `${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
    const initialResult = (await this.makeApiRequest("get", url)) as {
      total: number;
      data: unknown[];
    };

    if (
      initialResult &&
      initialResult.total > 0 &&
      Array.isArray(initialResult.data)
    ) {
      totalItems = initialResult.total;
      allData.push(...initialResult.data);
      currentItem = initialResult.data.length;
      logger.info(`Fetched ${currentItem}/${totalItems} items...`);
    } else {
      logger.info(`No data found at ${endpoint}.`);
      return [];
    }

    while (currentItem < totalItems) {
      const loopUrl =
        `${endpoint}?currentItem=${currentItem}&pageSize=${pageSize}`;
      const result = (await this.makeApiRequest("get", loopUrl)) as {
        data: unknown[];
      };

      if (result && Array.isArray(result.data) && result.data.length > 0) {
        allData.push(...result.data);
        currentItem += result.data.length;
        logger.info(`Fetching... ${currentItem}/${totalItems}`);
      } else {
        break;
      }
    }

    logger.info(
      `Finished fetching ${allData.length} items from ${endpoint}.`
    );
    return allData;
  }
}

export const kiotVietApiService = KiotVietApiService.getInstance();
