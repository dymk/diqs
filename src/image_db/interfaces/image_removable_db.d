module image_db.interfaces.image_removable_db;

import types;
import image_db.all;

interface ImageRemovableDb
{
	void removeImage(user_id_t user_id);
}
