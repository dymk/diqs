module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : image_id_t;
import sig : ImageData, IDImageData;

interface BaseDB
{
	IDImageData addImage(ImageData);
	bool removeImage(image_id_t);
}
