module image_db.level_db_listeners;

import image_db.all;
import image_db.bucket_manager;
import types;
import sig;

import dawg.bloom;

interface DbImageChangeListener
{
	void onImageAdded(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res);
	void onImageRemoved(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res);
}

final class NumImageCounter : DbImageChangeListener
{
private:
	uint num_images;

public:
	void onImageAdded(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	{
		num_images++;
	}

	void onImageRemoved(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	in
	{
		assert(num_images > 0, "Number of images would have been negative");
	}
	body
	{
		num_images--;
	}

	void set(uint num_images)
	{
		this.num_images = num_images;
	}

	uint get() @property const
	{
		return num_images;
	}
}

final class BucketSizeTracker : DbImageChangeListener
{
private:
	BucketSizes bucket_sizes;

public:
	void onImageAdded(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	in
	{
		assert(sig !is null);
	}
	body
	{
		bucket_sizes.addSig(sig);
	}

	void onImageRemoved(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	in
	{
		assert(sig !is null);
	}
	body
	{
		bucket_sizes.removeSig(sig);
	}

	inout(BucketSizes*) get() inout @property
	{
		return &bucket_sizes;
	}
}

final class MemDbImageTracker : DbImageChangeListener
{
private:
	MemDb mem_db;

public:
	this()
	{
		mem_db = new MemDb();
	}

	~this()
	{
		mem_db.destroy();
		mem_db = null;
	}

	void onImageAdded(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	in
	{
		assert(sig !is null);
		assert(dc !is null);
	}
	body
	{
		mem_db.addImage(user_id, sig, dc);
	}

	void onImageRemoved(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	{
		mem_db.removeImage(user_id);
	}

	inout(MemDb) get() inout @property
	{
		return mem_db;
	}
}

final class IdTracker : DbImageChangeListener
{
private:
	// Quick herustic for checking if an ID hasn't been inserted yet
	scope BloomFilter!(4, user_id_t) id_filter;

	// ID generator
	scope shared IdGen!user_id_t id_gen;

public:
	this(size_t size)
	{
		id_gen = new IdGen!user_id_t;
		id_filter.resize(size);
	}

	void onImageAdded(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	{
		id_gen.saw(user_id);
		id_filter.insert(user_id);
	}

	void onImageRemoved(user_id_t user_id, const(ImageSig*) sig, const(ImageDc*) dc, const(ImageRes*) res)
	{
		// NOP
	}

	inout ref filter() inout @property
	{
		return id_filter;
	}

	inout auto gen() inout @property
	{
		return id_gen;
	}
}
