module net.db_info;

import types;
import image_db.all;

struct DbInfo {
	enum Flags : uint {
		Queryable = 1,
		Persistable = 2,
		ImageRemovable = 4,
		Reservable = 8
	}

	enum Type : uint
	{
		Mem,
		Level
	}

	// Probably not the best way to transfer database info, but it
	// greatly simplifies ease of serializing database info for multiple
	// different types of databases in a peer-agnostic way.
	user_id_t id;
	uint num_images;

	Type type;
	Flags flags;

	bool _dirty;
	string _path;

	bool dirty() @property
	{
		enforce(persistable);
		return _dirty;
	}

	string path() @property
	{
		enforce(persistable);
		return _path;
	}

	bool queryable() @property
	{
		return (flags & Flags.Queryable) != 0;
	}

	bool persistable() @property
	{
		return (flags & Flags.Persistable) != 0;
	}

	bool image_removable() @property
	{
		return (flags & Flags.ImageRemovable) != 0;
	}

	bool reservable() @property
	{
		return (flags & Flags.Reservable) != 0;
	}

	this(user_id_t id, BaseDb db)
	{
		this.flags = cast(Flags) 0;
		this.id = id;
		this.num_images = db.numImages();

		auto q = db.getQueryable();
		auto p = cast(PersistableDb) db;
		auto i = cast(ImageRemovableDb) db;
		auto r = cast(ReservableDb) db;

		with(Flags)
		{
			if(q !is null) this.flags |= Queryable;
			if(p !is null) this.flags |= Persistable;
			if(i !is null) this.flags |= ImageRemovable;
			if(r !is null) this.flags |= Reservable;
		}

		if(cast(MemDb) db)
		{
			type = Type.Mem;
		}
		else
		if(cast(LevelDb) db)
		{
			type = Type.Level;
		}
		else
		{
			assert(false, "Unknown concretae database class");
		}

		if(p)
		{
			_dirty = p.dirty();
			_path = p.path();
		}
	}
}
