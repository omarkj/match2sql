-define(match2sql(MatchSpec, RecordName),
	match2sql:tosql(MatchSpec, record_info(fields, RecordName))).
