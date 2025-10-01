function addSearchKeywordsToProducts() {
    const collectionName = 'kiotviet_products';
    const batchSize = 400; // Firestore batch writes are limited to 500 operations.
    Logger.log(`Starting to add 'search_keywords' to collection: '${collectionName}'`);
    try {
        const firestore = (0, firebase_1.getFirestoreInstance)();
        const allDocs = firestore.getDocuments(collectionName);
        if (!allDocs || allDocs.length === 0) {
            Logger.log('No documents found in the collection. Nothing to do.');
            return;
        }
        Logger.log(`Found ${allDocs.length} documents to process.`);
        for (let i = 0; i < allDocs.length; i += batchSize) {
            const batch = firestore.batch();
            const end = Math.min(i + batchSize, allDocs.length);
            Logger.log(`Processing batch: documents ${i + 1} to ${end}`);
            for (let j = i; j < end; j++) {
                const doc = allDocs[j];
                const productData = doc.obj;
                const docPath = `${collectionName}/${doc.name.split('/').pop()}`;
                const nameKeywords = (0, text_1.generateKeywordsFromText)(productData.name);
                const codeKeywords = (0, text_1.generateKeywordsFromText)(productData.code);
                // Combine keywords from name and code, ensuring uniqueness
                const allKeywords = new Set([...nameKeywords, ...codeKeywords]);
                // Update the document with the new array of keywords
                batch.update(docPath, { search_keywords: Array.from(allKeywords) });
            }
            // Commit the batch
            batch.commit();
        }
        Logger.log('Successfully updated all documents with search_keywords.');
        (0, ui_1.showToast)('Fix Complete!', `Updated ${allDocs.length} products.`);
    }
    catch (e) {
        Logger.log(`An error occurred during the fix process: ${e.toString()}\n${e.stack}`);
        (0, ui_1.showToast)('Fix Failed', `Error: ${e.message}`);
    }
}
