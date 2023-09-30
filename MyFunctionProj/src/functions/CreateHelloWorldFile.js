const { app } = require('@azure/functions');
const { BlobServiceClient } = require('@azure/storage-blob');


app.http('CreateHelloWorldFile', {
    methods: ['GET', 'POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        try {
            context.log(`Http function processed request for url "${request.url}"`);
            const datetime = new Date().toISOString();
            const filename = `Hello World_${datetime}.txt`;
            const content = `Hello, World it is ${datetime} now!`;

            const connectionString = process.env.DOCUMENTS_SA;
            const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
            const containerClient = blobServiceClient.getContainerClient('container');
            const blockBlobClient = containerClient.getBlockBlobClient(filename);

            await blockBlobClient.upload(content, content.length);

            return { body: `File ${filename} created successfully.` };
        } catch (e) {
            context.error(e)
            throw e
        }
    }
});
