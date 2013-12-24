module image_db.interfaces.reservable_db;

interface ReservableDb
{
	// Reserve amt images in the database,
	// to avoid unnecessary allocations/resizes
	void reserve(size_t amt);
}
