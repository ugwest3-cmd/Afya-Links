import { supabase } from '../config/supabase';
import { v4 as uuidv4 } from 'uuid';

/**
 * Uploads a file to Supabase Storage and returns the public URL.
 * 
 * @param bucketName The name of the storage bucket ('verification-docs', 'price-lists', etc.)
 * @param file The file object from Multer
 * @param folder Optional folder name inside the bucket
 * @returns Public URL of the uploaded file
 */
export const uploadFileToSupabase = async (bucketName: string, file: Express.Multer.File, folder: string = ''): Promise<string> => {
    const fileExt = file.originalname.split('.').pop();
    const fileName = `${folder ? folder + '/' : ''}${uuidv4()}.${fileExt}`;

    const { data, error } = await supabase.storage
        .from(bucketName)
        .upload(fileName, file.buffer, {
            contentType: file.mimetype,
            upsert: true,
        });

    if (error) {
        throw new Error(`Supabase upload failed: ${error.message}`);
    }

    const { data: publicUrlData } = supabase.storage
        .from(bucketName)
        .getPublicUrl(data.path);

    return publicUrlData.publicUrl;
};
