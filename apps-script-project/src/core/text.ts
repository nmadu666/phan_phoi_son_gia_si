/**
 * @fileoverview Contains utility functions for text processing.
 */
/**
 * Generates keywords and prefixes from a given text string for Firestore search.
 * - `keywords`: An array of unique, normalized words.
 * - `prefixes`: An array of all possible prefixes for each word, enabling "search-as-you-type".
 *
 * @param {string} text The input string to process.
 * @returns {{keywords: string[], prefixes: string[]}} An object containing keywords and prefixes.
 */
export function generateSearchables(text: string | null | undefined): { keywords: string[], prefixes: string[] } {
  if (!text || typeof text !== 'string') {
    return { keywords: [], prefixes: [] };
  }

  const normalizedText = text
    .toLowerCase()
    .normalize('NFD') // Decompose combined characters (e.g., 'á' -> 'a' + '´')
    .replace(/[\u0300-\u036f]/g, '') // Remove diacritical marks
    .replace(/đ/g, 'd'); // Special case for the Vietnamese letter 'đ'

  // Split by any non-alphanumeric character and filter out empty strings
  const words = normalizedText.split(/[^a-z0-9]+/).filter(word => word.length > 0);
  const uniqueWords = Array.from(new Set(words));

  const prefixes = new Set<string>();
  uniqueWords.forEach(word => {
    for (let i = 1; i <= word.length; i++) {
      prefixes.add(word.substring(0, i));
    }
  });

  return {
    keywords: uniqueWords,
    prefixes: Array.from(prefixes),
  };
}

/**
 * @deprecated Use generateSearchables instead.
 * Generates a clean array of keywords from a given text string.
 */
export function generateKeywordsFromText(text: string): string[] {
  return generateSearchables(text).keywords;
}

