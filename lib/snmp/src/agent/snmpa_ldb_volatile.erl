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

-behaviour(snmpa_local_db).

-export([
	 start_link/1,
	 stop/0, 
	 verbosity/1,
	 variable_get/1, 
	 variable_set/2
	]).

%% snmpa_ldb callback functions
-export([
	 open/1,
	 handle_insert/3, 
	 handle_delete/2,
	 handle_match/3, 
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


%% -------------------------------------------------------------------- 
%% snmpa_ldb callback functions

open(_) ->
    Tab = ets:new(?TAB, [set, protected]),
    {ok, #state{tab = Tab}}.

handle_close(#state{tab = Tab}) ->
    ets:delete(Tb),
    ok.

handle_insert(#state{tab = Tab}, Key, Value) ->
    ets:insert(Tab, {Key, Value}),
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
    {ok, ets:match(Ets, Pattern)}.



