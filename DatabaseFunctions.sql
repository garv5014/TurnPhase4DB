CREATE OR REPLACE PROCEDURE seed_database(IN num_of_rows integer DEFAULT NULL::integer)
 LANGUAGE plpgsql
AS $procedure$
begin 
	if num_of_rows is null then 
		call makecustomers(10); 
		call makesubtier();
		call makesubs();
		call make_login_history();
		call make_cust_sub();
		call make_developers();
		call make_games();
		call makefeaturepack();
		call make_games_to_featurepack();
		call makecust_sub_pay_hist();
		call make_cust_sub_feat();
		call makecust_sub_feat_pay_hist();
		call simulate_playing_games_random();
	else 
		call makecustomers(num_of_rows); -- no default
		call makesubtier(); -- no parameter
		call makesubs(); -- no parameter
		call make_login_history((num_of_rows % 100) +1); -- defaults 3
		call make_cust_sub((num_of_rows %3) +1); -- num of contract per customer
		call make_developers(num_of_rows/10); -- defaults 10 
		call make_games((num_of_rows % 4)+ 1); -- number of games per dev
		call makefeaturepack(); -- finite number of packs. No Default
		call make_games_to_featurepack();-- Connects games to feature packs
		call makecust_sub_pay_hist(); --no parameters 
		call make_cust_sub_feat((num_of_rows%2) +1); -- number of potential contracts per customer
		call makecust_sub_feat_pay_hist(); -- no parameters
		call simulate_playing_games_random(2); -- simulates playing each game for each customer.
	end if;
end;
$procedure$
;

CREATE OR REPLACE PROCEDURE makecustomers(IN counter integer)
 LANGUAGE plpgsql
AS $procedure$
declare
randomnum int;
namename text = '';
begin 
  	 for coun in 0..counter by 1 loop
	  	 namename = '';
	  	 for randcount in 0..2 by 1 loop 
		  	 
	  	 	for idcount in 0..3 by 1 loop
	  	 		namename = namename||(((random() * 10)::int) - 1);
	  	 	end loop;
	  	 		namename = namename||' ';
	  	 end loop;
	  	 
	  	 INSERT INTO customer
	(email, firstname, surname, username, password_, payment_info)
	VALUES('email'||coun||'@email.com', 'Person'||coun, 'Personson'||coun, 'User'||coun, 'password'||coun, namename);
   	end loop;
 commit;
	
end;$procedure$
;

CREATE OR REPLACE PROCEDURE makesubtier()
 LANGUAGE plpgsql
AS $procedure$
declare

begin 
	INSERT INTO sub_tier
	(baseprice, tiername, concurrentlogin, active)
	VALUES(5.00, 'Bronze', 1, true), 
	(8.00, 'Silver', 2, true),
	(10.00, 'Gold', 5, true);
end;$procedure$
;


CREATE OR REPLACE PROCEDURE makesubs()
 LANGUAGE plpgsql
AS $procedure$
declare
subtier record;
begin 
	for subtier in
	select id from sub_tier s loop
	INSERT INTO sub
	(tier_id, numberofmonths)
	VALUES(subtier.id, 1),(subtier.id, 12); 
	end loop;
end;$procedure$
;

CREATE OR REPLACE PROCEDURE make_login_history(IN number_of_logins_per_cust integer DEFAULT 3)
 LANGUAGE plpgsql
AS $procedure$
declare 
	cust_curs cursor for select * from customer;
	current_cust record;
	rDeterminer int;
	mod_success bool;
	rlogin timestamp;
	rlogout timestamp; 
begin 
	
	open cust_curs; 
	loop
		
	fetch cust_curs into current_cust;
	exit when not found;
	
		for t in 0..number_of_logins_per_cust by 1
		loop 
			rlogin := null;
			rlogout := null;
			select (random() * 10) 
			into rDeterminer;
			rlogin :='2020-01-01'::timestamp + (random() * (interval '2 years')) + '0 days';
			if rDeterminer % 3 = 0 then 
			--failed to login
			mod_success = false;
			rlogout := rlogin +  '1 minute';
			else 
			--succeded login
			mod_success = true;
			if rDeterminer % 7 = 0 then
			rlogout := rlogin + (random() *  (interval'5 days'));
			end if;
			
			end if; 
			insert into log_in_out_history 
			(success, customerid,login,logout)
			values (mod_success, current_cust.id ,rlogin, rlogout);
		end loop;
		
	
	end loop;
	close cust_curs;
	
end;
$procedure$
;

CREATE OR REPLACE PROCEDURE make_cust_sub(IN number_of_potential_contracts integer DEFAULT 1)
 LANGUAGE plpgsql
AS $procedure$
declare 
	cust_curs cursor for select * from customer; 
	cust_current record;
	rSub int;
	rDeterminer int;
	origin_date timestamp;
	temp_term_start timestamp;
	temp_term_exp timestamp;
	temp_active bool; 
	temp_autorenew bool;
	temp_interval text;
begin 
	
	open cust_curs;
	loop
		fetch cust_curs into cust_current;
		exit when not found;
	
		for t in 0..number_of_potential_contracts by 1 
		loop 
			
			SELECT
				sub.id 
			into rSub
			FROM
				sub OFFSET floor(random() * (
					SELECT
						COUNT(*)
						FROM sub))
			LIMIT 1;
			
			origin_date :='2020-01-01'::timestamp + (random() * (interval '2 years')) + '0 days';
			temp_term_start := origin_date + (random() * (interval '2 years')) + '0 days'; 
		
			select s.numberofmonths
			into temp_interval
			from sub s 
			where (rSub = s.id);
			temp_interval := temp_interval || ' months';
			temp_term_exp := temp_term_start + temp_interval::interval;
			
		select (random() * 10) 
			into rDeterminer;
			
			if t = 1 then 
			temp_active = true;
			else 
			temp_active = null;
			end if;
		
			if rDeterminer % 4 = 0 then
			temp_autorenew = true;
			else
			temp_autorenew = null;
			end if;
			
			insert into cust_sub 
			(cust_id, sub_id, current_term_start, current_term_exp, date_of_origin, autorenew,active)
			values (cust_current.id, rsub, temp_term_start, temp_term_exp, origin_date, temp_autorenew, temp_active);
		end loop;
	end loop;
	close cust_curs; 
end;
$procedure$
;

CREATE OR REPLACE PROCEDURE make_developers(IN num_of_dev integer DEFAULT 10)
 LANGUAGE plpgsql
AS $procedure$
declare 
	dev_id int;
begin 
	for t in 1..num_of_dev by 1 
	loop 
		insert into developer 
		(developername, company_address)
		values ('', '')
	returning id into dev_id;
	update developer 
	set developername = 'Game Company ' || dev_id,
		company_address = 'Company on ' || dev_id || ' Sesame St NY, US'
	where (id = dev_id);
	end loop; 
	
end;
$procedure$
;

CREATE OR REPLACE PROCEDURE make_games(IN num_of_games_per_dev integer DEFAULT 10)
 LANGUAGE plpgsql
AS $procedure$
declare 
	all_devs_curs cursor for select d.developername, id from developer d; 
	current_dev record;
	temp_game_id int;
	rDeterminer int; 
	rMod int; 
	temp_public bool; 
begin 
	
	open all_devs_curs;
	loop
		
		fetch all_devs_curs into current_dev;
		exit when not found;
		for t in 1..num_of_games_per_dev by 1
		loop
		select (random() * 100) 
			into rDeterminer;
		select (random() * 10)
			into rMod;
		if rMod = 0 or rDeterminer % rMod = 0 then
		temp_public := true;
		else
		temp_public := false;
		end if;
				insert into game 
				(game_name, dev_id, public) 
				values ('', current_dev.id, temp_public ) returning id into temp_game_id;
			update game 
			set game_name = 'Game ' || temp_game_id
			where (game.id = temp_game_id );
			end loop;
	end loop;
end;
$procedure$
;

CREATE OR REPLACE PROCEDURE make_games_to_featurepack()
 LANGUAGE plpgsql
AS $procedure$
declare 
	private_games_curs cursor for select g.id from game g where (public = false);
	all_private_games record; 
	game_feat_count int; 
	feat_count int;
	Feat int; 
begin 
	select count(*)
	into feat_count
	from featurepack; 
	 open private_games_curs;
		loop
			fetch private_games_curs into all_private_games;
			exit when not found;
			
			Feat := all_private_games.id % feat_count; 
			if Feat <> 0 and  Feat = feat_count - 1 then
			INSERT INTO game_feat (game_id, feat_id) VALUES(all_private_games.id, Feat);
			INSERT INTO game_feat (game_id, feat_id) VALUES(all_private_games.id, Feat+1);
			elseif Feat <> 0 then
			INSERT INTO game_feat (game_id, feat_id) VALUES(all_private_games.id, Feat);
			else
			INSERT INTO game_feat (game_id, feat_id) VALUES(all_private_games.id, feat_count);
			end if;
		end loop; 
	close private_games_curs;
end;
$procedure$
;

CREATE OR REPLACE PROCEDURE makefeaturepack()
 LANGUAGE plpgsql
AS $procedure$
declare

begin 
	INSERT INTO featurepack
	(pack_name, baseprice, active)
	VALUES('Retro GamePack', 3, true),
	('HighSciFi GamePack', 4, true),
	('DungeonDweller GamePack', 2, true),
	('Retro GamePack', 2, null),
	('HighSciFi GamePack', 3, null),
	('DungeonDweller GamePack', 1.5, null);

end;$procedure$
;


CREATE OR REPLACE PROCEDURE makecust_sub_feat_pay_hist()
 LANGUAGE plpgsql
AS $procedure$
declare
myrecord record;
begin 
	for myrecord in
	select cs.id, cs.current_term_start, s.baseprice, cs.active, cs.autorenew, s.pack_name  
	from cust_sub_featurepk cs inner join featurepack s on (s.id = cs.featpkid) loop
	if(myrecord.active = true ) then
		if(myrecord.autorenew = true) then
			INSERT INTO cust_sub_feat_pay_hist
			(cust_sub_feat_id, pay_date, amt, description)
			VALUES(myrecord.id, myrecord.current_term_start, myrecord.baseprice - 1::money, myrecord.pack_name||' renew');
		else 
		INSERT INTO cust_sub_feat_pay_hist
			(cust_sub_feat_id, pay_date, amt, description)
			VALUES(myrecord.id, myrecord.current_term_start, myrecord.baseprice, myrecord.pack_name||' not renew');
		
		end if;
		
	end if;
	end loop;
 commit;
	
end;$procedure$
;


CREATE OR REPLACE PROCEDURE make_cust_sub_feat(IN number_of_potential_contracts integer DEFAULT 1)
 LANGUAGE plpgsql
AS $procedure$
declare 
	cust_curs cursor for select * from cust_sub; 
	cust_current record;
	rSub int;
	rDeterminer int;
	origin_date timestamp;
	temp_term_start timestamp;
	temp_term_exp timestamp;
	temp_active bool; 
	temp_autorenew bool;
	temp_interval text;
begin 
	
	open cust_curs;
	loop
		fetch cust_curs into cust_current;
		exit when not found;
	
		for t in 0..number_of_potential_contracts by 1 
		loop 
			
			SELECT
				f.id 
			into rSub
			FROM
				featurepack f OFFSET floor(random() * (
					SELECT
						COUNT(*)
						FROM featurepack))
			LIMIT 1;
			
			origin_date :='2020-01-01'::timestamp + (random() * (interval '2 years')) + '0 days';
			temp_term_start := origin_date + (random() * (interval '2 years')) + '0 days'; 
		
			select (random() * 10) 
			into rDeterminer;
			
			if t = 1 then 
			temp_active = true;
			else 
			temp_active = null;
			end if;
		
			if rDeterminer % 4 = 0 then
			temp_autorenew = true;
			else
			temp_autorenew = null;
			end if;
			if((cust_current.id % 2) = 0) then
			insert into cust_sub_featurepk 
			(cust_subid, featpkid, current_term_start, current_term_end, date_of_origin, autorenew,active, numberofmonths)
			values (cust_current.id, rsub, temp_term_start,  temp_term_start + '1 month', origin_date, temp_autorenew, temp_active, 1);
			else
			insert into cust_sub_featurepk 
			(cust_subid, featpkid, current_term_start, current_term_end, date_of_origin, autorenew,active, numberofmonths)
			values (cust_current.id, rsub, temp_term_start, temp_term_start + '1 year', origin_date, temp_autorenew, temp_active, 12);
			end if;
		end loop;
	end loop;
	close cust_curs; 
end;$procedure$
;

CREATE OR REPLACE PROCEDURE makecust_sub_feat_pay_hist()
 LANGUAGE plpgsql
AS $procedure$
declare
myrecord record;
begin 
	for myrecord in
	select cs.id, cs.current_term_start, s.baseprice, cs.active, cs.autorenew, s.pack_name  
	from cust_sub_featurepk cs inner join featurepack s on (s.id = cs.featpkid) loop
	if(myrecord.active = true ) then
		if(myrecord.autorenew = true) then
			INSERT INTO cust_sub_feat_pay_hist
			(cust_sub_feat_id, pay_date, amt, description)
			VALUES(myrecord.id, myrecord.current_term_start, myrecord.baseprice - 1::money, myrecord.pack_name||' renew');
		else 
		INSERT INTO cust_sub_feat_pay_hist
			(cust_sub_feat_id, pay_date, amt, description)
			VALUES(myrecord.id, myrecord.current_term_start, myrecord.baseprice, myrecord.pack_name||' not renew');
		
		end if;
		
	end if;
	end loop;
 commit;
	
end;$procedure$
;

CREATE OR REPLACE PROCEDURE simulate_playing_games_random(IN number_of_plays_per_game integer DEFAULT 2)
 LANGUAGE plpgsql
AS $procedure$
declare
	customer_curs cursor for select c.id from customer c; 
	cust_rec record; 
	game_ record; 
begin 
	open customer_curs;
	loop
		fetch customer_curs into cust_rec;
		exit when not found;
		for game_ in (
		select g.game_name, g.id from customer
		inner join cust_sub cs on (customer.id = cs.cust_id and customer.id = 1)
		left join cust_sub_featurepk csf on (cs.id = csf.cust_subid)
		left join featurepack f on (csf.featpkid = f.id)
		left join game_feat gf on (f.id = gf.feat_id)
		left join game g on (gf.game_id = g.id) 
		where (g.id is not null)
		Union (select g.game_name , g.id from game g where (g.public = true))
		)
		loop
			call play_game_random(game_.id, cust_rec.id);
		end loop; 
	end loop;
	close customer_curs; 
end;
$procedure$
;


CREATE OR REPLACE PROCEDURE play_game_random(IN gameid integer, IN custid integer)
 LANGUAGE plpgsql
AS $procedure$
declare 
	cust_sub_id int; 
	game_feat record; 
	gameplay_record_id int;
	can_play bool;
	temp_record record;
begin
	select cs.cust_id 
	into cust_sub_id
	from customer c inner join 
	cust_sub cs on(c.id = cs.cust_id)
	where (cs.cust_id = custid );
	 select game_playable(gameid, custid) into can_play;
	
	if can_play then 
		insert into gameplay_record 
		(cust_subid, gameid, starttime, duration)
		values (cust_sub_id, gameid, '2020-10-15'::timestamp + (random() * (interval '2 years')) + '30 days', random() * (interval '8 hours'))
		returning id into gameplay_record_id;
		
		for temp_record in (
		select gf.game_id , gf.feat_id 
						from game_feat gf where (gf.game_id = gameid)
		)loop
			insert into game_feature_pack_rev 
			(game_record_id, feature_pack_id) 
			values (gameplay_record_id, temp_record.feat_id);
		end loop;
	else 
	end if; 
end; 
$procedure$
;

CREATE OR REPLACE FUNCTION game_playable(gameid integer, custid integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
declare 
	all_feat_for_game record;
	target_game int := gameid;
	game_count int; 
begin
	select count(*)
	into game_count
	from (
	((select g.game_name, g.id from customer
    inner join cust_sub cs on (customer.id = cs.cust_id and customer.id = custid)
    left join cust_sub_featurepk csf on (cs.id = csf.cust_subid)
    left join featurepack f on (csf.featpkid = f.id)
    left join game_feat gf on (f.id = gf.feat_id)
	left join game g on (gf.game_id = g.id) 
	where (g.id is not null and g.id = gameid)) )
    Union (select g.game_name , g.id from game g where (g.public = true and g.id = gameid) )) as x;
	
   	if game_count > 0 then 
   	return true;
   	else
   	return false;
   	end if; 
end;
$function$
;

CREATE OR REPLACE FUNCTION base_subscription_revenue_per_dev(dev_id integer, month_year timestamp without time zone)
 RETURNS money
 LANGUAGE plpgsql
AS $function$
declare 
	payPeriodUpperBound timestamp := date_trunc('month', (month_year));
    payPeriodLowerBound timestamp := date_trunc('month', (month_year + interval '1 month'));
   	devsum int;
   	allGameCount float := 0; 
   	devGameCount float := 0; 
   	baseSubRev money := 0; 
   	targetId int := dev_id;
begin 
		select count(g.id)
		into devGameCount
		from game as g inner join 
		gameplay_record as gr on (g.id = gr.gameid and targetid = g.dev_id and (
									gr.starttime > payPeriodUpperBound) and (
									gr.starttime < payPeriodLowerBound ));
--		raise notice 'devGameCount is %', devGameCount;							
									
	
		select count(g.id)
		into allGameCount
		from game as g inner join 
		gameplay_record as gr on ( g.id = gr.gameid
									and gr.starttime > payPeriodUpperBound 
									and (gr.starttime < payPeriodLowerBound )  );
--		raise notice 'allGameCount is %', allGameCount;
		
	select sum(csph.amt)
		into baseSubRev
		from cust_sub cs inner join
		cust_sub_pay_hist csph on (cs.id = csph.cust_sub_id
										and (csph.pay_date > payPeriodUpperBound )
										and (csph.pay_date < payPeriodLowerBound));
					
--					raise notice 'baseSubRev is %', baseSubRev;
	if baseSubRev is null or allGameCount = 0 then 
	return 0;
	else 
	return ((devGameCount/allGameCount) * (.1 * baseSubRev));
	end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION can_login(target_customer_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
declare 
	current_login_count int; 
	num_allowed_logins int; 
begin 
	
	select count(*) 
	into current_login_count
	from log_in_out_history lioh 
	where ((lioh.success = true)
			and (lioh.logout is null)
			and (lioh.customerid = target_customer_id)
		  );
	
	
	select st.concurrentlogin
	into num_allowed_logins
	from cust_sub cs inner join
	sub s on (cs.cust_id = target_customer_id  and cs.active = true and cs.sub_id = s.id) inner join 
	sub_tier st on (st.id = s.tier_id);
	
	return (current_login_count < num_allowed_logins);
end;

$function$
;

CREATE OR REPLACE FUNCTION check_public(target_game_id integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
declare 
	public bool;
begin 
	
	select g.public from game g where (g.id = target_game_id) into public;
	return public;
end;
$function$
;

CREATE OR REPLACE FUNCTION feature_pack_revenue_per_dev(dev_id integer, month_year timestamp without time zone, fp_id integer)
 RETURNS money
 LANGUAGE plpgsql
AS $function$
declare 
	payPeriodUpperBound timestamp := date_trunc('month', (month_year));
    payPeriodLowerBound timestamp := date_trunc('month', (month_year + interval '1 month'));
   	devsum int;
   	allFPGameCount float := 0; 
   	devFPGameCount float := 0; 
   	FPSubRev money := 0; 
   	targetId int := dev_id;
   	game_rec record; 
   	feature_rec record; 
   	game_play_rev_count float; 
  	target_fp_id int := fp_id;
  	feature_play_rev_count float;
begin 
	for game_rec in 
	(select distinct gr.id
	from featurepack f  inner join 
	game_feat g_f on((f.id = target_fp_id) and (g_f.feat_id = target_fp_id)) inner join 
	game g on(g_f.game_id = g.id and (targetId = g.dev_id)) inner join 
	gameplay_record gr on ((g.id = gr.gameid) and 
							(gr.starttime > payPeriodUpperBound) and (
							gr.starttime < payPeriodLowerBound )  ))
	loop
		select count(gfpr)
		into game_play_rev_count
			from game_feature_pack_rev gfpr
			where game_rec.id = gfpr.game_record_id;
		
			raise notice 'GamePlayRevCount %', game_play_rev_count;
		if game_play_rev_count >  1 then
			devFPGameCount := devFPGameCount + 1/game_play_rev_count;
			else 
			devFPGameCount := devFPGameCount + 1;
		end if;
		raise notice 'DevFPGameCount % in loop', devFPGameCount;
	end loop;
	raise notice 'DevFPGameCount %', devFPGameCount;
		

	for feature_rec in 
	(select distinct gr.id
	from featurepack f  inner join 
	game_feat g_f on((f.id = target_fp_id) and (g_f.feat_id = target_fp_id)) inner join 
	game g on(g_f.game_id = g.id) inner join 
	gameplay_record gr on ((g.id = gr.gameid) and 
							(gr.starttime > payPeriodUpperBound) and (
							gr.starttime < payPeriodLowerBound )  ))
	loop 
		select count(gfpr)
		into feature_play_rev_count
			from game_feature_pack_rev gfpr
			where feature_rec.id = gfpr.game_record_id;
		
			raise notice 'GamePlayRevCount %', feature_play_rev_count;
		if feature_play_rev_count >  1 then
			allFPGameCount := allFPGameCount + 1/feature_play_rev_count;
			else 
			allFPGameCount := allFPGameCount + 1;
		end if;
		
		
	end loop;
	
	
		raise notice 'allFPGameCount %', allFPGameCount;

						
						
	select sum(csfph.amt)
	into FPSubRev
	from featurepack f inner join 
	cust_sub_featurepk csf  on(f.id = target_fp_id and target_fp_id = csf.featpkid ) inner join 
	cust_sub_feat_pay_hist csfph on(csf.id = csfph.cust_sub_feat_id and (
							csfph.pay_date  > payPeriodUpperBound) and (
							csfph.pay_date < payPeriodLowerBound ));
						raise notice 'fpsubrev %', FPSubRev;
		if allFPGameCount = 0 or FPSubRev is null then 
		return 0; 
		else 
		return ((devFPGameCount/allFPGameCount) * (.1 * FPSubRev));
		end if; 
end;
$function$
;

CREATE OR REPLACE PROCEDURE find_renewable()
 LANGUAGE plpgsql
AS $procedure$
declare
renew record;

begin 
	for renew in 
	select id, cust_id, sub_id, current_term_exp, date_of_origin, autorenew, active
	from cust_sub order by 4 desc
	loop
		if(renew.autorenew and (now() - renew.current_term_exp >= '1 second') and renew.active = true) then
		 call renew_sub(renew);
		end if;
	end loop;

end;$procedure$
;


CREATE OR REPLACE PROCEDURE find_renewable_fp()
 LANGUAGE plpgsql
AS $procedure$
declare
renew record;
isactive bool;
begin 
	for renew in 
	select id , cust_subid, featpkid, current_term_end, date_of_origin, autorenew 
	from cust_sub_featurepk csf order by 4 desc loop
		isactive = f.active from featurepack f where (renew.featpkid = f.id);
		if(renew.autorenew and (now() - renew.current_term_end >= '1 second') and isactive = true) then
		 call renew_sub_fp(renew);
		end if;
	end loop;

end;$procedure$
;


CREATE OR REPLACE FUNCTION generate_base_sub_rev_report(month_year timestamp without time zone)
 RETURNS TABLE(developer text, payout money, pay_month timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
declare 
	all_devs record; 
begin 
	for all_devs in( 
	select id, developername
	from developer
	)loop 
		Developer := all_devs.developername;
		payout := Base_Subscription_Revenue_Per_Dev(all_devs.id, month_year);
		Pay_Month := date_trunc('month', (month_year));
		return next;
	end loop;
end;
$function$
;

CREATE OR REPLACE FUNCTION generate_feature_pack_sub_rev_report(month_year timestamp without time zone)
 RETURNS TABLE(featurepack text, dev_name text, payout money, pay_month timestamp without time zone, acitve boolean)
 LANGUAGE plpgsql
AS $function$
declare 
	all_feature_packs record; 
	all_devs record;
begin 
	for all_devs in( 
	select id, developername
	from developer
	)
	loop 
		for all_feature_packs in(
		select id, active, pack_name from featurepack
		)
		loop
			dev_name := all_devs.developername;
			FeaturePack := all_feature_packs.pack_name;
			payout := Feature_Pack_Revenue_Per_Dev(all_devs.id,month_year , all_feature_packs.id);
			Pay_Month := date_trunc('month', (month_year));
			acitve := all_feature_packs.active;
			return next;
		end loop;
	end loop;
end;
$function$
;


CREATE OR REPLACE PROCEDURE play_game(IN gameid integer, IN custid integer)
 LANGUAGE plpgsql
AS $procedure$
declare 
	cust_sub_id int; 
	game_feat record; 
	gameplay_record_id int;
	can_play bool;
	temp_record record;
begin
	select cs.cust_id 
	into cust_sub_id
	from customer c inner join 
	cust_sub cs on(c.id = cs.cust_id)
	where (cs.cust_id = custid );
	 select game_playable(gameid, custid) into can_play;
	
	if can_play then 
		insert into gameplay_record 
		(cust_subid, gameid, starttime, duration)
		values (cust_sub_id, gameid, now(), null)
		returning id into gameplay_record_id;
		
		for temp_record in (
		select gf.game_id , gf.feat_id 
						from game_feat gf where (gf.game_id = gameid)
		)loop
			insert into game_feature_pack_rev 
			(game_record_id, feature_pack_id) 
			values (gameplay_record_id, temp_record.feat_id);
		end loop;
	else 
	end if; 
end; 
$procedure$
;


CREATE OR REPLACE PROCEDURE renew_sub(IN mycustsub record)
 LANGUAGE plpgsql
AS $procedure$
declare
subprice money;
submonths int;
tempexp timestamp;
tempmonths text;
begin 
	subprice = st.baseprice from cust_sub 
	inner join sub on (mycustsub.sub_id = sub.id)
	inner join sub_tier st on (st.id = sub.tier_id)
	where (cust_sub.id = mycustsub.id);

	submonths = s.numberofmonths from cust_sub
	inner join sub s on (s.id = cust_sub.sub_id)
	where (cust_sub.id = mycustsub.id);
	tempmonths = submonths||' months';
	tempexp = mycustsub.current_term_exp + tempmonths::interval;
	tempexp = date_trunc('month', tempexp);
	tempmonths = date_part('day', mycustsub.date_of_origin)||' days';
	tempexp = tempexp + tempmonths::interval;
	if(date_part('day', tempexp) < date_part('day', mycustsub.date_of_origin)) then
	tempexp = date_trunc('month', tempexp);
	tempexp = tempexp + date_part(
        'days', 
        (date_trunc('month', tempexp) + '1 month - 1 day'::interval)
        );
	end if;
	if(mycustsub.autorenew = true) then
	subprice = subprice * .85;
	end if;
	INSERT INTO cust_sub_pay_hist
	(cust_sub_id, pay_date, amt, description)
	VALUES(mycustsub.id, now(), subprice, 'renew subscription');
		
	UPDATE cust_sub
	SET current_term_start= current_term_exp, current_term_exp= tempexp - '1 day'::interval
	WHERE id=mycustsub.id;
end;$procedure$
;

CREATE OR REPLACE PROCEDURE renew_sub_fp(IN mycustsub record)
 LANGUAGE plpgsql
AS $procedure$
declare
subprice money;
submonths int;
tempexp timestamp;
tempmonths text;
begin 
	subprice = fp.baseprice from cust_sub_featurepk csf
	inner join featurepack fp on (fp.id = csf.featpkid)
	where (csf.id = mycustsub.id);

	submonths = s.numberofmonths from cust_sub
	inner join sub s on (s.id = cust_sub.sub_id)
	where (cust_sub.id = mycustsub.id);

	tempmonths = submonths||' months';
	tempexp = mycustsub.current_term_end + tempmonths::interval;
	tempexp = date_trunc('month', tempexp);
	tempmonths = date_part('day', mycustsub.date_of_origin)||' days';
	tempexp = tempexp + tempmonths::interval;

	if(date_part('day', tempexp) < date_part('day', mycustsub.date_of_origin)) then
	tempexp = date_trunc('month', tempexp);
	tempexp = tempexp + date_part(
        'days', 
        (date_trunc('month', tempexp) + '1 month - 1 day'::interval)
        );
	end if;

	if(mycustsub.autorenew = true) then
	subprice = subprice - 1::money;
	end if;
	INSERT INTO cust_sub_feat_pay_hist
	(cust_sub_feat_id, pay_date, amt, description)
	VALUES(mycustsub.id, now(), subprice, 'renew subscription on featurepack');


	UPDATE cust_sub_featurepk 
	SET current_term_start= current_term_end, current_term_end = (tempexp - '1 day'::interval)
	WHERE id=mycustsub.id;
end;$procedure$
;

CREATE OR REPLACE PROCEDURE simulate_playing_games_random(IN number_of_plays_per_game integer DEFAULT 2)
 LANGUAGE plpgsql
AS $procedure$
declare
	customer_curs cursor for select c.id from customer c; 
	cust_rec record; 
	game_ record; 
begin 
	open customer_curs;
	loop
		fetch customer_curs into cust_rec;
		exit when not found;
		for game_ in (
		select g.game_name, g.id from customer
		inner join cust_sub cs on (customer.id = cs.cust_id and customer.id = 1)
		left join cust_sub_featurepk csf on (cs.id = csf.cust_subid)
		left join featurepack f on (csf.featpkid = f.id)
		left join game_feat gf on (f.id = gf.feat_id)
		left join game g on (gf.game_id = g.id) 
		where (g.id is not null)
		Union (select g.game_name , g.id from game g where (g.public = true))
		)
		loop
			call play_game_random(game_.id, cust_rec.id);
		end loop; 
	end loop;
	close customer_curs; 
end;
$procedure$
;



CREATE OR REPLACE VIEW currentcustomers
AS SELECT c.id,
    c.firstname,
    c.surname,
    c.username,
    cs.date_of_origin,
    s.numberofmonths,
    st.tiername
   FROM customer c
     JOIN cust_sub cs ON c.id = cs.cust_id
     JOIN sub s ON s.id = cs.sub_id
     JOIN sub_tier st ON s.tier_id = st.id
  WHERE cs.active = true;