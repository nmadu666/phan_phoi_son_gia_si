
// This file declares the types for the external FirestoreApp library.
// By creating this .d.ts file, we teach TypeScript what FirestoreApp is
// and what methods and types it exposes.

// Augment the existing GoogleAppsScript namespace to include Firestore types.
declare namespace GoogleAppsScript {
  namespace Firestore {
    /**
     * The main Firestore instance, returned by FirestoreApp.getFirestore().
     */
    export interface Firestore {
      getDocument(path: string): DocumentReference;
      createDocument(path: string, data: object): void;
    }

    /**
     * A reference to a document in the Firestore database.
     */
    export interface DocumentReference {
      // This interface is a placeholder for the type.
      // No properties or methods are needed for the current code.
    }
  }
}

/**
 * Declares the global FirestoreApp object that is available after
 * adding the library in the Apps Script editor.
 */
declare const FirestoreApp: {
  getFirestore(email: string, key: string, projectId: string): GoogleAppsScript.Firestore.Firestore;
};
