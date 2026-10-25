import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export function createMediaStorage(env = process.env) {
  const endpoint = (env.R2_ENDPOINT ?? env.S3_ENDPOINT ?? '').trim();
  const bucket = (env.R2_BUCKET ?? env.S3_BUCKET ?? '').trim();
  const accessKeyId = (env.R2_ACCESS_KEY_ID ?? env.S3_ACCESS_KEY_ID ?? '').trim();
  const secretAccessKey = (env.R2_SECRET_ACCESS_KEY ?? env.S3_SECRET_ACCESS_KEY ?? '').trim();

  const configuredValues = [endpoint, bucket, accessKeyId, secretAccessKey].filter(Boolean);
  if (configuredValues.length === 0) return null;
  if (configuredValues.length !== 4) {
    throw new Error(
      'R2_ENDPOINT, R2_BUCKET, R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY must be configured together.',
    );
  }

  let parsedEndpoint;
  try {
    parsedEndpoint = new URL(endpoint);
  } catch {
    throw new Error('R2_ENDPOINT must be a valid HTTPS URL.');
  }
  if (parsedEndpoint.protocol !== 'https:') {
    throw new Error('R2_ENDPOINT must use HTTPS.');
  }

  const client = new S3Client({
    region: env.R2_REGION ?? env.S3_REGION ?? 'auto',
    endpoint: parsedEndpoint.toString().replace(/\/$/, ''),
    forcePathStyle: true,
    credentials: { accessKeyId, secretAccessKey },
  });

  return Object.freeze({
    async createUploadUrl({ key, contentType }) {
      return getSignedUrl(
        client,
        new PutObjectCommand({
          Bucket: bucket,
          Key: key,
          ContentType: contentType,
        }),
        { expiresIn: 900 },
      );
    },
    async createDownloadUrl({ key }) {
      return getSignedUrl(
        client,
        new GetObjectCommand({ Bucket: bucket, Key: key }),
        { expiresIn: 3600 },
      );
    },
    async headObject({ key }) {
      try {
        const result = await client.send(
          new HeadObjectCommand({ Bucket: bucket, Key: key }),
        );
        return {
          sizeBytes: Number(result.ContentLength ?? 0),
          contentType: result.ContentType ?? '',
        };
      } catch (error) {
        if (
          error?.$metadata?.httpStatusCode === 404 ||
          error?.name === 'NotFound' ||
          error?.name === 'NoSuchKey'
        ) {
          return null;
        }
        throw error;
      }
    },
    async deleteObject({ key }) {
      await client.send(new DeleteObjectCommand({ Bucket: bucket, Key: key }));
    },
  });
}
