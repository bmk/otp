%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2012-2012. All Rights Reserved.
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
-module(snmpa_ldb_volatile).

-behaviour(snmpa_ldb).
%% -behaviour(snmpa_local_db).

-export([
	 start_link/1,
	 stop/0, 
	 verbosity/1,

	 variable_get/1, 
	 variable_set/2, 
	 variable_delete/1, 
	 variable_inc/2, 

	 table_create/1, 
	 table_exists/1, 
	 table_delete/1,
         table_get/1,

	 table_create_row/3, table_create_row/4, 
         table_delete_row/2,
         table_get_row/2,
         table_get_element/3, 
	 table_get_elements/4,
         table_set_elements/3, 
	 table_set_status/7,
         table_next/2,
         table_max_col/2
	]).

%% snmpa_local_db callback functions
-export([
	 open/1,
	 handle_insert/2, 
	 handle_delete/2,
	 handle_match/2, 
	 handle_lookup/2,
	 handle_close/1
	]).

-define(NAME, ?MODULE).
-define(TAB,  ?MODULE).

-record(state, {tab}).

start_link(Opts) ->
    snmpa_ldb:start_link(?NAME, ?MODULE, Opts).
    
stop() ->
    snmpa_ldb:stop(?NAME).

verbosity(Verbosity) ->
    snmpa_ldb:verbosity(?NAME, Verbosity).

variable_get(Variable) ->
    snmpa_ldb:variable_get(?NAME, Variable).

variable_set(Variable, Value) ->
    snmpa_ldb:variable_set(?NAME, Variable, Value).

variable_delete(Variable) ->
    snmpa_ldb:variable_delete(?NAME, Variable).

variable_inc(Variable, N) ->
    snmpa_ldb:variable_inc(?NAME, Variable, N).


table_create(Table) ->
    snmpa_ldb:table_create(?NAME, Table).

table_exists(Table) ->
    snmpa_ldb:table_exists(?NAME, Table).

table_delete(Table) ->
    snmpa_ldb:table_delete(?NAME, Table).

table_create_row(Table, RowIndex, Row) ->
    snmpa_ldb:table_create_row(?NAME, Table, RowIndex, Row).

table_create_row(Table, RowIndex, Status, Cols) ->
    snmpa_ldb:table_create_row(?NAME, Table, RowIndex, Status, Cols).

table_delete_row(Table, RowIndex) ->
    snmpa_ldb:table_create_row(?NAME, Table, RowIndex).

table_get_row(Table, RowIndex) ->
    snmpa_ldb:table_get_row(?NAME, Table, RowIndex).

table_get_element(Table, RowIndex, Col) ->
    snmpa_ldb:table_get_element(?NAME, Table, RowIndex, Col).

table_get_elements(Table, RowIndex, Cols) ->
    snmpa_ldb:table_get_elements(?NAME, Table, RowIndex, Cols).

table_set_elements(Table, RowIndex, Cols) ->
    snmpa_ldb:table_set_elements(?NAME, Table, RowIndex, Cols).

table_set_status(Table, RowIndex, Status, StatusCol, Cols, 
		 ChangedStatusFunc, ConsFunc) ->
    snmpa_ldb:table_set_status(?NAME, Table, RowIndex, Status, StatusCol, Cols, 
			       ChangedStatusFunc, ConsFunc).

table_next(Table, RestOid) ->
    snmpa_ldb:table_next(?NAME, Table, RestOid).

table_get(Table) ->
    snmpa_ldb:table(?NAME, Table).

table_max_col(Table, Col) ->
    snmpa_ldb:table_max_col(?NAME, Table, Col).


%% -------------------------------------------------------------------- 
%% snmpa_ldb callback functions

open(_) ->
    Tab = ets:new(?TAB, [set, protected]),
    {ok, #state{tab = Tab}}.

handle_close(#state{tab = Tab}) ->
    ets:delete(Tab),
    ok.

handle_insert(#state{tab = Tab}, Data) ->
    ets:insert(Tab, Data),
    ok.

handle_delete(#state{tab = Tab}, Key) ->
    ets:delete(Tab, Key),
    ok.

handle_lookup(#state{tab = Tab}, Key) ->
    case ets:lookup(Tab, Key) of
	[{_, Value}] ->
	    {ok, Value};
	[] ->
	    undefined
    end.

handle_match(#state{tab = Tab}, Pattern) ->
    {ok, ets:match(Tab, Pattern)}.

