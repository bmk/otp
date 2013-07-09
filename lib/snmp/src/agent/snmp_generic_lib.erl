%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2013-2013. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%
%%
-module(snmp_generic_lib).

%% Avoid warning for local function error/1 clashing with autoimported BIF.
-compile({no_auto_import, [error/1]}).
-export([try_apply/2, 
	 init_defaults/2, init_defaults/3,
	 split_index_to_keys/2, 
	 table_construct_row/4, 
	 table_create_rest/6,
	 table_info/1,
	 get_own_indexes/2, 
	 get_status_col/2, 
	 get_table_info/2, 
	 get_index_types/1]).

-include("STANDARD-MIB.hrl").
-include("snmp_types.hrl").

-define(VMODULE,"GENERIC-LIB").
-include("snmp_verbosity.hrl").

-ifndef(default_verbosity).
-define(default_verbosity, silence).
-endif.


%%------------------------------------------------------------------

init_defaults(Defs, InitRow) ->
    table_defaults(InitRow, Defs).
init_defaults(Defs, InitRow, StartCol) ->
    table_defaults(InitRow, StartCol, Defs).


%%------------------------------------------------------------------
%%  Sets default values to a row.
%%  InitRow is a list of values.
%%  Defs is a list of {Col, DefVal}, in Column order.
%%  Returns a new row (a list of values) with the same values as
%%  InitRow, except if InitRow has value noinit in a column, and
%%  the corresponing Col has a DefVal in Defs, then the DefVal
%%  will be the new value.
%%------------------------------------------------------------------
table_defaults(InitRow, Defs) -> table_defaults(InitRow, 1, Defs).

table_defaults([], _, _Defs) -> [];
table_defaults([noinit | T], CurIndex, [{CurIndex, DefVal} | Defs]) ->
    [DefVal | table_defaults(T, CurIndex+1, Defs)];
%% 'not-accessible' columns don't get a value
table_defaults([noacc | T], CurIndex, [{CurIndex, _DefVal} | Defs]) ->
    [noacc | table_defaults(T, CurIndex+1, Defs)];
table_defaults([Val | T], CurIndex, [{CurIndex, _DefVal} | Defs]) ->
    [Val | table_defaults(T, CurIndex+1, Defs)];
table_defaults([Val | T], CurIndex, Defs) ->
    [Val | table_defaults(T, CurIndex+1, Defs)].


%%------------------------------------------------------------------
%%  Constructs a row with first elements the own part of RowIndex,
%%  and last element RowStatus. All values are stored "as is", i.e.
%%  dynamic key values are stored without length first.
%%  RowIndex is a list of the
%%  first elements. RowStatus is needed, because the
%%  provided value may not be stored, e.g. createAndGo
%%  should be active.
%%  Returns a tuple of values for the row. If a value
%%  isn't specified in the Col list, then the
%%  corresponding value will be noinit.
%%------------------------------------------------------------------
table_construct_row(Table, RowIndex, Status, Cols) ->
    #table_info{nbr_of_cols     = LastCol, 
		index_types     = Indexes,
                defvals         = Defs, 
		status_col      = StatusCol,
                first_own_index = FirstOwnIndex, 
		not_accessible  = NoAccs} = table_info(Table),
    Keys    = split_index_to_keys(Indexes, RowIndex),
    OwnKeys = get_own_indexes(FirstOwnIndex, Keys),
    Row     = OwnKeys ++ table_create_rest(length(OwnKeys) + 1,
					   LastCol, StatusCol,
					   Status, Cols, NoAccs),
    L = init_defaults(Defs, Row),
    list_to_tuple(L).



%%-----------------------------------------------------------------
%% Get, from a list of Keys, the Keys defined in this table.
%% (e.g. if INDEX { ifIndex, myOwnIndex }, the Keys is a list
%% of two elements, and returned from this func is a list of
%% the last of the two.)
%%-----------------------------------------------------------------

get_own_indexes(0, _Keys) -> [];
get_own_indexes(1, Keys) -> Keys;
get_own_indexes(Index, [_Key | Keys]) ->
    get_own_indexes(Index - 1, Keys).


%%-----------------------------------------------------------------
%% Creates everything but the INDEX columns.
%% Pre: The StatusColumn is present
%% Four cases:
%% 0) If a column is 'not-accessible' => use noacc
%% 1) If no value is provided for the column and column is
%%    not StatusCol => use noinit
%% 2) If column is not StatusCol, use the provided value
%% 3) If column is StatusCol, use Status
%%-----------------------------------------------------------------
table_create_rest(Col, Max, _ , _ , [], _NoAcc) when Col > Max -> [];
table_create_rest(Col,Max,StatusCol,Status,[{Col,_Val}|Defs],[Col|NoAccs]) ->
    % case 0
    [noacc | table_create_rest(Col+1, Max, StatusCol, Status, Defs, NoAccs)];
table_create_rest(Col,Max,StatusCol,Status,Defs,[Col|NoAccs]) ->
    % case 0
    [noacc | table_create_rest(Col+1, Max, StatusCol, Status, Defs, NoAccs)];
table_create_rest(StatCol, Max, StatCol, Status, [{_Col, _Val} |Defs], NoAccs) ->
    % case 3
    [Status | table_create_rest(StatCol+1, Max, StatCol, Status,Defs,NoAccs)];
table_create_rest(Col, Max, StatusCol, Status, [{Col, Val} |Defs],NoAccs) ->
    % case 2
    [Val | table_create_rest(Col+1, Max, StatusCol, Status,Defs,NoAccs)];
table_create_rest(StatCol, Max, StatCol, Status, Cols, NoAccs) ->
    % case 3
    [Status | table_create_rest(StatCol+1, Max, StatCol, Status, Cols, NoAccs)];
table_create_rest(Col, Max, StatusCol, Status, Cols, NoAccs) when Col =< Max->
    % case 1
    [noinit | table_create_rest(Col+1, Max, StatusCol, Status, Cols, NoAccs)].


%%------------------------------------------------------------------
%% This function splits RowIndex which is part
%% of a OID, into a list of the indexes for the
%% table. So a table with indexes {integer, octet string},
%% and a RowIndex [4,3,5,6,7], will be split into
%% [4, [5,6,7]].
%%------------------------------------------------------------------
split_index_to_keys(Indexes, RowIndex) ->
    collect_keys(Indexes, RowIndex).

collect_keys([#asn1_type{bertype = 'INTEGER'} | Indexes], [IntKey | Keys]) ->
    [IntKey | collect_keys(Indexes, Keys)];
collect_keys([#asn1_type{bertype = 'Unsigned32'} | Indexes], [IntKey | Keys]) ->
    [IntKey | collect_keys(Indexes, Keys)];
collect_keys([#asn1_type{bertype = 'Counter32'} | Indexes], [IntKey | Keys]) ->
    %% Should we allow this - counter in INDEX is strange!
    [IntKey | collect_keys(Indexes, Keys)];
collect_keys([#asn1_type{bertype = 'TimeTicks'} | Indexes], [IntKey | Keys]) ->
    %% Should we allow this - timeticks in INDEX is strange!
    [IntKey | collect_keys(Indexes, Keys)];
collect_keys([#asn1_type{bertype = 'IpAddress'} | Indexes], 
	     [A, B, C, D | Keys]) ->
    [[A, B, C, D] | collect_keys(Indexes, Keys)];
%% Otherwise, check if it has constant size
collect_keys([#asn1_type{lo = X, hi = X} | Indexes], Keys)
   when is_integer(X) andalso (length(Keys) >= X) ->
    {StrKey, Rest} = collect_length(X, Keys, []),
    [StrKey | collect_keys(Indexes, Rest)];
collect_keys([#asn1_type{lo = X, hi = X} | _Indexes], Keys)
   when is_integer(X) ->
    exit({error, {size_mismatch, X, Keys}});
%% Otherwise, its a dynamic-length type => its a list
%% OBJECT IDENTIFIER, OCTET STRING or BITS (or derivatives)
%% Check if it is IMPLIED (only last element can be IMPLIED)
collect_keys([#asn1_type{implied = true}], Keys) ->
    [Keys];
collect_keys([_Type | Indexes], [Length | Keys]) when length(Keys) >= Length ->
    {StrKey, Rest} = collect_length(Length, Keys, []),
    [StrKey | collect_keys(Indexes, Rest)];
collect_keys([_Type | _Indexes], [Length | Keys]) ->
    exit({error, {size_mismatch, Length, Keys}});
collect_keys([], []) -> [];
collect_keys([], Keys) ->
    exit({error, {bad_keys, Keys}});
collect_keys(_Any, Key) -> [Key].

collect_length(0, Rest, Rts) ->
    {lists:reverse(Rts), Rest};
collect_length(N, [El | Rest], Rts) ->
    collect_length(N-1, Rest, [El | Rts]).


try_apply(nofunc, _) -> {noError, 0};
try_apply(F, Args) -> apply(F, Args).


table_info({Name, _ModuleAlias}) ->
    case snmpa_symbolic_store:table_info(Name) of
	{value, TI} ->
	    TI;
	false ->
	    error({table_not_found, Name})
    end;
table_info(Name) ->
    case snmpa_symbolic_store:table_info(Name) of
	{value, TI} ->
	    TI;
	false ->
	    error({table_not_found, Name})
    end.

variable_info({Name, _ModuleAlias}) ->
    case snmpa_symbolic_store:variable_info(Name) of
	{value, VI} ->
	    VI;
	false ->
	    error({variable_not_found, Name})
    end;
variable_info(Name) ->
    case snmpa_symbolic_store:variable_info(Name) of
	{value, VI} ->
	    VI;
	false ->
	    error({variable_not_found, Name})
    end.


%%-----------------------------------------------------------------
%% Purpose: These functions can be used by the user's instrum func 
%%          to retrieve various table info.
%%-----------------------------------------------------------------

%%-----------------------------------------------------------------
%% Description:
%% Used by user's instrum func to check if mstatus column is 
%% modified.
%%-----------------------------------------------------------------
get_status_col(Name, Cols) ->
    #table_info{status_col = StatusCol} = table_info(Name),
    case lists:keysearch(StatusCol, 1, Cols) of
	{value, {StatusCol, Val}} -> {ok, Val};
	_ -> false
    end.



%%-----------------------------------------------------------------
%% Description:
%% Used by user's instrum func to get the table info. Specific parts
%% or all of it. If all is selected then the result will be a tagged
%% list of values.
%%-----------------------------------------------------------------
get_table_info(Name, nbr_of_cols) ->
    get_nbr_of_cols(Name);
get_table_info(Name, defvals) ->
    get_defvals(Name);
get_table_info(Name, status_col) ->
    get_status_col(Name);
get_table_info(Name, not_accessible) ->
    get_not_accessible(Name);
get_table_info(Name, index_types) ->
    get_index_types(Name);
get_table_info(Name, first_accessible) ->
    get_first_accessible(Name);
get_table_info(Name, first_own_index) ->
    get_first_own_index(Name);
get_table_info(Name, all) ->
    TableInfo = table_info(Name),
    [{nbr_of_cols,      TableInfo#table_info.nbr_of_cols},
     {defvals,          TableInfo#table_info.defvals},
     {status_col,       TableInfo#table_info.status_col},
     {not_accessible,   TableInfo#table_info.not_accessible},
     {index_types,      TableInfo#table_info.index_types},
     {first_accessible, TableInfo#table_info.first_accessible},
     {first_own_index,  TableInfo#table_info.first_own_index}].


%%-----------------------------------------------------------------
%% Description:
%% Used by user's instrum func to get the index types.
%%-----------------------------------------------------------------
get_index_types(Name) ->
    #table_info{index_types = IndexTypes} = table_info(Name),
    IndexTypes.

get_nbr_of_cols(Name) ->
    #table_info{nbr_of_cols = NumberOfCols} = table_info(Name),
    NumberOfCols.

get_defvals(Name) ->
    #table_info{defvals = DefVals} = table_info(Name),
    DefVals.

get_status_col(Name) ->
    #table_info{status_col = StatusCol} = table_info(Name),
    StatusCol.

get_not_accessible(Name) ->
    #table_info{not_accessible = NotAcc} = table_info(Name),
    NotAcc.

get_first_accessible(Name) ->
    #table_info{first_accessible = FirstAcc} = table_info(Name),
    FirstAcc.

get_first_own_index(Name) ->
    #table_info{first_own_index = FirstOwnIdx} = table_info(Name),
    FirstOwnIdx.


%%-----------------------------------------------------------------

error(Reason) ->
    throw({error, Reason}).

user_err(F, A) ->
    snmpa_error:user_err(F, A).
