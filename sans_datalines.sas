
   /*-----------------------------------------------------------------*
   | MACRO NAME	 : 	sans_datalines
   | SHORT DESC  : 	This macro provides macro envionment-friendly hard 
   |				coding to manually recreate a SAS data without
   |				usng datalines/cards.
   |					
   *------------------------------------------------------------------*
   | AUTHOR		 : Langlais, Blake                			(08/15/2019)
   |					
   *------------------------------------------------------------------*
   | PURPOSE	 :	This macro provides macro language-friendly hard 
   |				coding to manually recreate a SAS data set without 
   |				usng datalines/cards. The user provides an existing
   |				SAS dataset, the macro generates data step code for the
   |				user to copy from the log into the editor. This
   |				is particularly useful in the SAS macro enviornment
   |				where manual data creation is not possible using typical
   |				methods (i.e. dataline/cards statements).
   |					
   *------------------------------------------------------------------*
   | MACRO CALL
   |
   |  
   		%sans_datalines(dsn= );
   |	
   |	 		
   |
   *------------------------------------------------------------------*
   | REQUIRED PARAMETERS
   |
   | Name      : dsn
   | Type      : A single existing SAS data set 
   |
   *------------------------------------------------------------------*
   | ADDITIONAL NOTES
   |
   |
   *------------------------------------------------------------------*
   | This program is free software; you can redistribute it and/or
   | modify it under the terms of the GNU General Public License as
   | published by the Free Software Foundation; either version 2 of
   | the License, or (at your option) any later version.
   |
   | This program is distributed in the hope that it will be useful,
   | but WITHOUT ANY WARRANTY; without even the implied warranty of
   | MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   | General Public License for more details.
   *-----------------------------------------------------------------*/

%macro sans_datalines(dsn);
	%if %sysfunc(exist(&dsn.))=0 %then %do;
		data _null_;
			put "ER" "ROR: No data live here -> &dsn..";
		run;
		%goto exit;
	%end;
	%let userwarn = %sysfunc(getoption(mergenoby,keyword));
	options mergenoby=nowarn;
	data ____dsn;
		set &dsn.;
	run;
	proc contents data=____dsn out=____dsn_conts noprint;
	run;
	data ____ref;
		set ____dsn_conts(keep = name type length);
		rank + 1;
	run;
	proc sql noprint;
		select max(rank)
		into : max_rank
		from ____ref;
	quit;
	data ____outlog;
	run;
	%let length_code =;
	%let i = 1;
	%do %while(&i. <= &max_rank.);	
		data _null_;
			set ____ref(where=(rank=&i.));
			call symput("name_i", name);
			call symput("type_i", type);
			call symput("length_i", length);
		run;
		%if &type_i. = 1 %then %do;
			%if &i.^=1 %then %do; 
				%let length_code = %sysfunc(strip(&length_code.)) %sysfunc(strip(&name_i.)) %sysfunc(strip(&length_i.)); 
			%end;
				%else %do; 
					%let length_code = %sysfunc(strip(&name_i.)) %sysfunc(strip(&length_i.));
				%end;
		%end;
			%else %if &type_i. = 2 %then %do;
				%if &i.^=1 %then %do; 
					%let length_code = %sysfunc(strip(&length_code.)) %sysfunc(strip(&name_i.)) $%sysfunc(strip(&length_i.));
				%end;
					%else %do;
						%let length_code = %sysfunc(strip(&name_i.)) $%sysfunc(strip(&length_i.));
					%end;
			%end;
		%put "&length_code.";
		data ____outlog;
			merge ____outlog ____dsn(keep=&name_i. rename=(&name_i. = _&name_i.));
			%if &type_i. = 1 %then %do;
				&name_i. = strip(put(_&name_i., 30.));
				if &name_i. = "" then &name_i. = ".";
			%end;
				%else %if &type_i. = 2 %then %do;
					length &name_i. $%eval(&length_i.+2);
					&name_i. = "'"||strip(_&name_i.)||"'";
					if &name_i. = "" then &name_i. = "''";
				%end;
			drop _&name_i.;
		run;
		%let i = %eval(&i.+1);
	%end;
	proc sql noprint;
		select strip(name)||"=';'"
		into : put_code separated by " "
		from ____ref;
	quit;
	data _null_;
		set ____outlog end=last_rec;
		if _n_ = 1 then do;
			put "data &dsn.;";
			put "length &length_code.;";
		end;
		put  &put_code. " output;";
		if last_rec then do;
			put "run;";
			put ";";
			put ";";
		end;
	run;
	/* ------------------------------ */
	/* --- Clean up ----------------- */
	/* ------------------------------ */
	option &userwarn.;
	proc datasets noprint;
		delete ____:;
	quit;
	%exit:
%mend;