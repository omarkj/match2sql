-module(match2sql).

-export([test/0,
	 tosql/1]).

-define(AND, <<"AND">>).
-define(SELECT, <<"SELECT">>).
-define(FROM, <<"FROM">>).
-define(WHERE, <<"WHERE">>).
-define(STAR, <<"*">>).
-define(AA, <<":">>).
-define(DASH, <<"-">>).
-define(OPEN, <<"(">>).
-define(CLOSE, <<")">>).
-define(SPACE, <<" ">>).
-define(END, <<";">>).
-define(COMMA, <<",">>).
-define(DOT, <<".">>).

-record(foo, {bar, zar}).

test() ->
    tosql([{#foo{bar='$1',zar='$2'},[{'>','$1', 1}],['$1']}]),
    F = tosql([{#foo{bar='$1',zar='$2'},[{'>',{'+','$2', 1}, 1}],['$1','$2']}]),
    io:format("F is ~p", [F]).

tosql([{Head, Match, Returns}]) ->
    {TableName, Elements} = match_elements(Head),
    Guards = convert_guards(Match, Elements, <<>>),
    Select = convert_select(TableName, lists:flatten(Returns), Elements),
    <<Select/binary, ?SPACE/binary, ?WHERE/binary,
      ?SPACE/binary, Guards/binary, ?END/binary>>.

convert_select(TableName, ['$_'], _) ->
    <<?SELECT/binary, ?SPACE/binary, ?STAR/binary,
      ?SPACE/binary, ?FROM/binary, ?SPACE/binary, TableName/binary>>;
convert_select(TableName, Returns, Elements) ->
    Select0 = lists:foldl(fun
			      (R, <<>>) ->
				  Name = proplists:get_value(R, Elements),
				  <<?SELECT/binary, ?SPACE/binary, Name/binary>>;
			      (R, Res) ->
				  Name = proplists:get_value(R, Elements),
				  <<Res/binary, ?COMMA/binary, Name/binary>>
			  end, <<>>, Returns),
    <<Select0/binary, ?SPACE/binary, ?FROM/binary, ?SPACE/binary,
      TableName/binary>>.

convert_guards([], _, Ret) ->
    Ret;
convert_guards([Guard|Rest], Elements, <<>>) ->
    convert_guards(Rest, Elements, convert_guard(Guard, Elements));
convert_guards([Guard|Rest], Elements, Acc) ->
    Guard0 = convert_guard(Guard, Elements),
    convert_guards(Rest, Elements, <<Acc/binary, ?AND/binary, Guard0/binary>>).

convert_guard({Rule, Var, Constraint}, Elements) when is_tuple(Var) ->
    Guard0 = convert_guard(Var, Elements),
    Rule0 = get_rule(Rule),
    Constraint0 = convert_constraint(Constraint, Elements),
    <<?OPEN/binary, Guard0/binary, ?CLOSE/binary,
      Rule0/binary, Constraint0/binary>>;
convert_guard({Rule, Var, Constraint}, Elements) ->
    Rule0 = get_rule(Rule),
    Var0 = proplists:get_value(Var, Elements),
    Constraint0 = convert_constraint(Constraint, Elements),
    <<Var0/binary, Rule0/binary, Constraint0/binary>>.

% @todo injection checking
convert_constraint(Constraint, Elements) when is_atom(Constraint) ->
    % Check if this constraint is actually a element
    case proplists:get_value(Constraint, Elements) of
	undefined ->
	    % Nope - convert the atom to binary and
	    list_to_binary(atom_to_list(Constraint));
	Data ->
	    Data
    end;
convert_constraint(Constraint, _) when is_integer(Constraint) ->
    list_to_binary(integer_to_list(Constraint));
convert_constraint(Constraint, _) when is_float(Constraint) ->
    list_to_binary(float_to_list(Constraint));
convert_constraint(Constraint, _) when is_list(Constraint) ->
    B = list_to_binary(Constraint),
    <<"'", B/binary, "'">>;
convert_constraint(Constraint, _) when is_binary(Constraint) ->
    <<"'", Constraint/binary, "'">>.    

get_rule('>') ->
    <<?SPACE/binary,">",?SPACE/binary>>;
get_rule('<') ->
    <<?SPACE/binary,"<",?SPACE/binary>>;
get_rule('+') ->
    <<?SPACE/binary,"+",?SPACE/binary>>;
get_rule('-') ->
    <<?SPACE/binary,"-",?SPACE/binary>>;
get_rule('=:=') ->
    <<?SPACE/binary,"=",?SPACE/binary>>;
get_rule('=/=') ->
    <<?SPACE/binary,"!=",?SPACE/binary>>.

match_elements(Head) ->
    FieldNames = record_info(fields, foo),
    [TableName|Data] = tuple_to_list(Head),
    TableName0 = list_to_binary(atom_to_list(TableName)),
    {TableName0, zip(TableName0, FieldNames, Data, [])}.

zip(_,[], [], Ret) ->
    Ret;
zip(T,[_FieldName|FieldNames], ['_'|Rest], Ret) ->
    zip(T,FieldNames, Rest, Ret);
zip(TableName, [FieldName|FieldNames], [Data|Rest], Ret) ->
    Field = list_to_binary(atom_to_list(FieldName)),
    Name = <<TableName/binary,?DOT/binary,Field/binary>>,
    zip(TableName, FieldNames, Rest,
	Ret ++ [{Data, Name}]).
