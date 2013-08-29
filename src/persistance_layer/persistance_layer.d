module persistance_layer.persistance_layer;

import sig :
  ImageIdSigDcRes;

import types :
  user_id_t;

import image_db.bucket_manager :
  BucketSizes;

interface PersistanceLayer
{
	ImageIdSigDcRes getImage(user_id_t);
	ImageIdSigDcRes removeImage(user_id_t);
	void appendImage(ImageIdSigDcRes);

	void save();
	void close();

	BucketSizes* bucketSizes();

	uint length();

	interface ImageDataIterator {
		ImageIdSigDcRes front();
		void popFront();
		bool empty();
	}
	ImageDataIterator imageDataIterator();
}
