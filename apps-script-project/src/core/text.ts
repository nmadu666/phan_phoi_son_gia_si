/**
 * @fileoverview Contains utility functions for text processing.
 */

/**
 * Generates a clean array of keywords from a given text string.
 * This function performs several normalization steps:
 * 1. Converts the text to lowercase.
 * 2. Removes Vietnamese diacritics (e.g., "sơn màu" -> "son mau").
 * 3. Replaces any non-alphanumeric characters with spaces.
 * 4. Splits the text into individual words.
 * 5. Returns an array of unique, non-empty keywords.
 *
 * @param {string} text The input string to process.
 * @returns {string[]} An array of normalized keywords.
 */
export function generateKeywordsFromText(text: string): string[] {
    if (!text) {
        return [];
    }

    const normalizedText = text
        .toLowerCase()
        .normalize('NFD') // Decompose combined characters (e.g., 'á' -> 'a' + '´')
        .replace(/[\u0300-\u036f]/g, '') // Remove diacritical marks
        .replace(/đ/g, 'd'); // Special case for the Vietnamese letter 'đ'

    // Split by any non-alphanumeric character and filter out empty strings
    const words = normalizedText.split(/[^a-z0-9]+/).filter(word => word.length > 0);

    return Array.from(new Set(words)); // Return unique keywords
}

