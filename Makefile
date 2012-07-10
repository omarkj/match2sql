test:
	erl -compile match2sql.erl
	erl -noshell -pa ebin -eval "eunit:test(match2sql, [verbose])" -s init stop