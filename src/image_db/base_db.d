module image_db.base_db;

/**
 * Represents an image database, held in memory and/or the disk.
 */

import types : user_id_t, coeffi_t;
import sig : ImageData, IDImageData;
import consts : ImageArea, NumColorChans;

interface BaseDB
{
	IDImageData addImage(const ref ImageData);
}

