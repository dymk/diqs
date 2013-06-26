module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : image_id_t, ImageData;

interface BaseDB
{
	image_id_t addImage(ImageData);
	bool removeImage(image_id_t);
}
