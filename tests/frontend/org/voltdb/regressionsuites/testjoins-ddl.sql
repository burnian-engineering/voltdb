CREATE TABLE R1 (
	A INTEGER NOT NULL,
	C INTEGER NOT NULL,
	D INTEGER 
);

CREATE TABLE R2 (
	A INTEGER NOT NULL,
	C INTEGER
);

CREATE TABLE R3 (
	A INTEGER NOT NULL,
	C INTEGER NOT NULL
);
CREATE INDEX IND1 ON R3 (A);

CREATE TABLE P1 (
	A INTEGER NOT NULL,
	C INTEGER NOT NULL,
	
);
PARTITION TABLE P1 ON COLUMN A;
 
CREATE TABLE P2 (
	A INTEGER NOT NULL,
	E INTEGER NOT NULL,
	PRIMARY KEY (A)
);
PARTITION TABLE P2 ON COLUMN A;

CREATE TABLE P3 (
	A INTEGER NOT NULL,
	F INTEGER NOT NULL,
	PRIMARY KEY (A)

);
PARTITION TABLE P3 ON COLUMN A;

-- ENG-8692
CREATE TABLE t1(i1 INTEGER);
CREATE TABLE t2(i2 INTEGER);
CREATE TABLE t3(i3 INTEGER);
CREATE TABLE t4(i4 INTEGER);
CREATE INDEX t4_idx ON T4 (i4);
