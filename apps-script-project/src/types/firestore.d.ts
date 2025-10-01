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
      getDocuments(path: string): Document[];
      batch(): Batch;
      // Thêm các phương thức khác nếu bạn sử dụng trong tương lai
      // getDocument(path: string): Document;
      // createDocument(path: string, data: object): Document;
      // updateDocument(path: string, data: object): Document;
      // deleteDocument(path: string): void;
    }

    /**
     * Represents a document returned from Firestore.
     */
    export interface Document {
      /** The full resource name of the document, e.g., 'projects/projectId/databases/(default)/documents/collection/docId'. */
      name: string;
      /** The fields of the document, represented as a JavaScript object. */
      obj: { [key: string]: any };
      /** The time the document was created. */
      createTime: string;
      /** The time the document was last updated. */
      updateTime: string;
    }

    /**
     * Represents a batch of write operations.
     */
    export interface Batch {
      /** Queues an update operation for a document in the batch. */
      update(path: string, data: { [key: string]: any }): Batch;
      /** Commits all of the writes in the batch. */
      commit(): void;
      // Thêm các phương thức khác của batch nếu cần (create, delete,...)
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
