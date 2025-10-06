/**
 * @fileoverview Contains utility functions for date parsing.
 */

/**
 * Parses a date string from various formats (KiotViet API, ISO 8601) into a JavaScript Date object.
 * Handles formats like:
 * - "/Date(1609459200000+0700)/" (KiotViet)
 * - "2022-08-04T13:08:26.2970000" (ISO 8601 variant)
 * @param {string | null | undefined} dateString The date string to parse.
 * @returns {Date | null} A Date object or null if parsing fails.
 */
export function parseKiotVietDate(dateString: string | null | undefined): Date | null {
  if (!dateString || typeof dateString !== 'string') return null;

  // 1. Try parsing KiotViet format: /Date(1609459200000+0700)/
  const kiotVietMatch = dateString.match(/\/Date\((\d+).*\)\//);
  if (kiotVietMatch && kiotVietMatch[1]) {
    return new Date(parseInt(kiotVietMatch[1], 10));
  }

  // 2. Try parsing as a standard ISO 8601 string or similar formats
  const date = new Date(dateString);
  // Check if the date is valid. `new Date('invalid string')` returns an Invalid Date object,
  // and its time value is NaN.
  if (!isNaN(date.getTime())) {
    return date;
  }

  // 3. If all parsing fails, return null
  return null;
}
