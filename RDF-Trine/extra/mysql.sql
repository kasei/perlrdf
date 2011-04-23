CREATE TABLE IF NOT EXISTS Literals (
	ID bigint unsigned PRIMARY KEY,
	Value longtext NOT NULL,
	Language text NOT NULL DEFAULT "",
	Datatype text NOT NULL DEFAULT "",
	INDEX (Value(32))
) CHARACTER SET utf8 COLLATE utf8_bin;

CREATE TABLE IF NOT EXISTS Resources (
	ID bigint unsigned PRIMARY KEY,
	URI text NOT NULL,
	INDEX (URI(64))
);

CREATE TABLE IF NOT EXISTS Bnodes (
	ID bigint unsigned PRIMARY KEY,
	Name text NOT NULL
);

CREATE TABLE IF NOT EXISTS Models (
	ID bigint unsigned PRIMARY KEY,
	Name text NOT NULL
);
