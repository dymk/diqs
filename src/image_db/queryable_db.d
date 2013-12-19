module image_db.queryable_db;

import query;

interface QueryableDb
{
	/**
	 * Performs a query on the database
	 */
	QueryResult[] query(QueryParams) const;
}
