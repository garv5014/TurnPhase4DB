set search_path to public; 
drop schema if exists Gol cascade; 
create schema Gol; 
set search_path to Gol;

drop table if exists  cust_sub cascade;
drop table if exists cust_sub_featurepk cascade;
drop table if exists customer cascade;
drop table if exists developer cascade;
drop table if exists featurepack cascade;
drop table if exists game cascade;
drop table if exists game_feat cascade;
drop table if exists gameplay_record  cascade;
drop table if exists log_in_out_history cascade;
drop table if exists sub cascade;
drop table if exists sub_tier cascade;
drop table if exists cust_sub_pay_hist cascade;
drop table if exists cust_sub_feat_pay_hist cascade;
drop table if exists game_feature_pack_rev cascade;

CREATE TABLE customer (
	id serial4 NOT NULL,
	email text null unique,
	firstname text null,
	surname text null,
	username text null unique,
	password_ text null,
	payment_info text null,
	CONSTRAINT customer_pk PRIMARY KEY (id),
	unique(username)
);

CREATE TABLE log_in_out_history (
	id serial4 NOT NULL,
	success bool null,
	customerid int4 not null,
	login timestamp not null,
	logout timestamp null,
	CONSTRAINT log_in_out_history_pk PRIMARY KEY (id)
);
ALTER TABLE  log_in_out_history ADD CONSTRAINT log_in_out_history_fk FOREIGN KEY (customerid) REFERENCES customer(id)
on delete set null;

CREATE TABLE developer (
	id serial4 NOT NULL,
	developername text null unique,
	company_address text null unique,
	CONSTRAINT developer_pk PRIMARY KEY (id)
);


CREATE TABLE featurepack (
	id serial4 NOT NULL,
	pack_name text NULL,
	baseprice money null,
	active bool null constraint active check (true or null),
	CONSTRAINT featurepack_pk PRIMARY KEY (id),
	unique (pack_name, active)
);


CREATE TABLE game (
	id serial4 NOT NULL,
	game_name text NULL,
	dev_id int4 not null,
	public bool null,
	CONSTRAINT game_pk PRIMARY KEY (id),
	unique (game_name)
);
ALTER TABLE  game ADD CONSTRAINT game_fk FOREIGN KEY (dev_id) REFERENCES developer(id)
on delete set null;

create table game_feat (
	id serial4 not null,
	game_id int4 not null constraint game_public check ( check_public(game_id)  = false), -- check the gameid to make sure that it is private before adding it to a feature pack
	feat_id int4 not null,
	constraint game_feat_pk primary key (id),
	unique (game_id, feat_id)
);
ALTER TABLE  game_feat ADD CONSTRAINT game_feat_fk FOREIGN KEY (game_id) REFERENCES game(id)
on delete set null;
ALTER TABLE  game_feat ADD CONSTRAINT game__feat1_fk FOREIGN KEY (feat_id) REFERENCES featurepack(id)
on delete set null;

CREATE TABLE sub_tier (
	id serial4 NOT NULL,
	baseprice money null,
	tiername text NULL,
	concurrentlogin int4 null,
	active bool null constraint active check ( true or null) ,
	unique(tiername, active),
	
	CONSTRAINT sub_tier_pk PRIMARY KEY (id)
);

CREATE TABLE sub (
	id serial4 NOT NULL,
	tier_id int4 not NULL,
	numberofmonths int4 null,

	CONSTRAINT sub_pk PRIMARY KEY (id)
);
ALTER TABLE  sub ADD CONSTRAINT sub_fk_1 FOREIGN KEY (tier_id) REFERENCES sub_tier(id)
on delete set null;

CREATE TABLE cust_sub (
	id serial4 NOT NULL,
	cust_id int4 not null,
	sub_id int4 not null,
	current_term_start timestamp not null,
	current_term_exp timestamp not null constraint exp_greater_then_start check(current_term_exp > current_term_start),
	date_of_origin timestamp null,
	autorenew bool null,
	active bool null constraint notneg check (true or null),
	unique(cust_id, active),
	CONSTRAINT cust_sub_pk PRIMARY KEY (id)
);






ALTER TABLE  cust_sub ADD CONSTRAINT cust_sub_fk FOREIGN KEY (cust_id) REFERENCES customer(id)
on delete set null;

ALTER TABLE  cust_sub ADD CONSTRAINT cust_sub_1_fk FOREIGN KEY (sub_id) REFERENCES sub(id)
on delete set null;

create table cust_sub_pay_hist (
	id serial4 not null,
	cust_sub_id int4 not null,
	pay_date timestamp not null,
	amt money not null constraint notnegative check(amt > 0::money),
	description text null,
	constraint cust_sub_pay_hist_pk primary key (id)
);

ALTER TABLE  cust_sub_pay_hist ADD CONSTRAINT cust_sub_pay_hist_fk FOREIGN KEY (cust_sub_id) REFERENCES cust_sub(id)
on delete set null;

CREATE TABLE cust_sub_featurepk (
	id serial4 NOT NULL,
	cust_subid int4 not NULL,
	featpkid int4 not null,
	autorenew bool null,
	current_term_start timestamp not null,
	current_term_end timestamp not null,
	numberofmonths int null,
	date_of_origin timestamp not null,
	active bool null constraint notneg check (true or null),
	CONSTRAINT cust_sub_featurepk_pk PRIMARY KEY (id)
);

ALTER TABLE  cust_sub_featurepk ADD CONSTRAINT cust_sub_featpk1_fk FOREIGN KEY (cust_subid) REFERENCES cust_sub(id)
on delete set null;

ALTER TABLE  cust_sub_featurepk ADD CONSTRAINT cust_sub_featpk_fk FOREIGN KEY (featpkid) REFERENCES featurepack(id)
on delete set null;

create table cust_sub_feat_pay_hist (
	id serial4 not null,
	cust_sub_feat_id int4 not null,
	pay_date timestamp not null,
	amt money not null constraint notneg check (amt > 0::money),
	description text null,
	constraint cust_sub_feat_pay_hist_pk primary key (id)
);

ALTER TABLE  cust_sub_feat_pay_hist ADD CONSTRAINT cust_sub_feat_pay_hist_fk FOREIGN KEY (cust_sub_feat_id) references cust_sub_featurepk(id)
on delete set null;

CREATE TABLE gameplay_record (
	id serial4 NOT NULL,
	cust_subid serial4 not null,
	gameid serial4 not null,
	starttime timestamp null,
	duration interval null,
	CONSTRAINT cust_game_pk PRIMARY KEY (id)
);
ALTER TABLE  gameplay_record ADD CONSTRAINT gameplay_record_fk FOREIGN KEY (cust_subid) REFERENCES cust_sub(id)
on delete set null;
ALTER TABLE  gameplay_record ADD CONSTRAINT gameplay_record_fk_1 FOREIGN KEY (gameid) REFERENCES game(id)
on delete set null;

Create table game_feature_pack_rev(
	id serial4 not null, 
	game_record_id int4,
	feature_pack_id int4,
	constraint game_feat_pack_pk primary key (id)
);
ALTER TABLE game_feature_pack_rev ADD CONSTRAINT game_feature_pack_rev_fk FOREIGN KEY (game_record_id) REFERENCES gameplay_record(id)
on delete set null;
ALTER TABLE game_feature_pack_rev ADD CONSTRAINT game_feature_pack_rev_fk1  FOREIGN KEY (feature_pack_id) REFERENCES featurepack(id)
on delete set null;
